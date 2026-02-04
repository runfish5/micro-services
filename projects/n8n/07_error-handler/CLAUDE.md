# error-handler

Global error handler for all n8n workflows. Catches failures, classifies errors, logs to Google Sheets, and sends Telegram alerts.

## Purpose

Set as n8n's Error Workflow (Settings > Error Workflow) to catch all workflow failures. Provides:
- Error classification by type and severity
- Persistent logging to FailedItems Google Sheet
- Telegram alerts with color-coded severity
- CODE RED alerts for watchdog failures (8-hour Task Resolver)
- Long message chunking for Telegram's 4096 char limit

## Error Classification

| Type | Severity | Retryable | Trigger |
|------|----------|-----------|---------|
| `auth_error` | critical | No | 401, 403, credential issues |
| `rate_limit` | high | Yes | 429, quota exceeded |
| `network_error` | high | Yes | Timeout, connection refused |
| `llm_schema_error` | high | Yes | LLM output didn't match schema |
| `parse_error` | medium | No | Invalid JSON, syntax errors |
| `validation_error` | medium | No | Missing required fields |
| `resource_error` | critical | No | Out of memory/disk |
| `unknown` | medium | No | Unclassified errors |

## LLM Cost Estimation

Calculates expected Groq/Google API calls for retry scheduling (rate-limit awareness). Cost varies by failed node - earlier failures = more work remaining.

## Setup

1. Import workflows/007-error-handler.json into n8n
2. Configure credentials (Google Sheets, Telegram)
3. Create `FailedItems` sheet with headers (see workflow sticky note)
4. Activate workflow
5. Set as Error Workflow in n8n Settings

## Dependencies

- Google Sheets (FailedItems logging)
- Telegram (alerts)
- Works with: `04_inbox-attachment-organizer/8-hour-incident-resolver`
