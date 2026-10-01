// Scenario tests for guard.tick (sql/guard.sql) against a THROWAWAY Postgres 16 database.
//
//   npm install --no-save pg
//   PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=... PGDATABASE=guard_test node guard.test.mjs
//
// It drops and recreates execution_entity, execution_data, binary_data, workflow_entity and the
// schema `guard` in that database. Never point it at a real n8n database.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
const HERE = path.dirname(fileURLToPath(import.meta.url));
if (!process.env.PGDATABASE || /^(railway|n8n|postgres)$/i.test(process.env.PGDATABASE)) {
  console.error('Set PGDATABASE to a throwaway database (not railway, n8n or postgres). This test wipes tables.');
  process.exit(2);
}
const conn = {}; // host, port, user, password and database come from the PG* environment variables
const c = new pg.Client(conn);
await c.connect();
const q = async (sql, p) => (await c.query(sql, p)).rows;
const R = path.join(HERE, '..', 'sql') + path.sep;
let fails = 0;
const ok = (name, cond, extra = '') => { console.log((cond ? 'PASS ' : 'FAIL ') + name + (cond ? '' : '  ' + extra)); if (!cond) fails++; };

const reset = async () => {
  await c.query(fs.readFileSync(path.join(HERE, 'fake-n8n-schema.sql'), 'utf8'));
  await c.query('DROP SCHEMA IF EXISTS guard CASCADE');
  await c.query(fs.readFileSync(R + 'guard.sql', 'utf8'));
  // organizer (gmail trigger) -> crm (sub) -> search (sub); organizer -> converter (sub); backfill calls itself by expression
  await c.query(`INSERT INTO workflow_entity (id, name, active, nodes, "versionId", "activeVersionId", "triggerCount") VALUES
    ('ORG', '04_inbox-attachment-organizer', true, '[{"p":"calls CRM and CONV"}]', 'v-org', 'v-org', 1),
    ('CRM', 'smart-CRM-fill', true, '[{"p":"calls SEARCH"}]', 'v-crm', 'v-crm', 0),
    ('SEARCH', 'record-search', true, '[]', 'v-s', 'v-s', 0),
    ('CONV', 'any-file2json-converter', true, '[]', 'v-c', 'v-c', 0),
    ('BACK', 'inbox-backfill', true, '[{"p":"={{ $workflow.id }}"}]', 'v-b2', 'v-b1', 1),
    ('ERRH', '007_error-handler.n8n', true, '[]', 'v-e', 'v-e', 1),
    ('GUARD', 'db-growth-guard', true, '[]', 'v-g', 'v-g', 1),
    ('BRIEF', 'daily briefing', true, '[]', 'v-d', 'v-d', 1),
    ('OFF', 'My workflow 8', false, '[]', 'v-o', null, 0)`);
};
// one finished run that stored `mb` MB, `agoMin` minutes ago
const run = async (wf, mode, mb, agoMin, status = 'success') => {
  const [{ id }] = await q(`INSERT INTO execution_entity (mode, status, "workflowId", "startedAt", "stoppedAt", finished)
    VALUES ($1::text, $2::text, $3::text, now() - make_interval(mins => $4::int + 1), CASE WHEN $2::text = 'running' THEN NULL ELSE now() - make_interval(mins => $4::int) END, $2::text = 'success') RETURNING id`, [mode, status, wf, agoMin]);
  // random bytes as text: does not compress, so the stored size is close to the nominal size
  await c.query(`INSERT INTO execution_data ("executionId", "workflowData", data)
    SELECT $1, '{}', string_agg(md5(random()::text || g::text), '') FROM generate_series(1, greatest(1, ($2::numeric * 32768)::int)) g`, [id, mb]);
  return id;
};
const base = { volume_mb: 500, overhead_mb: 0, default_mb_burst: 5, default_mb_hour: 20, protected: ['GUARD', 'ERRH'] };
const tick = async (cfg) => (await q('SELECT guard.tick($1::jsonb) AS t', [JSON.stringify({ ...base, ...cfg })]))[0].t;
const kinds = (t) => t.actions.map(a => `${a.kind}:${a.workflow_id}:${a.notify ? 'N' : '-'}${a.enforce ? 'E' : '-'}:[${a.targets.map(x => x.id)}]`).join(' | ');

