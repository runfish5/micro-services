#!/usr/bin/env bash
# Database growth guard: the operator's side, run from a terminal.
#
#   scripts/db-guard.sh preflight   read-only facts: sizes, write-ahead log, pruning, biggest writers
#   scripts/db-guard.sh status      what the guard saw at its last check, and the open allowances
#   scripts/db-guard.sh allow <workflow id> <MB> <hours>   let one workflow store <MB> in the next <hours>
#   scripts/db-guard.sh tune-wal    cap the write-ahead log (max_wal_size 64MB, min_wal_size 32MB)
#   scripts/db-guard.sh install     create schema "guard" by hand (the service does this itself at start)
#
# It only feeds SQL from projects/n8n/14_db-janitor/sql/ to psql. The guard itself is the
# service in projects/n8n/14_db-janitor/; see its docs/runbook.md.
#
# How it reaches Postgres (first match wins):
#   DATABASE_URL is set  -> your local psql, with that connection string
#   otherwise            -> the Railway CLI: psql runs inside the Postgres container, so the
#                           database never has to be reachable from the internet.
#                           Needs `railway login` once, plus either a linked directory
#                           (`railway link`) or these three ids in the environment:
#                             RAILWAY_PROJECT  RAILWAY_ENVIRONMENT  RAILWAY_PG_SERVICE
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sql="$here/../projects/n8n/14_db-janitor/sql"
action="${1:-}"

PSQL_FLAGS='-X -q -At -v ON_ERROR_STOP=1'
# Inside the container: the local socket needs no password, and the names come from the
# container's own variables. Single quotes on purpose: the container expands them, not this shell.
REMOTE_PSQL='psql '"$PSQL_FLAGS"' -h /var/run/postgresql -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}"'

rsh() {
  local flags=()
  [ -n "${RAILWAY_PROJECT:-}" ]     && flags+=(--project "$RAILWAY_PROJECT")
  [ -n "${RAILWAY_ENVIRONMENT:-}" ] && flags+=(--environment "$RAILWAY_ENVIRONMENT")
  [ -n "${RAILWAY_PG_SERVICE:-}" ]  && flags+=(--service "$RAILWAY_PG_SERVICE")
  # MSYS_NO_PATHCONV: Git Bash on Windows would otherwise rewrite /tmp/... into a Windows path.
  MSYS_NO_PATHCONV=1 railway ssh "${flags[@]}" -- "$1"
}

run_sql() {
  local file="$1"
  [ -f "$file" ] || { echo "missing $file" >&2; exit 2; }
  if [ -n "${DATABASE_URL:-}" ]; then
    # shellcheck disable=SC2086
    psql "$DATABASE_URL" $PSQL_FLAGS -f "$file"
    return
  fi
  # The file travels as gzip + base64 in pieces: no quoting can break it, and each command
  # stays far below the length a Windows shell accepts.
  local remote="/tmp/db-guard-$$-$RANDOM.b64" payload first=1
  payload="$(gzip -9c "$file" | base64 | tr -d '\r\n')"
  while [ -n "$payload" ]; do
    if [ "$first" = 1 ]; then rsh "printf %s ${payload:0:4000} > $remote"; first=0
    else rsh "printf %s ${payload:0:4000} >> $remote"; fi
    payload="${payload:4000}"
  done
  rsh "base64 -d $remote | gunzip | $REMOTE_PSQL; rc=\$?; rm -f $remote; exit \$rc"
}

case "$action" in
  preflight)
    run_sql "$sql/preflight-database.sql"
    run_sql "$sql/preflight-history.sql"
    ;;
  tune-wal)
    run_sql "$sql/tune-wal.sql"
    ;;
  install)
    run_sql "$sql/guard.sql"
    run_sql "$sql/status.sql"
    ;;
  status)
    run_sql "$sql/status.sql"
    ;;
  allow)
    wf="${2:-}"; mb="${3:-}"; hours="${4:-}"
    # Checked here because the values go into SQL text.
    [[ "$wf" =~ ^[A-Za-z0-9_-]+$ && "$mb" =~ ^[0-9]+(\.[0-9]+)?$ && "$hours" =~ ^[0-9]+(\.[0-9]+)?$ ]] ||
      { echo "usage: db-guard.sh allow <workflow id> <MB> <hours>" >&2; exit 2; }
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    printf "INSERT INTO guard.allowance (workflow_id, mb, until) VALUES ('%s', %s, now() + %s * interval '1 hour');\n" \
      "$wf" "$mb" "$hours" > "$tmp"
    cat "$sql/status.sql" >> "$tmp"
    run_sql "$tmp"
    ;;
  *)
    sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
