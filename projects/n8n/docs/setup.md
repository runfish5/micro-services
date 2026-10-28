# Setup and key rotation

A rotation is a first setup that keeps the workflows and the credential IDs. Run it top to bottom
either way; on a first setup, step 2 has nothing to export.

## The stack

One Railway project, queue mode: `Primary` (editor, webhooks, schedules), `Worker` (runs the
executions), `Runner` (Code nodes), `Postgres`, `Redis`, and `db-guard`
([`14_db-janitor`](../14_db-janitor/docs/runbook.md)). Outside it: the GitHub heartbeat
([`external-heartbeat.md`](../13_n8n-ops-center/docs/external-heartbeat.md)), the app box and the
site, each holding a secret n8n also holds.

**A value lives once.** `Postgres` and `Redis` own their passwords and the n8n services reference
them (`${{Postgres.POSTGRES_PASSWORD}}`); the encryption key and the runner token are typed on two
services each, identical. A value missing on one service breaks silently.

| Variable | Primary | Worker | Runner | Value |
|---|:-:|:-:|:-:|---|
| `N8N_ENCRYPTION_KEY` | ✅ | ✅ | — | secret; encrypts every credential |
| `N8N_RUNNERS_*` | ✅ | ✅ | ✅ | enable, mode, broker, auth token (secret) |
| `GENERIC_TIMEZONE`, `TZ` | ✅ | ✅ | `TZ` | `Europe/Zurich`. The first places schedules, the second is `new Date()` wherever code runs: set one without the other and schedules fire right while code is hours off |
| `EXECUTIONS_MODE` | ✅ | ✅ | — | `queue` |
| `DB_TYPE`, `DB_POSTGRESDB_*` | ✅ | ✅ | — | references to `Postgres` |
| `QUEUE_BULL_REDIS_*` | ✅ | ✅ | — | references to `Redis` |
| `WEBHOOK_URL` | ✅ | — | — | public URL, also the OAuth callback |
| `N8N_DEFAULT_BINARY_DATA_MODE` | ✅ | ✅ | — | `database` ([why](infra-ops.md#binary-data-mode)) |
| `EXECUTIONS_DATA_PRUNE*`, `EXECUTIONS_DATA_MAX_AGE`, `EXECUTIONS_TIMEOUT*` | ✅ | ✅ | — | [values](infra-ops.md#execution-pruning-n8n-built-in) |

`Postgres`: image `ghcr.io/railwayapp-templates/postgres-ssl`, PostgreSQL 16 pinned by digest;
start command `/bin/sh -c "unset PGPORT; docker-entrypoint.sh postgres --port=5432"`; volume at
`/var/lib/postgresql/data`. Only `Primary` is public: `Runner` reaches the broker on
`Worker:5679` over private networking. The move to n8n 2.0 needed a TCP proxy on that port, which
put the broker on the internet; it was removed 2026-10-27. `db-guard`: source this repo, root directory
`projects/n8n/14_db-janitor`, variables from [`railway/db-guard.env.example`](railway/db-guard.env.example).

## The secrets

| Secret | Made | Goes to |
|---|---|---|
| `N8N_ENCRYPTION_KEY` | `openssl rand -hex 32` | shared variable |
| runner auth token | `openssl rand -hex 32` | shared variable |
| `POSTGRES_PASSWORD` | `openssl rand -hex 24` | `ALTER USER` first, then the `Postgres` variable: the variable alone never changes a password inside an existing database |
| `REDIS_PASSWORD` | `openssl rand -hex 24` | `Redis` variable |
| n8n owner login | the n8n UI | password manager |
| n8n API key | Settings → n8n API | `.claude/n8n-api.env`, the n8n credential that calls n8n itself, GitHub secret `N8N_API_KEY`, `db-guard` once in `enforce` |
| Telegram bot tokens | @BotFather `/revoke` | n8n Telegram credentials, `db-guard`, GitHub secret `TELEGRAM_BOT_TOKEN`; the box's admin bot is its own bot (`TELEGRAM_TOKEN`) |
| trail secret | `openssl rand -hex 32` | n8n header-auth credential, box `N8N_TRAIL_WEBHOOK_SECRET` |
| forms secret | `openssl rand -hex 32` | n8n header-auth credential, site `N8N_REACH_WEBHOOK_SECRET` |
| site records token | `openssl rand -hex 32` | n8n header-auth credential, box `SITE_RECORDS_TOKEN` |
| webhook paths without header auth | a new path in the workflow | the sender's `*_WEBHOOK_URL` (site, box) |
| provider keys, Google OAuth client secret | each provider's console ([credentials-guide](../credentials-guide.md)); Google: the web client whose ID every n8n Google credential shows, in that client's own project (the Apps Script client holds nothing n8n uses) | n8n credentials; the Google secret also in the PromptPotter box's `identity/oidc.json` (`google.client_secret`), then restart its service |

Keep the new values in one gitignored sheet, `.claude/keys.env`, while you work. It is the only
place they are typed.

## Steps

1. **New provider keys** in the browser, old ones still valid; paste each into the sheet.
   Generate the rest with `openssl`.
2. **Export.** Workflows through the API; credentials decrypted, with the old key still set:
   `railway ssh --service Primary -- n8n export:credentials --all --decrypted`, saved outside the repo.
   That file holds every secret in clear text: delete it after step 5.
3. **Infrastructure.** `ALTER USER` in Postgres, then every variable from the sheet
   (`railway variable set KEY --stdin --skip-deploys`). Before redeploying, retire what n8n wrapped
   with the old key in table `deployment_key`, where a trigger forbids deleting: every encrypted
   row gets `status = 'inactive'`, and the `aes-256-cbc` row a type no lookup matches. n8n seeds
   fresh ones at start; skip this and `primary` crashes with "cannot be read with this instance
   encryption key". Then redeploy all services.
4. **Import.** Write the sheet's values into the export and run `n8n import:credentials` on
   `Primary`. Same IDs, so every workflow keeps its bindings. Check with a second decrypted export.
   Logins, sessions and n8n API keys end with the old key. Google credentials: **Reconnect** each
   one, since the old tokens belong to the old client secret.
5. **Outside holders.** `gh secret set` for the heartbeat; `db-guard` variables; the box's env files
   (the operator's `sudo`, then restart its units); the site's environment, then a manual deploy.
6. **Revoke** every old key at its provider, the old n8n API key, and log out other n8n sessions.
7. **Verify.** Run the heartbeat Action once. `Settings → Error Workflow` still names the error
   handler (unbound logs nothing and says nothing). `db-guard`'s log shows `ok` lines. Each
   webhook answers its sender. A schedule fires at the expected UTC hour (`07:00` Zurich is
   `05:00` UTC in summer): neither the API nor `/rest/settings` shows the timezone.
