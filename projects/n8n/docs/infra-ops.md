# Infrastructure Operations

Infrastructure and container-layer operations for the n8n instance. Separate from n8n workflow-level troubleshooting (see `troubleshooting.md`).

## Binary Data Mode

n8n keeps binary data (email attachments, PDFs, images) for as long as it keeps the run they
belong to. Where it keeps them depends on `N8N_DEFAULT_BINARY_DATA_MODE`:

| Mode | Where | Works in queue mode? |
|---|---|---|
| `database` | table `binary_data` in PostgreSQL | yes. This is what a queue-mode instance uses |
| `filesystem` | files on the n8n container's disk | **no.** Primary and worker are separate containers with no shared disk, so one cannot read what the other wrote |
| `s3` | external object storage | yes, licensed feature |

An earlier version of this page recommended `filesystem`. That advice only holds for a
single-container instance. On the queue-mode setup described here, attachments live in Postgres
and count against its volume: the inbox-attachment-organizer stores about 237 KB per run.

So the size of the database is governed by three things, in this order: which runs are stored at
all (workflow settings `saveDataSuccessExecution` / `saveDataErrorExecution`), how long they are
kept (pruning, below), and the growth guard, which catches whatever the first two let through.

## Execution Pruning (n8n Built-in)

n8n deletes old runs by itself, configured through environment variables. Pruning runs on the
**primary** only:

| Variable | n8n default | This setup |
|----------|-------------|------------|
| `EXECUTIONS_DATA_PRUNE` | `true` | `true` |
| `EXECUTIONS_DATA_MAX_AGE` | `336` (hours = 14 days) | `336` |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | `10000` | `2000` |

Pruning deletes rows; PostgreSQL then reuses that space but does not hand it back to the volume
(see VACUUM below). That is fine: a table that stops growing is the goal.

Measured on this instance 2026-10-01: runs disappear at exactly 56 days, so the value in effect
is 1344 hours, not 336. Pruning works; the limit is just long for a 500 MB volume.

**Pruning does not delete files.** When n8n removes a run, by pruning or because the workflow
does not save successful runs, the files of that run stay in `binary_data` with nothing pointing
at them (1,148 such files here, the oldest from February). The growth guard deletes them an hour
after their run is gone (`orphan_file_hours`).

If runs older than the limit are still there, do not assume the variable is the cause. Run
`scripts/db-guard.sh preflight` and read `executions`: it shows how many runs are
overdue, soft-deleted or have no end time.

## Run-Time Limit

| Variable | n8n default | This setup |
|----------|-------------|------------|
| `EXECUTIONS_TIMEOUT` | `-1` (none) | `900` (seconds): every run ends after 15 minutes |
| `EXECUTIONS_TIMEOUT_MAX` | `3600` | `7200`: the most a single workflow may ask for |

A workflow that legitimately runs longer sets its own `executionTimeout` in its settings, up to
the maximum. This is the only limit that acts *before* a run writes its data.

## Database Growth Guard

[`14_db-janitor`](../14_db-janitor/workflows/mainflow.md) is a small sixth service next to
Postgres (variables: [`railway/db-guard.env.example`](railway/db-guard.env.example)). It checks
the database every 2 minutes, switches off a workflow that stores too much, and switches off everything with a trigger when the
volume passes 85%. Alerts, allowances for big jobs and the disk-full recovery steps are in its
[runbook](../14_db-janitor/docs/runbook.md).

## Volume Management

### Monitoring

The growth guard measures the volume from inside Postgres (all databases plus the write-ahead
log) and warns at 70%. The host's metrics dashboard shows the same volume from outside; the two
differ by a fixed overhead, which the guard's `overhead_mb` accounts for.

### Write-Ahead Log

The write-ahead log (`pg_wal`) lives on the same volume as the data. PostgreSQL's default
`max_wal_size` is 1 GB: on a 500 MB volume the log alone may fill the disk during heavy writing.
`scripts/db-guard.sh tune-wal` sets `max_wal_size = 64MB` and `min_wal_size = 32MB`.

### VACUUM

PostgreSQL doesn't return disk space after deleting rows.

```sql
-- Standard VACUUM: non-blocking, makes the space reusable inside the table
VACUUM ANALYZE;

-- Full VACUUM: rewrites the table and returns space to the volume
VACUUM FULL execution_data;
```

`VACUUM FULL` blocks the table and **needs free space of about the size the table will have
afterwards**. On a nearly full volume it fails, and on a full one Postgres does not start at all.
For that case see "If the disk is full anyway" in the
[runbook](../14_db-janitor/docs/runbook.md).

## Environment Variables Reference

Queue mode, several Railway services. **A variable set on only one service is the usual way this
breaks, and it breaks silently.** Define them as project-level *shared* variables, then `Add All`
per service — per-service copies drift.

| Variable | Primary | Worker | Runner | Purpose |
|---|:-:|:-:|:-:|---|
| `N8N_ENCRYPTION_KEY` | ✅ | ✅ | — | ⚠️ Identical everywhere, never regenerated — see below |
| `GENERIC_TIMEZONE` | ✅ | ✅ | — | Timezone the Schedule Trigger resolves hours in |
| `TZ` | ✅ | ✅ | ✅ | Node process TZ — `new Date()` wherever code actually runs |
| `EXECUTIONS_MODE` | ✅ | ✅ | — | `queue` |
| `DB_TYPE`, `DB_POSTGRESDB_*` | ✅ | ✅ | — | Host, port, database, user, password |
| `QUEUE_BULL_REDIS_*` | ✅ | ✅ | — | Host, port, username, password |
| `WEBHOOK_URL` | ✅ | — | — | Public URL for webhook + OAuth callbacks |
| `N8N_DEFAULT_BINARY_DATA_MODE` | ✅ | ✅ | — | `database` in queue mode (see Binary Data Mode) |
| `EXECUTIONS_DATA_PRUNE`, `EXECUTIONS_DATA_MAX_AGE`, `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | ✅ | ✅ | — | Execution pruning. Runs on the primary; set on both so the services never disagree |
| `EXECUTIONS_TIMEOUT`, `EXECUTIONS_TIMEOUT_MAX` | ✅ | ✅ | — | Run-time limit. The worker enforces it |
| `N8N_RUNNERS_*` | ✅ | ✅ | ✅ | Enable/mode/auth/broker — **verify exact names against your service** |

**⚠️ `N8N_ENCRYPTION_KEY`:** every credential is encrypted with it. Rebuild without the *same* key
and n8n starts clean, workflows look fine, and every credential silently fails to decrypt. Save it
outside Railway before any teardown.

**Timezone (set 2026-08-12):** instance was on UTC−4 while the operator is UTC+2, so every schedule
landed six hours late — the "7 AM briefing" arrived at 13:00.

```
GENERIC_TIMEZONE=Europe/Zurich
TZ=Europe/Zurich
```

Not interchangeable: the first is read by the scheduler on the primary, the second by whichever
service executes the node. Only the first → schedules fire right while `new Date()` stays six hours
off, which is worse than being uniformly wrong.

Neither the public API nor `/rest/settings` exposes the timezone, so **verify by where a schedule
lands**: `daily briefing @07:00` should start at 05:00 UTC. Still 11:00 UTC → the variable never
reached the service owning the schedule.

**Rebuild:** export *all* variables first (26 on the primary; this table is a guide, not an
inventory) → restore `N8N_ENCRYPTION_KEY` → shared vars onto every service → confirm
`Settings → Error Workflow` still points at `007_error-handler.n8n` (unbound logs nothing, and says
nothing) → confirm one schedule fires at the expected UTC time.
