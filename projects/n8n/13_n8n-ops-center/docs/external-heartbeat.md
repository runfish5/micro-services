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

This heartbeat lives on GitHub's infra and covers both.

## What it checks (`scripts/n8n-heartbeat-check.sh`, every 15 min)

1. **Liveness** — `GET {N8N_API_URL}/healthz` must return `200`. Catches full
   outage / crash-loop.
2. **Systemic failure** — of executions started in the last **90 min**
   (`HEARTBEAT_WINDOW_MIN`), alerts if **≥3** ran and **≥60%** failed. Catches the
   "up but every Code node times out" runner outage. The alert is enriched with the
   newest error message.

Any problem → the script exits non-zero → the Action fails.

## Alerting — no credentials to hand-roll

A failed Action makes **GitHub email the repo owner** (Actions failure
notifications, on by default). That's the whole alerting path — no bot token, no
chat ID, no relay.

**Optional Telegram:** if `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` secrets exist,
the script also posts to Telegram. Omit them and GitHub email is used.

## Setup (one time)

```bash
bash scripts/setup-heartbeat.sh   # reuses .claude/n8n-api.env → GitHub secrets
git add .github/workflows/n8n-heartbeat.yml scripts/ && git commit && git push
# then: Actions tab → n8n-heartbeat → "Run workflow" to test once
```

Secrets used: `N8N_API_URL` (required), `N8N_API_KEY` (optional — enables the
runner/error check), `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` (optional).

## Tuning

- Cadence: edit the `cron` in `.github/workflows/n8n-heartbeat.yml`.
- Window/sensitivity: set `HEARTBEAT_WINDOW_MIN`, or adjust the `>=3` / `>=0.6`
  thresholds in `scripts/n8n-heartbeat-check.sh`.

> Note: GitHub scheduled Actions can be delayed several minutes under load — fine
> for a safety net, not a sub-minute SLA.
