# error-handler

Global error handler for all n8n workflows. Catches failures, classifies errors, logs to Google Sheets, and sends Telegram alerts.

## Purpose

Set as n8n's Error Workflow (Settings > Error Workflow) to catch all workflow failures. Provides:
- Error classification by type and severity
- Persistent logging to FailedItems Google Sheet
- Telegram alerts with color-coded severity
- CODE RED alerts for watchdog failures (8-hour Task Resolver) — these also continue into normal logging + alerts
- Long message chunking for Telegram's 4096 char limit

**Alerting (runner-proof + email):** every failure fires on **both Telegram and email** (email reuses the Gmail OAuth credential). A `Runner/Infra Down?` branch sends an **expression-only** alert (no Code node) so it survives task-runner outages — the normal Code-node pipeline can't. Regex must be plain JS (no inline `(?i)` flag). Part of the lab's active safety net → see `../13_n8n-ops-center/docs/external-heartbeat.md`.

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

1. Import workflows/010-error-handler.json into n8n
2. Configure credentials (Google Sheets, Telegram)
3. Create `FailedItems` sheet with headers (see workflow sticky note)
4. Activate workflow
5. Set as Error Workflow in n8n Settings

Full guide: [docs/setup-guide.md](docs/setup-guide.md)

## Node Edits After Import

Settings cleared on import that must be re-selected manually:

| Node | Setting | Value |
|------|---------|-------|
| **Append to FailedItems** | Document | Your FailedItems spreadsheet |
| **Append to FailedItems** | Sheet | `FailedItems` |
| **Append to FailedItems** | Column to Match On | `execution_id` |
| **Send Telegram Alert** | Chat ID | `YOUR_CHAT_ID_1` |
| **CODE RED Alert** | Chat ID | `YOUR_CHAT_ID_1` |
| **Send Auto-Retry Alert** | Chat ID | `YOUR_CHAT_ID_1` |

## Recurrence → the morning UPKEEP section

`Prepare & Classify Error` also computes a **`fingerprint`** — `hash(workflow_id + failed_node +
normalised message)` — and writes it, with `error_signature`, to `FailedItems`. A failure that
repeats byte-identically is a defect, not an incident, and this is the only thing in the lab that
can tell the difference.

`workflows/upkeep-digest.json` is the briefing plugin that renders them. It **groups at read
time and never counts into a column**: failures arrive in bursts, Sheets read-then-write is not
atomic, and an upsert could reset a status a human set. Events are counted; state is stored.

Two rules that are easy to get wrong:

- **Recurrence promotes, it never demotes.** Repeating identically is not evidence of a defect —
  rate limits and runner timeouts do exactly that, and are what retry exists for. Recurrence may
  lift an already-non-retryable error to "defect"; the classifier keeps the veto.
- **`FailedItems` needs the `fingerprint` and `error_signature` headers.** The append uses
  `autoMapInputData`, which silently drops fields with no matching column.

Design, corpus evidence and the staged plan: [docs/upkeep-tasks-spec.md](docs/upkeep-tasks-spec.md).

## Dependencies

- Google Sheets (FailedItems logging; `upkeep-digest` also reads the `Tasks` tab in the
  Billing_Ledger document — two different spreadsheets)
- Telegram (alerts)
- Works with: `11_8-hours-incident-resolver`, `05_daily-briefing` (plugin seam),
  `16_commitments-ledger` (the `Tasks` table and the tap handler)
