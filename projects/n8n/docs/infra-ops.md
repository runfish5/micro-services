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

The `12_db-janitor` workflow runs weekly (Sunday 3 AM) and sends a Telegram report of old/oversized executions. Stub mode — reports only, no automatic deletion.

See [`12_db-janitor/workflows/mainflow.md`](../12_db-janitor/workflows/mainflow.md) for setup.

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

| Variable | Purpose |
|----------|---------|
| `N8N_DEFAULT_BINARY_DATA_MODE` | `default` (PostgreSQL) or `filesystem` (disk) |
| `EXECUTIONS_DATA_PRUNE` | Enable automatic execution pruning |
| `EXECUTIONS_DATA_MAX_AGE` | Max age in hours before pruning |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | Max total executions to keep |
| `DB_POSTGRESDB_HOST` | PostgreSQL host |
| `DB_POSTGRESDB_DATABASE` | Database name |
