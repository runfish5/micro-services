#!/usr/bin/env bash
# n8n heartbeat check — external safety net.
#
# Exits non-zero when the n8n instance is unreachable, when n8n cannot reach its
# database, when the API does not answer, when a majority of recent executions are
# failing (the signature of a task-runner outage / version drift), or when the
# database growth guard has gone quiet.
# A non-zero exit fails the GitHub Action, which makes GitHub email the repo owner
# — so alerting needs NO credentials. If TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID are
# also set, it additionally pings Telegram.
#
# Env:
#   N8N_API_URL           (required)  e.g. https://your-n8n.up.railway.app
#   N8N_API_KEY           (optional)  enables the runner/error-rate check
#   TELEGRAM_BOT_TOKEN    (optional)  enables an extra Telegram alert
#   TELEGRAM_CHAT_ID      (optional)  "
#   HEARTBEAT_GUARD_CHECK (optional)  "required" = also check that the database growth guard
#                                     is alive (projects/n8n/14_db-janitor). Default: off.
#   GUARD_STATUS_URL      (with it)   the guard's status page, https://<guard domain>/status.json
#
# Run locally the same way CI does:
#   set -a; source .claude/n8n-api.env; set +a; bash scripts/n8n-heartbeat-check.sh
set -uo pipefail

: "${N8N_API_URL:?set N8N_API_URL}"
base="${N8N_API_URL%/}"
PY="$(command -v python3 || command -v python || true)"

alert() {
  local msg="$1"
  echo "::error::${msg}"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=🚨 n8n heartbeat: ${msg}" >/dev/null || true
  fi
  exit 1
}

# 1) Liveness — catches full outage / crash-loop (e.g. a failed DB migration).
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "${base}/healthz" || true)
code="${code:-000}"
[ "$code" = "200" ] || alert "instance unhealthy (/healthz → ${code}); primary may be down or crash-looping."
echo "✓ liveness (${code})"

# 1b) Readiness — /healthz stays 200 while n8n has lost its database (seen 2026-10-01: the
#     Postgres volume was full, every request got 503, and liveness still passed).
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "${base}/healthz/readiness" || true)
code="${code:-000}"
[ "$code" = "200" ] || alert "n8n is up but not ready (/healthz/readiness → ${code}): it reports no working database connection. Check the Postgres service and its volume."
echo "✓ readiness (${code})"

# 2) Systemic-failure / runner check — catches the "up but every Code node times
#    out" outage. Needs the API key; skipped if not provided.
if [ -n "${N8N_API_KEY:-}" ]; then
  [ -n "$PY" ] || alert "python3 not found on the runner — cannot evaluate execution health."
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  api_code=$(curl -s -o "$tmp" -w '%{http_code}' --max-time 30 "${base}/api/v1/executions?limit=20" -H "X-N8N-API-KEY: ${N8N_API_KEY}" || true)
  api_code="${api_code:-000}"
  # Judge the status code before the body. A 503 used to be reported as "could not parse",
  # which hid a database outage behind a guess about the API key.
  if [ "$api_code" != "200" ]; then
    body=$(head -c 160 "$tmp" | tr -d '\r\n' | tr -c '[:print:]' ' ')
    case "$api_code" in
      503)     alert "the API answers 503 (service unavailable). n8n said: ${body:-nothing}" ;;
      401|403) alert "the API rejected the key (${api_code}). n8n said: ${body:-nothing}" ;;
      *)       alert "the API answered ${api_code}, expected 200. n8n said: ${body:-nothing}" ;;
    esac
  fi
  verdict=$(HEARTBEAT_WINDOW_MIN="${HEARTBEAT_WINDOW_MIN:-90}" "$PY" - "$tmp" <<'PY'
import sys, json, os, datetime
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))["data"]
    assert isinstance(data, list)
except Exception:
    print("PARSE_ERR"); sys.exit(0)

win = float(os.environ.get("HEARTBEAT_WINDOW_MIN", "90"))
now = datetime.datetime.now(datetime.timezone.utc)

