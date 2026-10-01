-- Database growth guard: the rules, as one function that service/guard-loop.sh calls every 2 minutes.
--
-- Lives in its own schema and READS the tables of n8n (execution_entity, execution_data,
-- binary_data, workflow_entity). It writes two tiny tables of its own: guard.state (one row)
-- and guard.event (one row per alert, used to send each alert only once). guard.allowance holds
-- the big jobs that were allowed by hand.
--
-- One exception to read-only: guard.sweep_files deletes files in binary_data whose run no longer
-- exists. n8n leaves them behind when it removes a run, and nothing can reach them any more.
--
-- The function decides and describes; it never stops anything itself. The service sends the
-- alerts and makes the API calls for the targets this function returns.
--
-- Safe to run again: everything is CREATE ... IF NOT EXISTS / CREATE OR REPLACE.
-- The service installs this file at every start. By hand: scripts/db-guard.sh install

CREATE SCHEMA IF NOT EXISTS guard;

CREATE TABLE IF NOT EXISTS guard.state (
  id         boolean PRIMARY KEY DEFAULT true CHECK (id),   -- exactly one row
  last_tick  timestamptz,
  mode       text,
  level      text,                                          -- ok | warn | hard
  pct        numeric,
  used_bytes bigint,
  hard_ticks integer NOT NULL DEFAULT 0                     -- checks in a row at or above the hard stop
);
INSERT INTO guard.state (id) VALUES (true) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS guard.event (
  id          bigserial PRIMARY KEY,
  at          timestamptz NOT NULL DEFAULT now(),
  kind        text NOT NULL,             -- rate_breach | allowance | disk_warn | hard_stop | stuck_run | unattributed
  workflow_id text NOT NULL DEFAULT '',
  bucket      text NOT NULL,             -- the window within which this alert is sent only once
  mode        text NOT NULL,
  detail      jsonb,
  UNIQUE (kind, workflow_id, bucket)
);

