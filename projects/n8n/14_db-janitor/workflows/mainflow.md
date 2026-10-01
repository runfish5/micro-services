# DB growth guard

> Checks n8n's own Postgres database every 2 minutes. A workflow that stores too much is reported,
> switched off and stopped. Big jobs are denied by default and need a time-limited allowance.
> Built after a backup run filled a 500 MB volume in one hour (2026-10-01).

Alerts, allowances, setup, drills and disk-full recovery: [`../docs/runbook.md`](../docs/runbook.md).

**The guard is not an n8n workflow.** It is a small service that runs next to Postgres: bash,
`psql`, `curl` and `jq` in one container. Reasons:

- Nothing to import, no credentials to create or pick inside n8n. It gets the database through
  one variable and installs its own schema at start.
- It keeps running when n8n is down, and reports that too.
- No database superuser credential sits in n8n, where every workflow could use it.

An earlier draft was a 25-node workflow. It worked, but needed four credentials, a separate
install step, and an n8n that is up in order to watch the database n8n depends on.

## Files

| File | What it is |
|---|---|
| `Dockerfile` | The image: Alpine with bash, psql, curl, jq |
| `service/guard-loop.sh` | The loop: ask Postgres, send alerts, switch workflows off through the n8n API |
| `service/config.json` | The limits. Overridden per instance with the variable `GUARD_CONFIG` |
| `sql/guard.sql` | All rules: schema `guard`, `guard.tick(cfg)`, `guard.status()`. Installed by the service at every start |
| `sql/tick.sql` | One check: adds open allowances and the error handler's id to the config, calls `guard.tick` |
| `sql/preflight-database.sql`, `sql/preflight-history.sql` | Read-only facts about the database and n8n's stored runs |
| `sql/status.sql`, `sql/tune-wal.sql` | Last check plus open allowances; cap the write-ahead log |
| `scripts/db-guard.sh` (repo root) | The operator's commands: `preflight`, `status`, `allow`, `tune-wal`, `install` |
| `workflows/db-guard-sandbox-writer.json` | Drill target, the only n8n workflow here: stores random bytes every minute. Unpublished except during a drill |
| `tests/guard.test.mjs` | Scenario tests for the rules, against a throwaway Postgres |
| `../docs/railway/db-guard.env.example` | The service's variables on Railway |

## One check

```
every 120 s:
  psql -f sql/tick.sql  ──fails──>  "the guard is blind" (at most every 30 min)
        │
        ▼  one JSON document: level, pct, actions[]
  write status.json  (served on $PORT for the outside heartbeat)
  for each action:
     notify  → Telegram (+ email if SMTP is set)          tell first,
     enforce → for each target:                           then act
                 POST /api/v1/workflows/{id}/deactivate
                 POST /api/v1/executions/stop   {workflowId}   (never a global stop)
  GET n8n /healthz/readiness  ──not 200 twice in a row──>  "n8n is not ready"
```

**One query, always one row.** `guard.tick` returns one JSON document even when there is nothing
to do, so the loop never has to tell "no rows" from "no answer".

**The loop decides nothing.** Every rule is in `sql/guard.sql` and covered by the tests. The
loop only carries messages and API calls, and no failed message can stop a switch-off.

**A failure names no cause.** A failed check sends the raw `psql` error. A failed switch-off
sends the HTTP status and says the workflow is probably still on.

## What `guard.tick` decides

1. **Volume level**: all databases plus the write-ahead log plus `overhead_mb`, as a percentage of
   `volume_mb`. `warn` at `warn_pct`, `hard` at `hard_pct`.
2. **Stored bytes per workflow** in the burst window and in the last 60 minutes: run data counted
   when the run ended, files counted when they were created.
3. **Breach**: still writing, and over either limit (limit × factor), or over its allowance.
4. **Targets**: the workflow itself if it starts runs on its own; otherwise the workflows that
   call it (found by its id in their nodes, up to four levels) and that own a trigger. Protected
   workflows are never targets; every workflow with an Error Trigger is protected automatically.
5. **Hard stop** after `hard` on two checks in a row: every workflow with a trigger, plus every
   workflow that wrote in the last hour.
6. **Stuck runs**: `running` longer than `max_run_minutes`. Report only.
7. **Leftover files**: files in `binary_data` whose run no longer exists and that are older than
   `orphan_file_hours` are deleted, at most 500 per check, in every mode. n8n keeps the files of a
   run (attachments, downloads) in that table and does not delete them when it removes the run.
   This is the only thing the guard deletes in n8n's own tables; the log line shows
   `swept_files` when it did.

Each alert is written to `guard.event` with a window key (half hour, day, or the run id). A second
alert with the same key is not sent. The switch-off is repeated on every check while the breach
lasts, the message is not.

## db-guard-sandbox-writer

```
When Sandbox Ticks (1 min) --> Config (mb_per_run: 3) --> Build Random Payload
```

On the instance it is named `ZZ_db-guard-test [sandbox]`. It exists to be caught: publish it,
watch the guard switch it off, delete its runs. No credentials.