def started(e):
    s = e.get("startedAt") or e.get("createdAt")
    if not s:
        return None
    try:
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

# Only judge health on executions from the last <win> minutes, so historical
# errors (e.g. from a past outage) don't keep the alarm stuck on.
recent = [e for e in data if (t := started(e)) and (now - t).total_seconds() <= win * 60]
done = [e for e in recent if e.get("status") in ("success", "error", "crashed")]
errs = [e for e in done if e.get("status") in ("error", "crashed")]
newest = errs[0]["id"] if errs else ""

# Majority of recent runs failing (and at least a few) => systemic, not a one-off.
if done and len(errs) >= 3 and len(errs) / len(done) >= 0.6:
    print(f"FAIL {len(errs)}/{len(done)} {newest}")
else:
    print(f"OK {len(errs)}/{len(done)}")
PY
)
  echo "executions: ${verdict}"
  case "$verdict" in
    FAIL*)
      eid=$(printf '%s' "$verdict" | awk '{print $3}')
      ratio=$(printf '%s' "$verdict" | awk '{print $2}')
      emsg=""
      if [ -n "$eid" ]; then
        det=$(curl -s --max-time 30 "${base}/api/v1/executions/${eid}?includeData=true" -H "X-N8N-API-KEY: ${N8N_API_KEY}")
        emsg=$(printf '%s' "$det" | "$PY" -c "import sys,json;d=json.load(sys.stdin);print(((d.get('data',{}).get('resultData',{}).get('error') or {}).get('message') or '')[:160])" 2>/dev/null || echo "")
      fi
      alert "systemic failures (${ratio} recent executions failing). Newest error: ${emsg:-unknown}. Likely the task runner is down or version-drifted → Railway: redeploy n8n-runner + primary."
      ;;
    PARSE_ERR)
      alert "the executions API answered 200 but not with the expected JSON. Cause unknown."
      ;;
  esac
fi

# 3) Growth guard — a small service next to Postgres checks the database every 2 minutes
#    (projects/n8n/14_db-janitor). If it stops, nothing watches the disk, and only an outside
#    check can notice. GUARD_STATUS_URL is its public /status.json.
if [ "${HEARTBEAT_GUARD_CHECK:-off}" = "required" ]; then
  [ -n "$PY" ] || alert "python3 not found on the runner — cannot read the guard status."
  [ -n "${GUARD_STATUS_URL:-}" ] || alert "HEARTBEAT_GUARD_CHECK is required, but GUARD_STATUS_URL is not set."
  gtmp="$(mktemp)"
  g_code=$(curl -s -o "$gtmp" -w '%{http_code}' --max-time 30 "$GUARD_STATUS_URL" || true)
  g_code="${g_code:-000}"
  if [ "$g_code" != "200" ]; then
    rm -f "$gtmp"
    alert "the growth guard does not answer (status page → HTTP ${g_code}). Nothing is watching the database size."
  fi
  gverdict=$("$PY" - "$gtmp" <<'PY'
import sys, json, time
try:
    s = json.load(open(sys.argv[1], encoding="utf-8"))["status"]
    # The page is a file the guard rewrites at every check: its age is "now - checked_at".
    age = time.time() - float(s["checked_at"])
except Exception:
    print("UNREADABLE"); sys.exit(0)
level, pct = s.get("level"), s.get("pct")
if age > 600:
    print(f"STALE {round(age / 60)}min"); sys.exit(0)
if level == "hard":
    print(f"HARD {pct}"); sys.exit(0)
print(f"OK {level} {pct}% age {int(age)}s mode {s.get('mode')}")
PY
)
  rm -f "$gtmp"
  echo "guard: ${gverdict}"
  case "$gverdict" in
    UNREADABLE) alert "the growth guard answered, but not with a status. Cause unknown." ;;
    STALE*)     alert "the growth guard has not checked the database (last check: ${gverdict#STALE }). Nothing is watching the database size." ;;
    HARD*)      alert "the database volume is at ${gverdict#HARD }%: the growth guard is in hard stop." ;;
  esac
fi

echo "✓ heartbeat OK"
