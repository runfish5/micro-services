# 11 - n8n Operations Center

Workflow monitoring and incident management via Telegram — check execution status, review failures, retry runs, and search invoices.

## Quick Start

1. Import `telegram-command-interface.n8n.json` into n8n
2. Verify credentials are connected (Telegram, Header Auth, Google Sheets)
3. Activate the workflow
4. Send `/help` to the bot in Telegram

## Safety Net (active — treat like a security control)

This project hosts the lab's **failure-alerting safety net**:
- **External heartbeat** — `.github/workflows/n8n-heartbeat.yml` + `scripts/n8n-heartbeat-check.sh` (one-time setup: `scripts/setup-heartbeat.sh`). Pings n8n every 15 min from outside Railway; failure → GitHub email. Full detail: **`docs/external-heartbeat.md`**.
- **In-n8n runner-proof + email alerts** live in `07_error-handler` (survive task-runner outages).

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/help` | `/help` | Show available commands |
| `/status` | `/status` | Show recent workflow executions |
| `/failures` | `/failures` | List pending failures from FailedItems |
| `/retry` | `/retry 36001` | Retry a failed execution by ID |
| `/search` | `/search Acme` | Search invoices by supplier name |

## Configuration

### Whitelist

Authorized Telegram chat IDs are defined in the **Whitelist Check** node:

```javascript
['YOUR_CHAT_ID_1', 'YOUR_CHAT_ID_2'].includes(String($json.message.chat.id))
```

To add a new user:
1. Get their chat ID (send a message to the bot, check trigger output)
2. Add the ID string to the array

### Credentials

| Purpose | Credential Name | ID |
|---------|-----------------|-----|
| Telegram | n8n_house_bot | `CREDENTIAL_ID_TELEGRAM` |
| n8n API | Header Auth account | `CREDENTIAL_ID_N8N_API` |
| Google Sheets | GoogleDriveMAIN | `CREDENTIAL_ID_GOOGLE_DRIVE` |

## Documentation

- **mainflow.md** - Complete node-by-node documentation
- **telegram-command-interface.n8n.json** - Workflow export

## Related Workflows

- **error-handler** - Logs failures to FailedItems sheet (queried by `/failures`)
- **8-hour-incident-resolver** - Auto-retries failures (same retry mechanism as `/retry`)
- **telegram-invoice-ocr-to-excel** - Writes to Billing_Ledger (queried by `/search`)
