#!/usr/bin/env bash
# Database growth guard, as a small always-on service next to Postgres.
#
# Every GUARD_INTERVAL_S seconds it asks Postgres one question (sql/tick.sql -> guard.tick),
# sends the alerts that come back, and in mode "enforce" switches the named workflows off
# through the n8n API. All rules live in sql/guard.sql; this file only carries messages.
#
# It installs its own schema at start, so there is nothing to set up inside n8n and nothing
# to run by hand. It keeps working when n8n is down, and says so.
#
# Variables (only the first is required):
#   DATABASE_URL          the database n8n uses. On Railway: ${{Postgres.DATABASE_URL}}
#   TELEGRAM_BOT_TOKEN    where alerts go. Without these two, alerts only reach the log
#   TELEGRAM_CHAT_ID      and the table guard.event
#   GUARD_MODE            observe (default: report only) | enforce
#   N8N_BASE_URL          needed for enforce, and for the "n8n is not ready" alert
#   N8N_API_KEY           needed for enforce: may read and unpublish workflows, stop executions
#   GUARD_CONFIG          JSON that overrides values of service/config.json,
#                         for example {"overhead_mb":43,"factors":{"<workflow id>":3}}
#   SMTP_URL SMTP_USER SMTP_PASS MAIL_TO   optional: every alert also as an email
#   PORT                  optional: serve /status.json for an outside heartbeat
#   GUARD_INTERVAL_S      default 120
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${GUARD_SQL_DIR:-$here/../sql}"
CONFIG_FILE="${GUARD_CONFIG_FILE:-$here/config.json}"
STATE_DIR="${GUARD_STATE_DIR:-/tmp/guard}"
INTERVAL="${GUARD_INTERVAL_S:-120}"
MODE="${GUARD_MODE:-observe}"
TELEGRAM_API_BASE="${TELEGRAM_API_BASE:-https://api.telegram.org}"
N8N_BASE_URL="${N8N_BASE_URL:-}"
N8N_BASE_URL="${N8N_BASE_URL%/}"
overrides="${GUARD_CONFIG:-}"
[ -n "$overrides" ] || overrides='{}'

export PGCONNECT_TIMEOUT=10
export PGOPTIONS="-c statement_timeout=30000"

mkdir -p "$STATE_DIR/www"
trap 'exit 0' TERM INT

log() { echo "$(date -u +%FT%TZ) $*"; }

# True at most once per $2 seconds for the key $1. Keeps a repeating failure from sending a
# message on every check.
due() {
  local f="$STATE_DIR/$1.stamp" now
  now=$(date +%s)
  if [ -f "$f" ] && [ $(( now - $(cat "$f") )) -lt "$2" ]; then return 1; fi
  echo "$now" > "$f"
}

# Sends one alert everywhere it can. Never fails: a broken channel must not stop the switch-off.
tell() {
  local subject="$1" text="$2" code
  log "ALERT $subject | $text"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    # Plain text on purpose: no parse mode, so no character in a workflow name can break it.
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 \
      "$TELEGRAM_API_BASE/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
      --data-urlencode "text=${text:0:3900}" 2>/dev/null) || code="${code:-000}"
    [ "$code" = "200" ] || log "telegram: HTTP $code"
  fi
  if [ -n "${SMTP_URL:-}" ] && [ -n "${MAIL_TO:-}" ]; then
    printf 'From: %s\r\nTo: %s\r\nSubject: %s\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n%s\r\n' \
      "${SMTP_USER:-db-guard}" "$MAIL_TO" "$subject" "$text" |
      curl -sS --max-time 30 --ssl-reqd --url "$SMTP_URL" --user "${SMTP_USER:-}:${SMTP_PASS:-}" \
        --mail-from "${SMTP_USER:-db-guard}" --mail-rcpt "$MAIL_TO" -T - >/dev/null 2>&1 ||
      log "email: could not send"
  fi
  return 0
}

fatal() { tell "[db-guard] the guard cannot start" "DB guard cannot start: $1"; exit 1; }

sql_file() { timeout 60 psql "$DATABASE_URL" -X -q -At -v ON_ERROR_STOP=1 "${@:2}" -f "$1"; }

# n8n API call. Prints the HTTP status; the body goes to $STATE_DIR/api.body.
api() {
  local method="$1" path="$2" body="${3:-}" args=()
  [ -n "$body" ] && args=(-H 'Content-Type: application/json' -d "$body")
  curl -sS -o "$STATE_DIR/api.body" -w '%{http_code}' --max-time 30 -X "$method" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY:-}" "${args[@]}" "$N8N_BASE_URL/api/v1$path" 2>/dev/null || echo 000
}

switch_off() {
  local id="$1" name="$2" stop="$3" code
  code=$(api POST "/workflows/$id/deactivate")
  if [ "${code:0:1}" != "2" ]; then
    # The switch-off is repeated on every check while a breach lasts. A workflow that is
    # already off may answer with an error, so look before calling it a failure.
    if [ "$(api GET "/workflows/$id")" = "200" ] && jq -e '.active == false' "$STATE_DIR/api.body" >/dev/null 2>&1; then
      log "already off: $name ($id)"
    else
      log "could not switch off $name ($id): HTTP $code"
      due "apifail-$id" 1800 && tell "[db-guard] could not switch off: $name" \
        "DB guard: tried to switch off $name ($id), the n8n API answered HTTP $code. It is probably still on. Cause unknown."
      return 0
    fi
  else
    log "switched off: $name ($id)"
  fi
  [ "$stop" = "true" ] || return 0
  # Per workflow id, never a global stop.
  code=$(api POST "/executions/stop" "{\"status\":[\"running\",\"queued\",\"waiting\"],\"workflowId\":\"$id\"}")
  log "stop runs of $name ($id): HTTP $code $(tr -d '\n' < "$STATE_DIR/api.body" 2>/dev/null | head -c 200)"
}

