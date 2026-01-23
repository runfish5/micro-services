# Telegram Command Interface

Command-line style interface via Telegram for monitoring and querying the home lab automation system.

## Quick Start

1. Import `telegram-command-interface.n8n.json` into n8n
2. Verify credentials are connected (Telegram, Header Auth, Google Sheets)
3. Activate the workflow
4. Send `/help` to the bot in Telegram

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
['7582730035', '7281469586'].includes(String($json.message.chat.id))
```

To add a new user:
1. Get their chat ID (send a message to the bot, check trigger output)
2. Add the ID string to the array

### Credentials

| Purpose | Credential Name | ID |
|---------|-----------------|-----|
| Telegram | n8n_house_bot | `OiAg5ImWe61JXymC` |
| n8n API | Header Auth account | `vjEcFZksIjUCKNRz` |
| Google Sheets | GoogleDriveMAIN | `O03W9YZyCWUacxnv` |

## Documentation

- **mainflow.md** - Complete node-by-node documentation
- **telegram-command-interface.n8n.json** - Workflow export

## Related Workflows

- **error-handler** - Logs failures to FailedItems sheet (queried by `/failures`)
- **8-hour-incident-resolver** - Auto-retries failures (same retry mechanism as `/retry`)
- **telegram-invoice-ocr-to-excel** - Writes to 2505_Invoices (queried by `/search`)
