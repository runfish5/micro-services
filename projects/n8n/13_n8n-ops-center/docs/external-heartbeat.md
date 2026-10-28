# External Heartbeat — n8n Safety Net

A **GitHub Actions** watchdog that pings the Railway-hosted n8n instance from
*outside* Railway, so it still alerts you when the instance itself is down.

## Why it exists

The in-n8n error handler can't warn you about failures that break n8n itself:
- **Task-runner outage** (queue mode): every Code node times out at 60s. The error
  handler's own Code nodes die too. Covered internally by the `Runner/Infra Down?`
  branch in `10_error-handler` (expression-only alert) — but that still relies on
  n8n being up enough to trigger.
- **Full outage / crash-loop** (e.g. a failed DB migration): no workflow runs at all,
  so nothing inside n8n can tell you.
- **n8n up, database gone** (2026-10-01: the Postgres volume was full): the web server
  answers, every request that needs the database gets `503`, and no workflow runs.
- **The growth guard gone quiet**: the guard service (`14_db-janitor`) watches the database
  size from next to Postgres. If it stops, nothing else watches the disk.

This heartbeat lives on GitHub's infra and covers all four.

**How fast it is, measured:** the schedule asks for every 15 minutes. Over 40 runs in
September 2026 GitHub actually ran it every **2.4 to 8.3 hours**. Treat it as the slow
backstop that tells you the same day, not as a monitor. The fast paths are the error handler
inside n8n (immediately) and the growth guard next to it (2 minutes). The guard is its own
service, so it also reports "n8n is not ready" within about 4 minutes. What only this heartbeat
covers is the whole project being down, the guard included.

## What it checks (`scripts/n8n-heartbeat-check.sh`)

1. **Liveness** — `GET {N8N_API_URL}/healthz` must return `200`. Catches full
   outage / crash-loop.
2. **Readiness** — `GET /healthz/readiness` must return `200`. `/healthz` stays `200`
   while n8n has no database; this one does not.
3. **The API answers** — the HTTP status of the executions call is judged before its
   body. `503` is reported as "service unavailable" with n8n's own words, `401`/`403`
   as a rejected key, anything else as the raw code. A `200` that is not the expected
   JSON is reported as exactly that, with no guessed cause.
4. **Systemic failure** — of executions started in the last **90 min**
   (`HEARTBEAT_WINDOW_MIN`), alerts if **≥3** ran and **≥60%** failed. Catches the
   "up but every Code node times out" runner outage. The alert is enriched with the
   newest error message.
5. **Growth guard alive** (only with `HEARTBEAT_GUARD_CHECK=required`) —
   the guard's status page (`GUARD_STATUS_URL`) must answer `200` with a check younger
   than 10 minutes and a level other than `hard`.

Until 2026-10-01 steps 2 and 3 did not exist: a `503` was read as "could not parse the
executions API (key invalid or API error)", a specific cause the evidence did not
support.

Any problem → the script exits non-zero → the Action fails.

## Alerting — no credentials to hand-roll

A failed Action makes **GitHub email the repo owner** (Actions failure
notifications, on by default). That's the whole alerting path — no bot token, no
chat ID, no relay.

**Telegram:** with both `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` set, every alert is also
posted to Telegram. The post never fails the run, but it never fails silently either: a
half-set pair or a Telegram refusal (401 dead token, 400 wrong chat id) is a `::warning::` on the
run, next to the error.

## Setup

Secrets, set with `gh secret set`: `N8N_API_URL` (required), `N8N_API_KEY` (enables the
runner/error check), `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` (optional). Repository variables
`GUARD_STATUS_URL` and `HEARTBEAT_GUARD_CHECK=required` turn on the guard check. Then Actions →
n8n-heartbeat → "Run workflow" once. Where each secret comes from: [`docs/setup.md`](../../docs/setup.md).

## Tuning

- Cadence: edit the `cron` in `.github/workflows/n8n-heartbeat.yml`.
- Window/sensitivity: set `HEARTBEAT_WINDOW_MIN`, or adjust the `>=3` / `>=0.6`
  thresholds in `scripts/n8n-heartbeat-check.sh`.

> Note: GitHub runs scheduled Actions on a best-effort basis. See the measured cadence
> above before relying on the `cron` line.
