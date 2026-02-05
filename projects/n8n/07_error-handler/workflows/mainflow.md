# error-handler Flow

```
Error Trigger → Prepare Error Record → Classify Error → IF: Rate Limit Auto-Retry?
                                                              │
                                           ┌──────────────────┴──────────────────┐
                                          YES                                    NO
                                           │                                      │
                                  Extract Config for Retry    Is Resolver Failure?
                                           │                              │
                                    Wait (Rate Limit)     ┌───────────────┴───────────────┐
                                           │             YES                              NO
                                Execute smart-folder2table  │                               │
                                           │       CODE RED Alert           Append to FailedItems
                                Send Auto-Retry Alert     │                               │
                                                          └──────────────┬────────────────┘
                                                                         │
                                                               Format Telegram Alert
                                                                         │
                                                               Split Long Message
                                                                         │
                                                               Loop Over Chunks
                                                                         │
                                                               Send Telegram Alert
                                                                         │
                                                                   (loop back)
```

## Key Nodes

| Node | Purpose |
|------|---------|
| **Error Trigger** | n8n's built-in error trigger - receives all workflow failures |
| **Prepare Error Record** | Extracts execution context, failed node, error message, attachment count |
| **Classify Error** | Determines error type, severity, retryability; calculates LLM cost estimate; checks auto-retry registry |
| **IF: Rate Limit Auto-Retry?** | Checks if error_type is rate_limit AND workflow is in auto-retry registry |
| **Extract Config for Retry** | Extracts original Config values from failed execution's runData + adds rate_limit_wait_seconds |
| **Wait (Rate Limit)** | Waits retry_after_seconds (extracted from error or default 60s) |
| **Execute smart-folder2table** | Calls smart-folder2table via Execute Workflow with original config + rate_limit_wait_seconds |
| **Send Auto-Retry Alert** | Telegram notification that auto-retry is happening |
| **Is Resolver Failure?** | Checks if the 8-hour Task Resolver itself failed (watchdog scenario) |
| **CODE RED Alert** | Immediate critical alert before normal processing |
| **Append to FailedItems** | Logs to Google Sheets with upsert on execution_id |
| **Format Telegram Alert** | Builds message with severity emoji, LLM cost info |
| **Split Long Message** | Chunks messages over 4000 chars for Telegram limit |
| **Loop Over Chunks** | Sends each chunk as `[1/N]`, `[2/N]`, etc. |

## Auto-Retry Registry

Workflows in the registry get immediate automatic retry on rate limit errors instead of waiting for the 8-hour resolver.

**Current registry:**
- `smart-folder2table`
- `any-file2json-converter`

**How it works:**
1. Classify Error checks if workflow name matches any entry in `AUTO_RETRY_REGISTRY`
2. Extracts "retry in Xs" timing from error message (defaults to 60s)
3. If rate_limit + in registry → Extract Config → Wait → Execute Workflow → Telegram alert
4. If rate_limit + NOT in registry → Normal flow (log + alert + 8-hour resolver)

**To add a workflow:** Edit the `AUTO_RETRY_REGISTRY` array in the "Classify Error" code node.

## Execute Workflow Retry (No Sheet Storage)

When a rate limit error occurs for smart-folder2table, the error handler restarts it via Execute Workflow instead of API retry. This passes the rate limit timing directly as a parameter.

**Pattern: Start Fast, Adapt on Error**
```
smart-folder2table runs fast (0s wait)
       ↓
Rate Limit Error (429) on file #6
       ↓
Error Handler catches it
       ↓
Extract "retry in 55s" from error message
       ↓
Extract Config values from execution.runData['Config']
       ↓
Call smart-folder2table via Execute Workflow
  with: original Config + rate_limit_wait_seconds = 55
       ↓
smart-folder2table starts fresh
       ↓
Files 1-5 already in sheet → skipped (resumability check)
       ↓
File #6 onwards with 55s waits
```

**Why Execute Workflow instead of API Retry?**
- API retry preserves original trigger data (good for Gmail workflows)
- smart-folder2table doesn't need trigger data - it reads folder_id from Config
- Execute Workflow lets us pass `rate_limit_wait_seconds` as a parameter
- Resumability is sheet-based (already-processed files are skipped)

**Note:** Other workflows (like inbox-attachment-organizer) still need API retry to preserve trigger data (Gmail messages, webhooks, etc.).

## Output Fields (FailedItems Sheet)

```
timestamp | workflow_id | workflow_name | execution_id | execution_mode |
failed_node | retry_of | error_message | error_stack | error_name |
started_at | status | retry_count | error_type | severity |
is_retryable | suggested_action | retry_input | retry_params
```

## Credentials

- `CREDENTIAL_ID_GOOGLE_DRIVE` - Google Sheets OAuth for FailedItems logging
- `CREDENTIAL_ID_TELEGRAM_IMPORTANT` - Telegram bot for alerts
