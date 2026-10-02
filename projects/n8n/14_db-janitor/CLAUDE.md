# 14_db-janitor: database growth guard

A small service next to Postgres (bash + psql, **not an n8n workflow**) that keeps n8n's own
database from filling its 500 MB volume. How it works: `workflows/mainflow.md`. Alerts, allowances
and disk-full recovery: `docs/runbook.md`.

## What it does

Every 2 minutes one Postgres function measures the volume and the bytes each workflow stored.

- Over the limit (5 MB in 3 minutes or 20 MB in an hour, times a per-workflow factor): alert,
  unpublish the workflow, stop its runs.
- Volume at 85% or more: everything with a trigger is unpublished.
- Files in `binary_data` whose run no longer exists are deleted after `orphan_file_hours` (1).
- It also reports "n8n is not ready".

## Current state

| Part | State |
|---|---|
| Guard service `db-guard` on Railway | running in **`observe`** (reports only). Telegram alerts work. `GUARD_CONFIG` is set; the n8n API key is not. Update this line when it goes to `enforce` |
| Heartbeat (readiness check, guard-alive check) | pushed. The guard-alive check stays off until the repository variables `GUARD_STATUS_URL` and `HEARTBEAT_GUARD_CHECK=required` are set |
| n8n pruning | works: runs are removed after 56 days. It never deletes the files of those runs; the guard does |
| Run-time limit as Railway variables | open, set by hand. Values: `projects/n8n/docs/infra-ops.md` |

## Rules

- **Big jobs are denied by default.** A legitimate one needs an allowance with an end time:
  `scripts/db-guard.sh allow <workflow id> <MB> <hours>`.
- **A batch workflow stores nothing in n8n**: `saveDataSuccessExecution: none` *and*
  `saveDataErrorExecution: none`. A failed or stopped run stores its full data like a successful one.
- **Not saving a run does not delete its files.** A batch job should create no n8n files at all:
  send the data on in an HTTP request. What still gets left behind, the guard deletes.
- **n8n writes a run's data when the run ends.** Nothing outside can veto that write, so the guard
  bounds the damage to one check interval; it does not prevent the first write.
- **The guard lives outside n8n on purpose.** It must work when n8n, its worker or the task runner
  is down, and no database superuser credential should sit inside n8n. Do not rebuild it as a
  workflow.
- Read-only checks: `scripts/db-guard.sh status` and `preflight`.

## Cost review due December 2026 – January 2027

The guard is a sixth Railway service. Measured before deploying: 9 MB memory (peak 15 MB), about
35 CPU-seconds per day. Compare with the **Metrics** tab of the service and the project's usage
page. If it is not worth it, the alternative is an n8n-workflow version (no extra service, more
setup, blind when n8n is down). Raise the question with the operator; do not decide it alone.
