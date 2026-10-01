-- Read-only. Facts about the tables of n8n itself: pruning, stored bytes per workflow, peaks, files.
-- Assumes n8n 2.x table and column names; preflight-database.sql lists the real ones.
-- "Stored bytes" = on-disk size of the data of a run (pg_column_size reads the stored, compressed
-- size without unpacking it) plus the files that run keeps in binary_data.
WITH ex AS (
  SELECT e.id, e."workflowId" AS wf, e.mode, e.status, e."startedAt", e."stoppedAt",
         coalesce(pg_column_size(d.data), 0) + coalesce(pg_column_size(d."workflowData"), 0) AS data_bytes,
         coalesce((SELECT sum(b."fileSize") FROM binary_data b
                   WHERE b."sourceType" = 'execution' AND b."sourceId" = e.id::text), 0) AS binary_bytes
  FROM execution_entity e
  LEFT JOIN execution_data d ON d."executionId" = e.id
)
SELECT jsonb_build_object(
  -- Pruning: separates the candidate causes without guessing one.
  'executions', (
    SELECT jsonb_agg(q ORDER BY q.n DESC)
    FROM (
      SELECT status, mode, count(*) AS n,
             count(*) FILTER (WHERE "deletedAt" IS NOT NULL) AS soft_deleted,
             count(*) FILTER (WHERE "stoppedAt" IS NULL) AS no_stopped_at,
             count(*) FILTER (WHERE "stoppedAt" < now() - interval '14 days'
                              AND "deletedAt" IS NULL) AS overdue_14d,
             min("startedAt") AS oldest, max("startedAt") AS newest
      FROM execution_entity GROUP BY status, mode) q),
  'by_month', (
    SELECT jsonb_object_agg(m, n)
    FROM (SELECT to_char("startedAt", 'YYYY-MM') AS m, count(*) AS n
          FROM execution_entity WHERE "startedAt" IS NOT NULL GROUP BY 1) q),
  'annotations_table', to_regclass('public.execution_annotations') IS NOT NULL,
  'per_workflow', (
    SELECT jsonb_agg(q ORDER BY q.bytes DESC)
    FROM (
      SELECT ex.wf, w.name, count(*) AS n,
             sum(ex.data_bytes) AS data_bytes, sum(ex.binary_bytes) AS binary_bytes,
             sum(ex.data_bytes + ex.binary_bytes) AS bytes,
             max(ex.data_bytes + ex.binary_bytes) AS max_run_bytes,
             round(max(extract(epoch FROM ex."stoppedAt" - ex."startedAt"))) AS max_runtime_s,
             jsonb_agg(DISTINCT ex.mode) AS modes
      FROM ex LEFT JOIN workflow_entity w ON w.id = ex.wf
      GROUP BY ex.wf, w.name) q),
  -- Back-test: the most each workflow ever stored within any 3-minute and 60-minute window.
  'peaks', (
    SELECT jsonb_agg(q ORDER BY q.peak_60min DESC)
    FROM (
      SELECT s.wf, max(s.b3) AS peak_3min, max(s.b60) AS peak_60min
      FROM (
        SELECT x.wf,
               sum(x.b) OVER (PARTITION BY x.wf ORDER BY x.t
                              RANGE BETWEEN interval '3 minutes' PRECEDING AND CURRENT ROW) AS b3,
               sum(x.b) OVER (PARTITION BY x.wf ORDER BY x.t
                              RANGE BETWEEN interval '60 minutes' PRECEDING AND CURRENT ROW) AS b60
        FROM (SELECT wf, "stoppedAt" AS t, data_bytes + binary_bytes AS b
              FROM ex WHERE "stoppedAt" IS NOT NULL) x) s
      GROUP BY s.wf) q),
  'per_day_last_30', (
    SELECT jsonb_object_agg(d, b)
    FROM (SELECT to_char("stoppedAt", 'YYYY-MM-DD') AS d, sum(data_bytes + binary_bytes) AS b
          FROM ex WHERE "stoppedAt" > now() - interval '30 days' GROUP BY 1) q),
  'binary', (
    SELECT jsonb_build_object('rows', count(*), 'file_bytes', coalesce(sum("fileSize"), 0),
                              'table_bytes', pg_total_relation_size('binary_data'))
    FROM binary_data),
  'binary_by_source', (
    SELECT jsonb_object_agg(coalesce(q.t, 'null'), q.j)
    FROM (SELECT "sourceType"::text AS t,
                 jsonb_build_object('rows', count(*), 'bytes', coalesce(sum("fileSize"), 0)) AS j
          FROM binary_data GROUP BY 1) q),
  'binary_orphans', (
    SELECT jsonb_build_object('rows', count(*), 'bytes', coalesce(sum(b."fileSize"), 0),
                              'oldest', min(b."createdAt"), 'newest', max(b."createdAt"))
    FROM binary_data b
    WHERE b."sourceType" = 'execution'
      AND NOT EXISTS (SELECT 1 FROM execution_entity e WHERE e.id::text = b."sourceId")),
  -- Policy lint. to_jsonb(w) is used so that a column this n8n version lacks reads as null
  -- instead of failing the whole query.
  'workflows', (
    SELECT jsonb_agg(jsonb_build_object(
             'id', w.id, 'name', w.name, 'active', w.active,
             'trigger_count', to_jsonb(w) -> 'triggerCount',
             'version', to_jsonb(w) ->> 'versionId',
             'active_version', to_jsonb(w) ->> 'activeVersionId',
             'archived', to_jsonb(w) -> 'isArchived',
             'save_success', w.settings::jsonb ->> 'saveDataSuccessExecution',
             'save_error', w.settings::jsonb ->> 'saveDataErrorExecution',
             'timeout_s', w.settings::jsonb ->> 'executionTimeout')
           ORDER BY w.active DESC, w.name)
    FROM workflow_entity w),
  'in_flight', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id', id, 'wf', "workflowId", 'mode', mode, 'status', status,
             'age_s', round(extract(epoch FROM now() - "startedAt")), 'wait_till', "waitTill")), '[]'::jsonb)
    FROM execution_entity WHERE status IN ('new', 'running', 'waiting'))
) AS facts;