// 1 normal load
await reset();
await run('ORG', 'trigger', 0.3, 1); await run('CRM', 'integrated', 0.1, 1); await run('BRIEF', 'trigger', 0.05, 30);
let t = await tick({ mode: 'enforce' });
ok('1 normal load: no action', t.actions.length === 0 && t.level === 'ok', kinds(t));

// 2 incident replay: backfill parent (manual, running) + chunk children storing 8 MB each
await reset();
await run('BACK', 'manual', 0.01, 0, 'running');
await run('BACK', 'integrated', 8, 1);
t = await tick({ mode: 'observe' });
ok('2a incident, observe: reported, not enforced', kinds(t) === 'rate_breach:BACK:N-:[BACK]', kinds(t));
console.log('     text:', t.actions[0]?.text);
t = await tick({ mode: 'enforce' });
ok('2b incident, enforce, same half hour: enforced, alert not repeated', kinds(t) === 'rate_breach:BACK:-E:[BACK]', kinds(t));
ok('2c recorded published version is the active one', t.actions[0]?.targets[0]?.version_id === 'v-b1', JSON.stringify(t.actions[0]?.targets));

// 3 sub-workflow offender two levels down: switch off the trigger owner, not the sub-workflow
await reset();
await run('ORG', 'trigger', 0.2, 1); await run('SEARCH', 'integrated', 9, 1);
t = await tick({ mode: 'enforce' });
ok('3 sub-workflow breach targets its trigger-owning caller', kinds(t) === 'rate_breach:SEARCH:NE:[ORG]', kinds(t));
console.log('     text:', t.actions[0]?.text);

// 4 per-workflow factor
await reset();
await run('ORG', 'trigger', 20, 1);
t = await tick({ mode: 'enforce', factors: { ORG: 5 } });
ok('4a factor 5: 20 MB burst allowed', t.actions.length === 0, kinds(t));
t = await tick({ mode: 'enforce' });
ok('4b without factor: blocked', kinds(t) === 'rate_breach:ORG:NE:[ORG]', kinds(t));

// 5 allowance
await reset();
await run('BACK', 'manual', 0.01, 0, 'running'); await run('BACK', 'integrated', 30, 1);
const now = Date.now(), iso = (ms) => new Date(ms).toISOString();
t = await tick({ mode: 'enforce', allowances: [{ workflow_id: 'BACK', mb: 150, from: iso(now - 3600e3), until: iso(now + 3600e3) }] });
ok('5a allowance covers 30 MB: only the "allowance active" note', kinds(t) === 'allowance:BACK:N-:[]', kinds(t));
t = await tick({ mode: 'enforce', allowances: [{ workflow_id: 'BACK', mb: 20, from: iso(now - 3600e3), until: iso(now + 3600e3) }] });
ok('5b allowance exceeded: blocked', kinds(t).includes('rate_breach:BACK:NE:[BACK]'), kinds(t));
await c.query('DELETE FROM guard.event');
t = await tick({ mode: 'enforce', allowances: [{ workflow_id: 'BACK', mb: 150, from: iso(now - 7200e3), until: iso(now - 60e3) }] });
ok('5c expired allowance: blocked again', kinds(t) === 'rate_breach:BACK:NE:[BACK]', kinds(t));

// 6 hourly limit, and a workflow that stopped writing is left alone
await reset();
for (const m of [50, 40, 30, 20, 10]) await run('BRIEF', 'trigger', 4.5, m);
t = await tick({ mode: 'enforce' });
ok('6a over the hourly limit but quiet now: no action', t.actions.length === 0, kinds(t));
await run('BRIEF', 'trigger', 1, 1);
t = await tick({ mode: 'enforce' });
ok('6b over the hourly limit and still writing: blocked', kinds(t) === 'rate_breach:BRIEF:NE:[BRIEF]', kinds(t));

