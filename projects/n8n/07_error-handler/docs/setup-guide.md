## Setup Guide — Error Handler

**Time:** ~10 min | **Difficulty:** Easy | **Cost:** Free

Global error handler for all n8n workflows. Catches failures, classifies errors,
logs to Google Sheets, and sends Telegram alerts.

---

### Step 1: Create the FailedItems Google Sheet

1. Create a new spreadsheet (e.g., name it `007_Error-handler.n8n-sheet`)
2. Rename the first tab to **FailedItems**
3. Add these headers to **row 1**:

| timestamp | workflow_id | workflow_name | execution_id | execution_mode |
|-----------|-------------|---------------|--------------|----------------|

| failed_node | retry_of | error_message | error_stack | error_name |
|-------------|----------|---------------|-------------|------------|

| started_at | status | retry_count | error_type | severity |
|------------|--------|-------------|------------|----------|

| is_retryable | suggested_action | retry_input | retry_params |
|--------------|------------------|-------------|--------------|

(single header row with all 18 columns)

---

### Step 2: Import the Workflow

1. Download [`007-error-handler.json`](../workflows/007-error-handler.json)
2. In n8n: **Workflows → Import from File** → select the JSON
3. **Save**

---

### Step 3: Connect Credentials

- **Google Sheets (OAuth2)** — for logging to FailedItems sheet
- **Telegram Bot** — for sending alerts

Assign each credential to its matching nodes. (n8n highlights missing credentials in red.)
See [credentials-guide.md](../../credentials-guide.md) for details.

---

### Step 4: Node Edits After Import

These settings reference environment-specific IDs that are cleared on import:

**Append to FailedItems** (Google Sheets node)
1. Document → select your FailedItems spreadsheet
2. Sheet → `FailedItems`
3. Column to Match On → `execution_id`

**Send Telegram Alert** / **CODE RED Alert** / **Send Auto-Retry Alert**
- Chat ID → your Telegram chat ID

---

### Step 5: Set as Error Workflow

1. In n8n: **Settings → Error Workflow**
2. Select this workflow
3. Activate the workflow

Every workflow failure in your instance will now be caught here.

---

### Step 6: Test

1. Create a test workflow with a Code node: `throw new Error("test error");`
2. Activate + trigger it
3. Verify: row appears in FailedItems sheet + Telegram alert received

---

### Troubleshooting

| Problem | Fix |
|---------|-----|
| No errors caught | Verify workflow is set as Error Workflow in Settings |
| Sheet row missing | Re-check Step 4 — document, sheet, match column |
| No Telegram alert | Check bot token + chat ID in Telegram nodes |
| "Sheet not found" | Verify tab is named exactly `FailedItems` |
| Message truncated | Normal — messages >4000 chars are auto-chunked |
