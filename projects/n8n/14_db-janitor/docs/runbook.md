# DB growth guard: runbook

What each alert means, how to switch things back on, how to allow a big job, and what to do if
the disk fills up anyway.

## Why this exists

On 2026-10-01 a backup workflow started by hand stored every raw email in n8n's run history:
about 245 MB in one hour, on a 500 MB Postgres volume with no backups. Postgres crash-looped,
n8n answered `503 Database is not ready!`, and nothing had stopped the job or raised an alarm.

Three layers now stand in the way. Each covers what the one before it cannot.

| Layer | Acts | Covers |
|---|---|---|
| n8n's own limits (environment variables) | before a write | a run that never ends; history that never shrinks |
| The growth guard (this project): a small service next to Postgres | within one check, 2 minutes | a workflow that stores too much; a volume that fills up; n8n not ready |
| External heartbeat (`13_n8n-ops-center/docs/external-heartbeat.md`) | within hours | n8n, its database or the guard itself being down |

**The limit to know:** n8n writes the data of a run when the run *ends*. Nothing outside n8n can
veto that write. The guard therefore does not prevent the first oversized write; it prevents the
second. Replayed on the October incident: the first 8 MB chunk lands, the next check switches the
workflow off, total damage about 25 MB instead of 245 MB.

## Alerts

Every alert goes to Telegram, to the log of the service and to the table `guard.event`, once per
window. With SMTP variables set it is also an email; subjects start with `[db-guard]`.

| Subject | Meaning | What to do |
|---|---|---|
| `blocked: <workflow>` | The workflow stored more than its limit and is still writing. In `enforce` mode it (or, for a sub-workflow, whatever calls it) was switched off and its runs were stopped. | Find out why it stored that much. If it was a legitimate big job, give it an allowance (below) and switch it back on. |
| `allowance active: <workflow>` | A workflow with an allowance stored something. Log entry, no action. | Nothing. |
| `disk at N%` | The volume passed `warn_pct`. Sent once per day. | Check what grew (`scripts/db-guard.sh preflight`) before it reaches the hard stop. |
| `HARD STOP: disk at N%` | The volume was at or above `hard_pct` on two checks in a row. Every workflow with a trigger was switched off, except the error workflow. | Free space first (see the last section). Then switch workflows back on. |
| `run does not end: <workflow>` | A run has been `running` longer than `max_run_minutes`. Report only. | Stop it in the Executions list. A run that cannot be stopped usually means the worker hung: restart the worker. |
| `files stored that belong to no run` | Files appeared in `binary_data` whose run is not stored. Nobody to switch off, so no cause is named. | Run `scripts/db-guard.sh preflight` and look at `binary_orphans`. |
| `the guard is blind` | The check itself failed. Nothing is watching the database. Sent at most every 30 minutes. | Read the error in the message. Run `scripts/db-guard.sh preflight`; if that fails too, Postgres is the problem. |
| `could not switch off: <workflow>` | The n8n API refused the switch-off. The message carries the HTTP status. | Unpublish the workflow by hand. `401`/`403` means the API key is wrong or lacks the right. |
| `n8n is not ready` / `n8n is ready again` | `/healthz/readiness` did not answer 200 on two checks in a row. | Check the Postgres service first, then primary and worker. |
| `the guard cannot start` | A variable of the service is wrong; the message says which. | Fix the variable in Railway. |
| Heartbeat: `the growth guard does not answer` / `has not checked the database` | From outside: the guard service is down or hangs. | Open the deploy log of the service in Railway. |

In `observe` mode every message starts with `OBSERVE ONLY` and says what *would* be switched off.

## Switching a workflow back on

The guard unpublishes; it never deletes or edits anything. To undo:

1. Fix or understand the cause first. While the workflow is over its hourly limit and writes
   again, the guard switches it off again on the next check.
2. Publish it in the n8n editor.

Publishing in the editor publishes the **current draft**. If the workflow had unpublished edits,
that is not the version that was live. The guard recorded the live version of every workflow it
switched off:

```sql
SELECT at, kind, detail -> 'targets' AS targets
FROM guard.event
WHERE kind IN ('rate_breach', 'hard_stop')
ORDER BY at DESC LIMIT 5;
```

Each target carries `version_id`. To publish exactly that version:

```
POST /api/v1/workflows/<id>/publish     body: { "versionId": "<version_id>" }
```

## Allowing a big job

Deny by default: there is no button and no form. A big job is blocked unless an allowance covers
it. One command, from a terminal:

```bash
scripts/db-guard.sh allow <workflow id> <MB> <hours>
```

- The workflow may store `<MB>` in total during the next `<hours>`. Its rate limits are off for
  that time; everything else stays as it is.
- It expires by itself. `scripts/db-guard.sh status` lists the open ones.
- The hard stop ignores allowances.
- The first write under an allowance sends one `allowance active` message, as a log.
- Estimate the size before you grant it: stored runs times the size of one run. If the job
  stores nothing by design (`saveDataSuccessExecution` and `saveDataErrorExecution` both `none`),
  it needs no allowance at all, only a run-time limit long enough to finish.

## The limits

The defaults are in `service/config.json`. Change them per instance with the service variable
`GUARD_CONFIG`, one JSON object that overrides single values, for example
`{"overhead_mb":43,"factors":{"<workflow id>":3}}`. The mode is its own variable.

| Value | Default | Meaning |
|---|---|---|
| `GUARD_MODE` (variable) | `observe` | `enforce` switches off and stops. `observe` only reports. |
| `default_mb_burst` / `burst_minutes` | 5 MB / 3 min | A workflow may store this much within the burst window |
| `default_mb_hour` | 20 MB | ... and this much within 60 minutes |
| `factors` | `{}` | Multiplies both limits for one workflow id |
| `warn_pct` / `hard_pct` | 70 / 85 | Volume levels, in percent of `volume_mb` |
| `volume_mb` / `overhead_mb` | 500 / 0 | Size of the volume, and what the host counts beyond databases and write-ahead log |
| `max_run_minutes` | 120 | A `running` run older than this is reported |
| `protected` | `[]` | Never switched off. Workflows with an Error Trigger are added automatically |
| `hard_stop_scope` | `[]` | For drills: limit the hard stop to these workflow ids |

"Stored" means the data n8n keeps for a run, as it sits on disk, plus the files of that run in
`binary_data`. A run that is deleted after success stores nothing and counts as nothing.

A workflow is only blocked while it is **still writing**: over its hourly limit but quiet for the
last few minutes means no action.

To check the limits against your own history, run `scripts/db-guard.sh preflight` and read
`peaks`: the most each workflow ever stored within 3 and within 60 minutes. A limit should
sit clearly above the normal peak and far below the free space.

`overhead_mb` is calibrated once: take the volume figure your host shows, subtract
`all_databases_bytes + wal_bytes` from the same `preflight` run.

## Setup from scratch

The guard is one small service next to Postgres. There is nothing to import or configure in n8n.
On Railway:

1. **New service** in the project that holds n8n: source = this repository, **Root Directory**
   `projects/n8n/14_db-janitor`. Railway builds the `Dockerfile` it finds there.
2. **Variables**: paste [`docs/railway/db-guard.env.example`](../../docs/railway/db-guard.env.example)
   into the Raw Editor and fill in the placeholders. Only `DATABASE_URL` is required, and it is a
   reference, not a typed value.
3. **Deploy.** The log must show `guard installed, mode=observe` and then one `ok ...` line every
   two minutes. The service creates the schema `guard` itself; it touches nothing of n8n.
4. **Calibrate** `overhead_mb`: take the volume figure the host shows and subtract the `used_mb`
   of a log line from the same minute.
5. **After a day without false alarms** set `GUARD_MODE` to `enforce`. That needs
   `N8N_BASE_URL` and `N8N_API_KEY`.
6. **Outside heartbeat** (optional): set `PORT`, generate a domain for the service, then set the
   repository variables `GUARD_STATUS_URL` (`https://<domain>/status.json`) and
   `HEARTBEAT_GUARD_CHECK=required`.