// 7 protected offender: alert, nothing switched off
await reset();
await run('ERRH', 'error', 9, 1);
t = await tick({ mode: 'enforce' });
ok('7 protected workflow: alert only', kinds(t) === 'rate_breach:ERRH:N-:[]', kinds(t));

// 8 disk warning once per day, hard stop after two checks in a row
await reset();
await run('ORG', 'trigger', 0.2, 1);
const used = (await tick({})).used_mb;
t = await tick({ mode: 'enforce', volume_mb: Math.round(used / 0.75) });
ok('8a warn level: one warning', kinds(t) === 'disk_warn::N-:[]' && t.level === 'warn', kinds(t) + ' ' + t.pct);
t = await tick({ mode: 'enforce', volume_mb: Math.round(used / 0.75) });
ok('8b warning not repeated the same day', t.actions.length === 0, kinds(t));
await c.query('DELETE FROM guard.event');
t = await tick({ mode: 'enforce', volume_mb: Math.round(used / 0.9) });
ok('8c first check at hard level: warning only', kinds(t) === 'disk_warn::N-:[]' && t.hard_ticks === 1, kinds(t) + ' ticks ' + t.hard_ticks);
t = await tick({ mode: 'enforce', volume_mb: Math.round(used / 0.9) });
ok('8d second check: hard stop of every trigger owner and writer, except protected',
  kinds(t) === 'hard_stop::NE:[ORG,BRIEF,BACK]', kinds(t));
ok('8e only the writer gets its runs stopped', JSON.stringify(t.actions[0].targets.filter(x => x.stop).map(x => x.id)) === '["ORG"]', JSON.stringify(t.actions[0].targets));
console.log('     text:', t.actions[0]?.text);
t = await tick({ mode: 'enforce', volume_mb: Math.round(used / 0.9), hard_stop_scope: ['BRIEF'] });
ok('8f drill scope limits the hard stop', kinds(t) === 'hard_stop::-E:[BRIEF]', kinds(t));
t = await tick({ mode: 'enforce' });
ok('8g back to normal resets the counter', t.hard_ticks === 0 && t.actions.length === 0, kinds(t));

// 9 stuck run reported once
await reset();
await c.query(`INSERT INTO execution_entity (mode, status, "workflowId", "startedAt") VALUES ('manual', 'running', 'BACK', now() - interval '5 hours')`);
t = await tick({ mode: 'enforce' });
ok('9a stuck run reported', kinds(t) === 'stuck_run:BACK:N-:[]', kinds(t));
t = await tick({ mode: 'enforce' });
ok('9b ... once', t.actions.length === 0, kinds(t));

// 10 files without a stored run
await reset();
await c.query(`INSERT INTO binary_data ("sourceType", "sourceId", data, "fileSize") VALUES ('execution', '999999', '\\x00', 9000000)`);
t = await tick({ mode: 'enforce' });
ok('10 orphan files: named as unattributed, no cause guessed', kinds(t) === 'unattributed::N-:[]', kinds(t));

// 11 files of a running run count before the run ends
await reset();
const rid = await run('BACK', 'manual', 0.01, 0, 'running');
await c.query(`INSERT INTO binary_data ("sourceType", "sourceId", data, "fileSize") VALUES ('execution', $1, '\\x00', 7000000)`, [String(rid)]);
t = await tick({ mode: 'enforce' });
ok('11 files of a running run are seen before it ends', kinds(t) === 'rate_breach:BACK:NE:[BACK]', kinds(t));