-- Deny by default: a big job is blocked unless a row here covers it. Written by
-- scripts/db-guard.sh allow; sql/tick.sql hands the rows that have not ended to guard.tick.
CREATE TABLE IF NOT EXISTS guard.allowance (
  id          bigserial PRIMARY KEY,
  workflow_id text NOT NULL,
  mb          numeric NOT NULL CHECK (mb > 0),      -- may store this much in total between starts and until
  starts      timestamptz NOT NULL DEFAULT now(),
  until       timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Records an alert. Returns true when it is new (so it should be sent), false when the same
-- alert was already sent in this window. If the row cannot be written (disk full), it returns
-- true: better a repeated alert than a silent one.
CREATE OR REPLACE FUNCTION guard.note(p_kind text, p_workflow_id text, p_bucket text, p_mode text, p_detail jsonb)
RETURNS boolean
LANGUAGE plpgsql AS $guard$
DECLARE
  n integer;
BEGIN
  INSERT INTO guard.event (kind, workflow_id, bucket, mode, detail)
  VALUES (p_kind, coalesce(p_workflow_id, ''), p_bucket, p_mode, p_detail)
  ON CONFLICT (kind, workflow_id, bucket) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
EXCEPTION WHEN OTHERS THEN
  RETURN true;
END
$guard$;

-- Workflows to switch off when p_wf stored too much.
-- If p_wf starts runs on its own (it has a trigger, or a run of it was started by hand), that is
-- p_wf itself. If it only ever runs as a sub-workflow, switching it off would just make its
-- callers fail, and failed runs store their full data. Then the targets are the workflows that
-- call it, directly or through other sub-workflows, and that own a trigger.
CREATE OR REPLACE FUNCTION guard.targets_for(p_wf text, p_protected text[])
RETURNS jsonb
LANGUAGE plpgsql STABLE AS $guard$
DECLARE
  v_root boolean;
  v_out  jsonb;
BEGIN
  SELECT coalesce(w."triggerCount", 0) > 0
         OR EXISTS (SELECT 1 FROM execution_entity e
                    WHERE e."workflowId" = p_wf AND e.mode <> 'integrated'
                      AND (e.status IN ('new', 'running', 'waiting')
                           OR e."stoppedAt" > now() - interval '60 minutes'))
  INTO v_root
  FROM workflow_entity w WHERE w.id = p_wf;

  IF coalesce(v_root, false) THEN
    SELECT jsonb_agg(jsonb_build_object('id', w.id, 'name', w.name,
                                        'version_id', w."activeVersionId", 'stop', true))
    INTO v_out
    FROM workflow_entity w
    WHERE w.id = p_wf AND NOT (w.id = ANY (p_protected));
  ELSE
    WITH RECURSIVE up (id, depth) AS (
      SELECT p_wf, 0
      UNION
      SELECT c.id, up.depth + 1
      FROM up
      JOIN workflow_entity c ON c.id <> up.id AND c.nodes::text LIKE '%' || up.id || '%'
      WHERE up.depth < 4
    )
    SELECT jsonb_agg(DISTINCT jsonb_build_object('id', w.id, 'name', w.name,
                                                 'version_id', w."activeVersionId", 'stop', true))
    INTO v_out
    FROM up
    JOIN workflow_entity w ON w.id = up.id
    WHERE up.depth > 0 AND w.active AND coalesce(w."triggerCount", 0) > 0
      AND NOT (w.id = ANY (p_protected));
  END IF;

  RETURN coalesce(v_out, '[]'::jsonb);
END
$guard$;

-- Names in alerts go to Telegram as Markdown; one stray underscore makes the whole send fail.
CREATE OR REPLACE FUNCTION guard.plain(p text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $guard$
  SELECT translate(coalesce(p, '?'), '_*[]`~', '      ');
$guard$;

CREATE OR REPLACE FUNCTION guard.mb(p numeric)
RETURNS text
LANGUAGE sql IMMUTABLE AS $guard$
  SELECT trim(to_char(round(coalesce(p, 0) / 1048576.0, 1), 'FM999999990.0'));
$guard$;

CREATE OR REPLACE FUNCTION guard.names(p_targets jsonb)
RETURNS text
LANGUAGE sql IMMUTABLE AS $guard$
  SELECT coalesce(string_agg(guard.plain(t ->> 'name'), ', '), 'nothing')
  FROM jsonb_array_elements(p_targets) t;
$guard$;

-- One check. Always returns exactly one JSON document:
--   { ok, skipped, mode, level, pct, used_mb, hard_ticks, actions: [...] }
-- Deletes files that belong to no run. n8n keeps the files of a run (attachments, downloads) in
-- binary_data and does not delete them when it removes the run, whether by its own clean-up of
-- old runs or because the run was not to be saved. Without this, the table only ever grows.
-- Only rows older than p_hours are touched, at most p_limit per call, so a check stays short.
-- A run that is only marked as deleted still has its row in execution_entity: its files stay
-- until n8n removes the row.
CREATE OR REPLACE FUNCTION guard.sweep_files(p_hours numeric, p_limit integer DEFAULT 500)
RETURNS jsonb
LANGUAGE plpgsql AS $guard$
DECLARE
  v_rows  integer;
  v_bytes bigint;
BEGIN
  IF coalesce(p_hours, 0) <= 0 THEN
    RETURN jsonb_build_object('rows', 0, 'bytes', 0);
  END IF;
  WITH gone AS (
    DELETE FROM binary_data
    WHERE "fileId" IN (
      SELECT bd."fileId"
      FROM binary_data bd
      WHERE bd."sourceType" = 'execution'
        AND bd."createdAt" < now() - make_interval(secs => p_hours * 3600)
        AND NOT EXISTS (SELECT 1 FROM execution_entity e WHERE e.id::text = bd."sourceId")
      ORDER BY bd."createdAt"
      LIMIT p_limit)
    RETURNING "fileSize")
  SELECT count(*), coalesce(sum("fileSize"), 0) INTO v_rows, v_bytes FROM gone;
  RETURN jsonb_build_object('rows', v_rows, 'bytes', v_bytes);
END
$guard$;

-- Each action: { kind, workflow_id, notify, enforce, targets: [{id, name, version_id, stop}], subject, text }
--   notify  = send the alert (false when the same alert was already sent in its window)
--   enforce = switch the targets off and stop their runs (only in mode "enforce")
CREATE OR REPLACE FUNCTION guard.tick(cfg jsonb)
RETURNS jsonb
LANGUAGE plpgsql AS $guard$
DECLARE
  v_mode       text    := CASE WHEN cfg ->> 'mode' = 'enforce' THEN 'enforce' ELSE 'observe' END;
  v_enforce    boolean := cfg ->> 'mode' = 'enforce';
  v_volume     numeric := coalesce((cfg ->> 'volume_mb')::numeric, 500) * 1048576;
  v_overhead   numeric := coalesce((cfg ->> 'overhead_mb')::numeric, 0) * 1048576;
  v_warn       numeric := coalesce((cfg ->> 'warn_pct')::numeric, 70);
  v_hard       numeric := coalesce((cfg ->> 'hard_pct')::numeric, 85);
  v_hard_need  integer := coalesce((cfg ->> 'hard_checks_in_a_row')::integer, 2);
  v_burst      interval := make_interval(mins => coalesce((cfg ->> 'burst_minutes')::integer, 3));
  v_lim_burst  numeric := coalesce((cfg ->> 'default_mb_burst')::numeric, 5) * 1048576;
  v_lim_hour   numeric := coalesce((cfg ->> 'default_mb_hour')::numeric, 20) * 1048576;
  v_max_run    interval := make_interval(mins => coalesce((cfg ->> 'max_run_minutes')::integer, 120));
  v_protected  text[]  := ARRAY(SELECT jsonb_array_elements_text(coalesce(cfg -> 'protected', '[]'::jsonb)));
  v_scope      text[]  := ARRAY(SELECT jsonb_array_elements_text(coalesce(cfg -> 'hard_stop_scope', '[]'::jsonb)));
  v_prefix     text;
  v_verb       text;
  v_used       numeric;
  v_pct        numeric;
  v_level      text;
  v_hard_ticks integer := 0;
  v_actions    jsonb := '[]'::jsonb;
  v_targets    jsonb;
  v_notify     boolean;
  v_act        boolean;
  v_factor     numeric;
  v_text       text;
  v_subject    text;
  v_name       text;
  v_half_hour  text := to_char(now(), 'YYYY-MM-DD HH24') || CASE WHEN extract(minute FROM now()) < 30 THEN ':00' ELSE ':30' END;
  v_swept      jsonb := jsonb_build_object('rows', 0, 'bytes', 0);
  r            record;
BEGIN
  -- Never queue behind a table rewrite or a migration: give up after 3 seconds instead.
  PERFORM set_config('lock_timeout', '3s', true);
  -- One check at a time. After a hung worker, queued checks arrive in a burst.
  IF NOT pg_try_advisory_xact_lock(hashtext('guard.tick')) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', 'busy', 'mode', v_mode, 'actions', '[]'::jsonb);
  END IF;

  v_prefix := CASE WHEN v_enforce THEN '' ELSE 'OBSERVE ONLY. ' END;
  v_verb := CASE WHEN v_enforce THEN 'Switched off and stopped: ' ELSE 'Would switch off: ' END;

  -- 1. How full is the volume, as far as Postgres can see: all databases, the write-ahead log,
  --    plus a fixed overhead measured once against the figure of the host.
  v_used := (SELECT sum(pg_database_size(oid)) FROM pg_database)
          + (SELECT coalesce(sum(size), 0) FROM pg_ls_waldir())
          + v_overhead;
  v_pct := round(100 * v_used / v_volume, 1);
  v_level := CASE WHEN v_pct >= v_hard THEN 'hard' WHEN v_pct >= v_warn THEN 'warn' ELSE 'ok' END;

  SELECT CASE WHEN v_level = 'hard' THEN s.hard_ticks + 1 ELSE 0 END
  INTO v_hard_ticks FROM guard.state s;
  v_hard_ticks := coalesce(v_hard_ticks, 0);

  -- 2. Stored bytes per workflow. The data of a run is counted when the run ends (that is when
  --    n8n writes it); its files are counted when they are created.
  FOR r IN
    WITH al AS (
      SELECT DISTINCT ON (a ->> 'workflow_id')
             a ->> 'workflow_id' AS wf,
             (a ->> 'mb')::numeric * 1048576 AS budget,
             (a ->> 'from')::timestamptz AS t_from,
             (a ->> 'until')::timestamptz AS t_until
      FROM jsonb_array_elements(coalesce(cfg -> 'allowances', '[]'::jsonb)) a
      WHERE (a ->> 'from')::timestamptz <= now() AND (a ->> 'until')::timestamptz > now()
      ORDER BY a ->> 'workflow_id', (a ->> 'until')::timestamptz DESC
    ),
    horizon AS (
      SELECT least(now() - interval '60 minutes', coalesce((SELECT min(t_from) FROM al), now())) AS t0
    ),
    w AS (
      SELECT e."workflowId" AS wf,
             coalesce(e."stoppedAt", e."startedAt", e."createdAt") AS t,
             (coalesce(pg_column_size(d.data), 0) + coalesce(pg_column_size(d."workflowData"), 0))::numeric AS b
      FROM execution_entity e
      JOIN execution_data d ON d."executionId" = e.id
      WHERE coalesce(e."stoppedAt", e."startedAt", e."createdAt") > (SELECT t0 FROM horizon)
      UNION ALL
      SELECT coalesce(e."workflowId", '') AS wf, bd."createdAt" AS t, bd."fileSize"::numeric AS b
      FROM binary_data bd
      LEFT JOIN execution_entity e ON bd."sourceType" = 'execution' AND e.id::text = bd."sourceId"
      WHERE bd."createdAt" > (SELECT t0 FROM horizon)
    )
    SELECT w.wf,
           coalesce(sum(w.b) FILTER (WHERE w.t > now() - v_burst), 0) AS b_burst,
           coalesce(sum(w.b) FILTER (WHERE w.t > now() - interval '60 minutes'), 0) AS b_hour,
           coalesce(sum(w.b) FILTER (WHERE w.t >= al.t_from), 0) AS b_allow,
           max(al.budget) AS budget,
           max(al.t_from) AS t_from,
           max(al.t_until) AS t_until
    FROM w
    LEFT JOIN al ON al.wf = w.wf
    GROUP BY w.wf
  LOOP
    SELECT guard.plain(name) INTO v_name FROM workflow_entity WHERE id = r.wf;
    v_name := coalesce(v_name, CASE WHEN r.wf = '' THEN 'no stored run' ELSE guard.plain(r.wf) END);

    -- Files that belong to no stored run: nobody to switch off, so say so and name no cause.
    IF r.wf = '' THEN
      IF r.b_burst > v_lim_burst THEN
        v_notify := guard.note('unattributed', '', v_half_hour, v_mode, jsonb_build_object('b_burst', r.b_burst));
        IF v_notify THEN
          v_actions := v_actions || jsonb_build_object(
            'kind', 'unattributed', 'workflow_id', '', 'notify', true, 'enforce', false, 'targets', '[]'::jsonb,
            'subject', '[db-guard] files stored that belong to no run',
            'text', 'DB guard: ' || guard.mb(r.b_burst) || ' MB of files were stored in the last few minutes that belong to no stored run. Nothing was switched off. Cause unknown. Disk at ' || v_pct || '%.');
        END IF;
      END IF;
      CONTINUE;
    END IF;

    v_factor := coalesce((cfg -> 'factors' ->> r.wf)::numeric, 1);

    IF r.budget IS NOT NULL THEN
      -- An allowance replaces the rate limit until it expires. Tell once that it is in use.
      IF guard.note('allowance', r.wf, to_char(r.t_until, 'YYYY-MM-DD HH24:MI'), v_mode,
                    jsonb_build_object('budget', r.budget, 'from', r.t_from, 'until', r.t_until)) THEN
        v_actions := v_actions || jsonb_build_object(
          'kind', 'allowance', 'workflow_id', r.wf, 'notify', true, 'enforce', false, 'targets', '[]'::jsonb,
          'subject', '[db-guard] allowance active: ' || v_name,
          'text', 'DB guard: allowance active for ' || v_name || ': ' || guard.mb(r.budget) || ' MB until '
                  || to_char(r.t_until, 'YYYY-MM-DD HH24:MI TZ') || '. Used so far: ' || guard.mb(r.b_allow) || ' MB. Disk at ' || v_pct || '%.');
      END IF;
      v_act := r.b_burst > 0 AND r.b_allow > r.budget;
      v_text := v_name || ' used ' || guard.mb(r.b_allow) || ' MB of its ' || guard.mb(r.budget) || ' MB allowance';
    ELSE
      v_act := r.b_burst > 0 AND (r.b_burst > v_lim_burst * v_factor OR r.b_hour > v_lim_hour * v_factor);
      v_text := v_name || ' stored ' || guard.mb(r.b_burst) || ' MB in the last ' || extract(minute FROM v_burst)::integer
                || ' minutes and ' || guard.mb(r.b_hour) || ' MB in the last hour (limits ' || guard.mb(v_lim_burst * v_factor)
                || ' and ' || guard.mb(v_lim_hour * v_factor) || ' MB)';
    END IF;

    IF v_act THEN
      v_targets := guard.targets_for(r.wf, v_protected);
      v_notify := guard.note('rate_breach', r.wf, v_half_hour, v_mode,
                             jsonb_build_object('b_burst', r.b_burst, 'b_hour', r.b_hour, 'b_allow', r.b_allow,
                                                'budget', r.budget, 'factor', v_factor, 'targets', v_targets, 'pct', v_pct));
      v_actions := v_actions || jsonb_build_object(
        'kind', 'rate_breach', 'workflow_id', r.wf, 'notify', v_notify,
        'enforce', v_enforce AND jsonb_array_length(v_targets) > 0,
        'targets', v_targets,
        'subject', '[db-guard] blocked: ' || v_name,
        'text', 'DB guard: ' || v_prefix || v_text || '. '
                || CASE WHEN jsonb_array_length(v_targets) = 0
                        THEN 'No workflow to switch off was found (it is protected, or nothing with a trigger calls it).'
                        ELSE v_verb || guard.names(v_targets) || '.' END
                || ' Disk at ' || v_pct || '%. A big job needs an allowance: scripts/db-guard.sh allow.');
    END IF;
  END LOOP;

  -- 3. Runs that never end. n8n ends runs at its own time limit; this only reports leftovers,
  --    for example after a worker hung.
  FOR r IN
    SELECT e.id, e."workflowId" AS wf, guard.plain(w.name) AS name,
           round(extract(epoch FROM now() - e."startedAt") / 60) AS minutes
    FROM execution_entity e
    LEFT JOIN workflow_entity w ON w.id = e."workflowId"
    WHERE e.status = 'running' AND e."startedAt" < now() - v_max_run
  LOOP
    IF guard.note('stuck_run', r.wf, r.id::text, v_mode, jsonb_build_object('execution', r.id, 'minutes', r.minutes)) THEN
      v_actions := v_actions || jsonb_build_object(
        'kind', 'stuck_run', 'workflow_id', r.wf, 'notify', true, 'enforce', false, 'targets', '[]'::jsonb,
        'subject', '[db-guard] run does not end: ' || r.name,
        'text', 'DB guard: run ' || r.id || ' of ' || r.name || ' has been running for ' || r.minutes
                || ' minutes. Nothing was stopped. Cause unknown.');
    END IF;
  END LOOP;

  -- 4. The volume itself. No allowance overrides the hard stop.
  IF v_level = 'hard' AND v_hard_ticks >= v_hard_need THEN
    WITH writers AS (
      SELECT DISTINCT e."workflowId" AS id
      FROM execution_entity e
      JOIN execution_data d ON d."executionId" = e.id
      WHERE coalesce(e."stoppedAt", e."startedAt", e."createdAt") > now() - interval '60 minutes'
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', w.id, 'name', w.name, 'version_id', w."activeVersionId",
             'stop', w.id IN (SELECT id FROM writers)) ORDER BY w.name), '[]'::jsonb)
    INTO v_targets
    FROM workflow_entity w
    WHERE NOT (w.id = ANY (v_protected))
      AND (cardinality(v_scope) = 0 OR w.id = ANY (v_scope))
      AND ((w.active AND coalesce(w."triggerCount", 0) > 0) OR w.id IN (SELECT id FROM writers));

    v_notify := guard.note('hard_stop', '', to_char(now(), 'YYYY-MM-DD HH24'), v_mode,
                           jsonb_build_object('pct', v_pct, 'used', v_used, 'targets', v_targets));
    v_actions := v_actions || jsonb_build_object(
      'kind', 'hard_stop', 'workflow_id', '', 'notify', v_notify,
      'enforce', v_enforce AND jsonb_array_length(v_targets) > 0,
      'targets', v_targets,
      'subject', '[db-guard] HARD STOP: disk at ' || v_pct || '%',
      'text', 'DB guard HARD STOP: ' || v_prefix || 'disk at ' || v_pct || '% (' || guard.mb(v_used) || ' of '
              || guard.mb(v_volume) || ' MB). ' || v_verb || guard.names(v_targets)
              || '. Their published versions are recorded in guard.event. Free space before switching anything back on.');
  ELSIF v_level IN ('warn', 'hard') THEN
    IF guard.note('disk_warn', '', to_char(now(), 'YYYY-MM-DD'), v_mode, jsonb_build_object('pct', v_pct, 'used', v_used)) THEN
      v_actions := v_actions || jsonb_build_object(
        'kind', 'disk_warn', 'workflow_id', '', 'notify', true, 'enforce', false, 'targets', '[]'::jsonb,
        'subject', '[db-guard] disk at ' || v_pct || '%',
        'text', 'DB guard: disk at ' || v_pct || '% (' || guard.mb(v_used) || ' of ' || guard.mb(v_volume)
                || ' MB). Everything is switched off at ' || v_hard || '%.');
    END IF;
  END IF;

  -- 5. Housekeeping, in every mode: delete files whose run no longer exists. It names no workflow
  --    and switches nothing off. A failure here must not cost the verdict above.
  BEGIN
    v_swept := guard.sweep_files(coalesce((cfg ->> 'orphan_file_hours')::numeric, 1));
  EXCEPTION WHEN OTHERS THEN
    v_swept := jsonb_build_object('rows', 0, 'bytes', 0, 'error', SQLERRM);
  END;

  -- 6. Remember this check. If even this small write fails, still return the verdict.
  BEGIN
    UPDATE guard.state
    SET last_tick = now(), mode = v_mode, level = v_level, pct = v_pct,
        used_bytes = v_used::bigint, hard_ticks = v_hard_ticks;
    DELETE FROM guard.event WHERE at < now() - interval '180 days';
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'ok', true, 'skipped', NULL, 'mode', v_mode, 'level', v_level, 'pct', v_pct,
    'used_mb', round(v_used / 1048576.0, 1), 'hard_ticks', v_hard_ticks, 'swept', v_swept,
    'actions', (SELECT coalesce(jsonb_agg(a), '[]'::jsonb) FROM jsonb_array_elements(v_actions) a
                WHERE (a ->> 'notify')::boolean OR (a ->> 'enforce')::boolean));
END
$guard$;

-- What the outside heartbeat reads: is the guard alive, and how full is the volume.
CREATE OR REPLACE FUNCTION guard.status()
RETURNS jsonb
LANGUAGE sql STABLE AS $guard$
  SELECT jsonb_build_object(
    'ok', coalesce(s.last_tick > now() - interval '10 minutes', false) AND s.level IS DISTINCT FROM 'hard',
    'tick_age_s', round(extract(epoch FROM now() - s.last_tick)),
    'mode', s.mode, 'level', s.level, 'pct', s.pct)
  FROM guard.state s;
$guard$;
