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

**Structured signal first, text second.** `error.httpCode` is carried by every `NodeApiError` and
is unambiguous; substring matching is not, and getting this backwards cost months (below). Text
matching remains the fallback for `NodeOperationError`, which carries no code.

| Type | Severity | Retryable | Trigger |
|------|----------|-----------|---------|
| `handler_blind` | critical | No | **This workflow** could not find the error in the trigger payload |
| `auth_error` | critical | No | `401`/`403`, credential issues |
| `rate_limit` | high | Yes | `429`, quota exceeded |
| `config_error` | high | No | `404` — a wrong id, never a transient |
| `network_error` | high | Yes | `5xx`/`522`/`408`/`ECONN*`, timeout, *timed out*, task runner not matched |
| `llm_schema_error` | high | Yes | "doesn't fit required format", "output parser", "failed to parse" |
| `validation_error` | medium | No | `400`, missing required fields |
| `parse_error` | medium | No | Invalid JSON, syntax errors |
| `resource_error` | critical | No | Out of memory/disk |
| `unknown` | medium | No | Unclassified errors |

Non-retryable rows are written with `status: needs_review`, not `pending_retry` — the resolver
selects on **both** `status === 'pending_retry'` and `is_retryable === true`, and `status` used to
be hardcoded for every row regardless of type.

### Absence is not a diagnosis

The extraction fallback used to be the sentence *"LLM output did not match required schema"*, and
the `llm_schema_error` branch matched that exact string — one n8n **never emits**. The handler
invented a symptom and then diagnosed it. Combined with reading `$json.error` (n8n nests it at
`$json.execution.error`), extraction found nothing on *every* failure, so **100% of rows were
labelled `llm_schema_error`, retryable** — for months. Everything downstream agreed, because
everything downstream reads this one field.

Three rules earned by that, all load-bearing:

1. **A missing value may become `unknown`; it may never become a specific cause.** If the handler
   cannot see the error, that *is* the incident → `handler_blind`, which names the payload keys it
   did find, so the next n8n upgrade that moves the shape says so on day one.
2. **`llm_schema_error` must stay above `parse_error` and `validation_error`.** *"doesn't fit
   required format"* contains `required`, and *"failed to parse"* contains `parse` — either branch
   swallows it, and the type silently goes back to being unreachable.
3. **Non-retryable is what makes a defect visible.** `upkeep-digest` only promotes an
   already-non-retryable signature, so a wrong `is_retryable` hides a bug rather than merely
   mislabelling it.

Verified against the 285-failure retained corpus on 2026-08-12: `llm_schema_error` **0**,
`network_error` 108, `rate_limit` 68, `config_error` 53, `validation_error` 29, `unknown` 24,
`parse_error` 2 — across 36 distinct fingerprints, where the old code produced one signature
per node.

### Telegram alerts strip Markdown

Every interpolated value passes through `.replace(/[_*\[\]`~]/g,'')`. n8n's Telegram node defaults
to legacy Markdown, where `_ * [` and `` ` `` open an entity and **one** unbalanced character fails
the whole `sendMessage` — which is how the runner-proof branch lost 22 alerts during the outage it
exists for. This became load-bearing the moment `error_message` started carrying real error text
instead of one fixed, punctuation-free sentence; workflow names alone (`04_inbox-…`) would break it.

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