blind() {
  local err
  err="$(tr '\n' ' ' < "$STATE_DIR/err" 2>/dev/null | head -c 600)"
  log "check failed: $err"
  due blind 1800 && tell "[db-guard] the guard is blind" \
    "DB guard is BLIND: the check of the database failed, nothing is watching its size. Cause unknown. Raw error: ${err:-none}"
  return 0
}

tick() {
  local cfg out a subject text
  cfg=$(jq -c -n --slurpfile d "$CONFIG_FILE" --argjson o "$overrides" --arg mode "$MODE" '$d[0] * $o * {mode: $mode}')
  out=$(sql_file "$SQL_DIR/tick.sql" -v cfg="$cfg" 2>"$STATE_DIR/err") || { blind; return 0; }
  if ! jq -e '.ok == true' >/dev/null 2>&1 <<<"$out"; then
    printf 'unexpected answer: %s' "${out:0:300}" > "$STATE_DIR/err"; blind; return 0
  fi
  if [ "$(jq -r '.skipped // empty' <<<"$out")" != "" ]; then log "skipped: $(jq -r .skipped <<<"$out")"; return 0; fi

  log "$(jq -r '"ok mode=\(.mode) level=\(.level) pct=\(.pct) used_mb=\(.used_mb) actions=\(.actions | length)"' <<<"$out")"
  jq -c --argjson now "$(date +%s)" \
    '{status: {ok: (.level != "hard"), checked_at: $now, tick_age_s: 0, mode, level, pct}}' <<<"$out" \
    > "$STATE_DIR/www/status.json.new" && mv "$STATE_DIR/www/status.json.new" "$STATE_DIR/www/status.json"

  while IFS= read -r a; do
    [ -n "$a" ] || continue
    # Tell first, then act.
    if [ "$(jq -r .notify <<<"$a")" = "true" ]; then
      subject=$(jq -r .subject <<<"$a")
      text=$(jq -r '.text + ((.targets // []) | if length > 0 then "\n\nTargets (id, name, version that was live):\n" + (map("\(.id)  \(.name)  \(.version_id // "-")") | join("\n")) else "" end)' <<<"$a")
      tell "$subject" "$text"
    fi
    if [ "$(jq -r .enforce <<<"$a")" = "true" ]; then
      while IFS=$'\t' read -r id stop name; do
        [ -n "$id" ] && switch_off "$id" "$name" "$stop"
      done < <(jq -r '.targets[] | [.id, (.stop | tostring), .name] | @tsv' <<<"$a")
    fi
  done < <(jq -c '.actions[]' <<<"$out")
}

# The database can be fine while n8n is not. Two failed checks in a row, then one message.
check_n8n() {
  [ -n "$N8N_BASE_URL" ] || return 0
  local code n f="$STATE_DIR/n8n.fails"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$N8N_BASE_URL/healthz/readiness" 2>/dev/null) || code="${code:-000}"
  if [ "$code" = "200" ]; then
    if [ -f "$f" ] && [ "$(cat "$f")" -ge 2 ]; then tell "[db-guard] n8n is ready again" "DB guard: n8n answers again (/healthz/readiness 200)."; fi
    rm -f "$f" "$STATE_DIR/n8n.stamp"
    return 0
  fi
  n=$(( $(cat "$f" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$f"
  log "n8n readiness: HTTP $code ($n in a row)"
  if [ "$n" -ge 2 ] && due n8n 1800; then
    tell "[db-guard] n8n is not ready" \
      "DB guard: n8n did not answer ready on $n checks in a row (/healthz/readiness -> HTTP $code). Cause unknown."
  fi
  return 0
}

# ---- start
[ -n "${DATABASE_URL:-}" ] || fatal "DATABASE_URL is not set."
jq -e . "$CONFIG_FILE" >/dev/null 2>&1 || fatal "$CONFIG_FILE is not valid JSON."
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$overrides" || fatal "GUARD_CONFIG is not a JSON object."
case "$MODE" in
  observe) ;;
  enforce) { [ -n "$N8N_BASE_URL" ] && [ -n "${N8N_API_KEY:-}" ]; } || fatal "GUARD_MODE=enforce needs N8N_BASE_URL and N8N_API_KEY." ;;
  *) fatal "GUARD_MODE must be observe or enforce, not '$MODE'." ;;
esac

if [ -n "${PORT:-}" ]; then
  httpd -p "$PORT" -h "$STATE_DIR/www" && log "status at :$PORT/status.json"
fi

# A private network may need a few seconds after start before names resolve: try quietly
# twice before calling it a failure.
tries=0
until sql_file "$SQL_DIR/guard.sql" >/dev/null 2>"$STATE_DIR/err"; do
  tries=$((tries + 1))
  [ -n "${GUARD_ONCE:-}" ] && tries=3
  if [ "$tries" -ge 3 ]; then blind; else log "database not reachable yet (try $tries)"; fi
  [ -n "${GUARD_ONCE:-}" ] && exit 1
  sleep 10 & wait $!
done
log "guard installed, mode=$MODE, every ${INTERVAL}s"
# One message per start: it proves the alert channel works, and a restart never goes unseen.
tell "[db-guard] started" "DB guard started in mode $MODE. It checks the database every ${INTERVAL} seconds."

while true; do
  tick
  check_n8n
  [ -n "${GUARD_ONCE:-}" ] && exit 0
  sleep "$INTERVAL" & wait $!
done
