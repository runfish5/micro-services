# Infrastructure Operations

Infrastructure and container-layer operations for the n8n instance. Separate from n8n workflow-level troubleshooting (see `troubleshooting.md`).

## Binary Data Mode

By default n8n stores binary data (email attachments, PDFs, images) **inline in PostgreSQL** execution records. This causes rapid volume growth — the inbox-attachment-organizer stores ~237KB per execution.

### Fix: Filesystem Storage

Set this environment variable on your hosting platform (e.g., Docker Compose env, service dashboard):

```
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
```

- New executions store binary data as files on disk, DB holds only metadata + JSON
- Existing data in PostgreSQL stays until executions are pruned/deleted
- No workflow changes needed — transparent to all workflows

### Verification

After setting the var and redeploying:
1. Run a workflow that processes files (e.g., inbox-attachment-organizer)
2. Check the volume — binary files appear in `/home/node/.n8n/binaryData/`
3. DB growth per execution should drop from ~237KB to ~50KB

## Execution Pruning (n8n Built-in)

n8n has built-in execution pruning, configured via env vars:

| Variable | Default | Recommended |
|----------|---------|-------------|
| `EXECUTIONS_DATA_PRUNE` | `true` | `true` |
| `EXECUTIONS_DATA_MAX_AGE` | `336` (14 days, hours) | `336` |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | - | `500` |

These prune execution *records* but don't reclaim PostgreSQL disk space (see VACUUM below).

## DB Janitor Workflow

The `14_db-janitor` workflow runs weekly (Sunday 3 AM) and sends a Telegram report of old/oversized executions. Stub mode — reports only, no automatic deletion.

See [`14_db-janitor/workflows/mainflow.md`](../14_db-janitor/workflows/mainflow.md) for setup.

## Volume Management

### Monitoring

Check your hosting platform's metrics dashboard for PostgreSQL volume usage.

### VACUUM

PostgreSQL doesn't return disk space after deleting rows. After pruning old executions:

```sql
-- Standard VACUUM (non-blocking, reclaims some space)
VACUUM ANALYZE;

-- Full VACUUM (blocks writes, fully reclaims space — use during low traffic)
VACUUM FULL;
```

Run from your PostgreSQL admin console (e.g., `psql`, pgAdmin, or your host's query editor).

### One-Time Cleanup (Existing Bloat)

If the volume is already bloated from binary data stored before enabling filesystem mode:

1. Set `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` and redeploy
2. In n8n UI, delete old executions from heavy workflows (inbox-organizer, file-converter)
3. Run `VACUUM FULL;` from your PostgreSQL console
4. Monitor volume — should see immediate drop

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
| `N8N_DEFAULT_BINARY_DATA_MODE` | ✅ | ✅ | — | `default` (PostgreSQL) or `filesystem` |
| `EXECUTIONS_DATA_PRUNE[_MAX_COUNT]`, `_MAX_AGE` | ✅ | — | — | Execution pruning |
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
