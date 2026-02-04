# error-handler Flow

```
Error Trigger → Prepare Error Record → Classify Error → Is Resolver Failure?
                                                              │
                                           ┌──────────────────┴──────────────────┐
                                          YES                                    NO
                                           │                                      │
                                    CODE RED Alert              Append to FailedItems
                                           │                                      │
                                           └──────────────┬───────────────────────┘
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
| **Classify Error** | Determines error type, severity, retryability; calculates LLM cost estimate |
| **Is Resolver Failure?** | Checks if the 8-hour Task Resolver itself failed (watchdog scenario) |
| **CODE RED Alert** | Immediate critical alert before normal processing |
| **Append to FailedItems** | Logs to Google Sheets with upsert on execution_id |
| **Format Telegram Alert** | Builds message with severity emoji, LLM cost info |
| **Split Long Message** | Chunks messages over 4000 chars for Telegram limit |
| **Loop Over Chunks** | Sends each chunk as `[1/N]`, `[2/N]`, etc. |

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
