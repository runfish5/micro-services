# Shared n8n Infrastructure

Reusable workflows and components used across multiple projects.

## Error Handler Workflow

**File:** `error-handler.n8n.json`

Global error handler for all n8n workflows. Catches failures, classifies errors, logs to Google Sheets, and sends Telegram alerts with long message support.

### Setup

1. **Import workflow**: Paste `error-handler.n8n.json` into n8n
2. **Configure credentials**:
   - Connect your Google Sheets credential to the Append to FailedItems node
   - Connect your Telegram credential to the Send Telegram Alert node
   - Update `YOUR_TELEGRAM_CHAT_ID` in the Format Telegram Alert code node
3. **Create FailedItems sheet**: Add a tab named `FailedItems` with headers:
   ```
   timestamp | workflow_id | workflow_name | execution_id | execution_mode | retry_of | error_message | error_stack | error_name | started_at | status | retry_count | error_type | severity | is_retryable | suggested_action
   ```
4. **Activate workflow**
5. **Set as Error Workflow**: In n8n Settings > Error Workflow > Select this workflow

### Error Classification

| Type | Severity | Retryable | Trigger |
|------|----------|-----------|---------|
| `auth_error` | critical | No | 401, 403, credential issues |
| `rate_limit` | high | Yes | 429, quota exceeded |
| `network_error` | high | Yes | Timeout, connection refused |
| `parse_error` | medium | No | Invalid JSON, schema mismatch |
| `validation_error` | medium | No | Missing required fields |
| `resource_error` | critical | No | Out of memory/disk |
| `unknown` | medium | No | Unclassified errors |

### Telegram Alerts

Sends color-coded alerts based on severity:
- Red: Critical (auth, resource)
- Orange: High (rate limit, network)
- Yellow: Medium (parse, validation, unknown)

**Long message support**: Messages over 4000 chars are split into chunks and sent as multiple messages with part numbers `[1/3]`, `[2/3]`, etc.

### Manual Retry

Failed items can be retried via:
- n8n UI: Executions > Find failed > Retry
- FailedItems sheet: Update `status` column, create retry workflow

### Testing

Use a Code node with test errors:
```js
// Rate Limit (retryable)
throw new Error("429 Too Many Requests - rate limit exceeded");

// Auth Error (critical)
throw new Error("401 Unauthorized - invalid credentials");

// Network Error (retryable)
throw new Error("ETIMEDOUT - connection timed out");
```
