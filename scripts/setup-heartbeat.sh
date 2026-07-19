#!/usr/bin/env bash
# One-shot setup for the n8n heartbeat safety net.
# Reuses the values already in .claude/n8n-api.env and pushes them into this
# repo's GitHub Actions secrets — so you don't hand-roll anything.
#
# Requires: gh CLI, authenticated (`gh auth login`).
# Usage:    bash scripts/setup-heartbeat.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".claude/n8n-api.env"

[ -f "$ENV_FILE" ] || { echo "✗ Missing $ENV_FILE (needs N8N_API_URL, N8N_API_KEY)."; exit 1; }
command -v gh >/dev/null || { echo "✗ gh CLI not found — install from https://cli.github.com/"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✗ Not logged in — run 'gh auth login' first."; exit 1; }

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${N8N_API_URL:?N8N_API_URL not set in $ENV_FILE}"
: "${N8N_API_KEY:?N8N_API_KEY not set in $ENV_FILE}"

gh secret set N8N_API_URL --body "$N8N_API_URL"
gh secret set N8N_API_KEY --body "$N8N_API_KEY"
echo "✓ Set N8N_API_URL + N8N_API_KEY as GitHub Actions secrets."

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  gh secret set TELEGRAM_BOT_TOKEN --body "$TELEGRAM_BOT_TOKEN"
  gh secret set TELEGRAM_CHAT_ID   --body "$TELEGRAM_CHAT_ID"
  echo "✓ Set TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID — Telegram alerts enabled."
else
  echo "ℹ No Telegram vars in $ENV_FILE — that's fine: alerts arrive via GitHub's"
  echo "  failed-workflow email (make sure Actions email notifications are on)."
fi

echo
echo "Next:"
echo "  1) commit + push .github/workflows/n8n-heartbeat.yml and scripts/"
echo "  2) Actions tab → n8n-heartbeat → 'Run workflow' to test it once"