// 12 one check at a time
await reset();
const c2 = new pg.Client(conn); await c2.connect();
await c2.query('BEGIN'); await c2.query(`SELECT pg_advisory_xact_lock(hashtext('guard.tick'))`);
t = await tick({ mode: 'enforce' });
ok('12 a second check while one runs is skipped', t.skipped === 'busy', JSON.stringify(t));
await c2.query('ROLLBACK'); await c2.end();

// 13 status
await tick({});
const [{ s }] = await q('SELECT guard.status() AS s');
ok('13 status after a check', s.ok === true && s.tick_age_s < 5 && s.level === 'ok', JSON.stringify(s));

// 14 unknown mode never enforces
await reset();
await run('BRIEF', 'trigger', 9, 1);
t = await tick({ mode: 'Enforce ' });
ok('14 a mistyped mode observes', kinds(t) === 'rate_breach:BRIEF:N-:[BRIEF]' && t.mode === 'observe', kinds(t));

// 15 speed with a realistic history
await reset();
await c.query(`INSERT INTO execution_entity (mode, status, "workflowId", "startedAt", "stoppedAt", finished)
  SELECT 'trigger', 'success', 'ORG', now() - make_interval(mins => g * 40), now() - make_interval(mins => g * 40), true FROM generate_series(1, 4000) g`);
await c.query(`INSERT INTO execution_data ("executionId", "workflowData", data) SELECT id, '{}', repeat(md5(id::text), 800) FROM execution_entity`);
const t0 = Date.now(); t = await tick({ mode: 'enforce' }); const ms = Date.now() - t0;
ok(`15 check over 4000 stored runs takes ${ms} ms`, ms < 500 && t.actions.length === 0, kinds(t));

// 16 files whose run no longer exists are deleted, and only those
await reset();
const file = (sourceId, agoMin, type = 'execution') => c.query(
  `INSERT INTO binary_data ("sourceType", "sourceId", data, "fileSize", "createdAt") VALUES ($1::text, $2::text, '\\x00', 1000, now() - make_interval(mins => $3::int))`,
  [type, String(sourceId), agoMin]);
const kept = await run('ORG', 'trigger', 0.01, 300);
const marked = await run('ORG', 'trigger', 0.01, 300);
await c.query(`UPDATE execution_entity SET "deletedAt" = now() WHERE id = $1`, [marked]);
await file(999001, 300);            // run gone, old: delete
await file(999002, 10);             // run gone, but young: keep for now
await file(kept, 300);              // run exists: keep
await file(marked, 300);            // run only marked as deleted: keep until n8n removes the row
await file(999003, 300, 'chat');    // not a file of a run: never touched
t = await tick({ mode: 'observe' });
let left = (await q(`SELECT "sourceId" FROM binary_data ORDER BY 1`)).map(r => r.sourceId).join(',');
ok('16 old files without a run are deleted, in observe mode too', t.swept.rows === 1 && t.swept.bytes == 1000 && left === [kept, marked, 999002, 999003].map(String).sort().join(','), JSON.stringify(t.swept) + ' ' + left);

// 17 the clean-up can be switched off
await reset();
await file(999001, 300);
t = await tick({ orphan_file_hours: 0 });
ok('17 orphan_file_hours 0 deletes nothing', t.swept.rows === 0 && (await q('SELECT count(*)::int AS n FROM binary_data'))[0].n === 1, JSON.stringify(t.swept));

// 18 a large backlog goes in pieces
await reset();
await c.query(`INSERT INTO binary_data ("sourceType", "sourceId", data, "fileSize", "createdAt") SELECT 'execution', (900000 + g)::text, '\\x00', 10, now() - interval '2 hours' FROM generate_series(1, 1200) g`);
t = await tick({});
const t2 = await tick({}); const t3 = await tick({});
ok('18 1200 leftover files go in pieces of 500', t.swept.rows === 500 && t2.swept.rows === 500 && t3.swept.rows === 200, [t, t2, t3].map(x => x.swept.rows).join(','));

await c.end();
console.log(fails ? `\n${fails} FAILED` : '\nall passed');
process.exitCode = fails ? 1 : 0;