On any other host: run the image wherever it can reach the database, with the same variables.

`scripts/db-guard.sh` is for the operator, not for setup: `preflight` (read-only facts), `status`,
`allow`. It uses `DATABASE_URL` with a local `psql` if set; otherwise the Railway CLI, which runs
`psql` inside the Postgres container (`railway login` once, then `railway link` or the variables
`RAILWAY_PROJECT`, `RAILWAY_ENVIRONMENT`, `RAILWAY_PG_SERVICE`).

The write-ahead log lives on the same volume as the data, and the Postgres default lets it grow
to 1 GB. `preflight` shows `max_wal_size`; `scripts/db-guard.sh tune-wal` caps it at 64 MB.

The instance-wide variables that belong to this (pruning, run-time limit) are listed in
[`docs/infra-ops.md`](../../docs/infra-ops.md).

## Drill

`db-guard-sandbox-writer` (on the instance: `ZZ_db-guard-test [sandbox]`) stores 3 MB of random
text per minute.

1. Guard in `enforce` mode. Import and publish the sandbox workflow.
2. Within two checks: one Telegram message `blocked: ZZ db-guard-test`, the sandbox is
   unpublished again.
3. Delete the runs of the sandbox workflow.

Hard-stop drill: in `GUARD_CONFIG`, put the sandbox id into `hard_stop_scope` and lower `hard_pct`
below the current level. After two checks only the sandbox is switched off. Reset both values
afterwards.

## Tests

`tests/guard.test.mjs` runs the rules against a throwaway Postgres with a minimal copy of n8n's
tables: normal load, the October incident, sub-workflow callers, factors, allowances, dedup, warn
and hard stop, stuck runs, orphan files. The loop around the rules (`service/guard-loop.sh`) has
no test file; it was tested by hand in its image against stand-ins for n8n and Telegram. The rule
tests need Node, the `pg` package and any empty Postgres
16 database it may wipe:

```bash
PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=... PGDATABASE=guard_test \
  node projects/n8n/14_db-janitor/tests/guard.test.mjs
```

Never point it at a real n8n database: it drops and recreates the tables it reads.

## If the disk is full anyway

Symptoms: Postgres restarts in a loop with `could not write to file "pg_wal/xlogtemp"` or
`No space left on device`; n8n answers `503 Database is not ready!`; `/healthz` still says 200.

A full Postgres cannot delete its way out: deleting needs to write the log first. The way out is
to give the log room for a moment. This worked on 2026-10-01 (Postgres 16, Railway, no data lost).
It is delicate; read it to the end before starting.

**Never** delete or recreate the volume or the service, and do not touch `N8N_ENCRYPTION_KEY`.

1. **Stop the crash loop without losing the container.** Set the start command of the Postgres
   service to `sleep infinity`, and pin the image by digest so the redeploy cannot pull a newer
   major version. Note the original start command.
2. **Open a shell in the container** and copy the data directory to the container's own disk as
   a safety copy.
3. **Move `pg_wal` off the volume** to the container's own disk and leave a symlink in its
   place. The container's disk is temporary: from here until step 6, a restart of the container
   loses the log and with it the database. Do not redeploy, do not restart.
4. **Start Postgres by hand** on a port n8n does not use (for example 5433), as the `postgres`
   system user.
5. **Free space.** Delete the runs that caused it (`DELETE FROM execution_entity WHERE ...`;
   their data rows follow), delete files in `binary_data` that belong to no run, then `VACUUM`,
   then `VACUUM FULL execution_data`. Only `VACUUM FULL` gives space back to the volume, and it
   needs free space of about the size the table will have afterwards.
6. **Stop Postgres cleanly** with `pg_ctl stop`, remove the symlink and move `pg_wal` back onto
   the volume. Check the volume has room for it now.
7. **Restore the original start command**, redeploy Postgres, then restart n8n's primary and
   worker. Keep the image pinned.

Afterwards: find out what filled it, and check that the guard service is running and the
heartbeat variables are set, because one of them should have told you.
