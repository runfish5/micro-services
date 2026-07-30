# DB Janitor

> Weekly scheduled workflow that scans for old/oversized n8n executions and sends a Telegram cleanup report. Stub mode — reports only, no automatic deletion.

## Architecture

```
Weekly Schedule (Sun 3 AM) --> Config --> Fetch Executions --> Analyze Executions --> Has Candidates? --YES--> Format Report -----------> Send to Telegram
Manual Trigger ------------/                                                                        \--NO--> No Candidates Message --/
```

## Why This Exists

Binary data (email attachments, PDFs) stored inline in PostgreSQL execution records causes volume bloat. The inbox-attachment-organizer alone stores ~237KB per execution (5x other workflows). This workflow surfaces cleanup candidates so you can reclaim space.

Pair with the `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` env var (see `docs/infra-ops.md`) to prevent future bloat from new executions.

## Node Details

| Node | Type | Purpose | References |
|------|------|---------|------------|
| Weekly Schedule | scheduleTrigger | Fires Sunday at 3 AM (cron: `0 3 * * 0`) | -- |
| Manual Trigger | manualTrigger | Testing entry point | -- |
| Config | code | Defines cleanup rules: `maxAgeDays`, `maxSizeThresholdKB`, target workflow IDs | Edit workflow IDs here |
| Fetch Executions | httpRequest | `GET /api/v1/executions?limit=100&status=success` via n8n API | Header Auth: `CREDENTIAL_ID_N8N_API` |
| Analyze Executions | code | Filters by age + workflow ID, counts candidates, estimates reclaimable MB | References Config node |
| Has Candidates? | if | Routes based on whether any old executions were found | -- |
| Format Report | code | Builds Markdown summary with per-workflow counts and space estimate | -- |
| No Candidates Message | code | Returns "no candidates found" message | -- |
| Send to Telegram | telegram | Sends report to admin chat | Chat ID: `YOUR_CHAT_ID_1` |

## Configuration

Edit the **Config** node to adjust:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `maxAgeDays` | 14 | Executions older than this are flagged |
| `maxSizeThresholdKB` | 100 | Size threshold for binary-heavy executions |
| `targetWorkflows` | inbox-organizer, file-converter | Workflow IDs to prioritize in the report |
| `batchSize` | 100 | Number of executions to fetch per scan |

## Credentials

| Credential | Type | Used By |
|------------|------|---------|
| n8n API Key | httpHeaderAuth (`CREDENTIAL_ID_N8N_API`) | Fetch Executions |
| Telegram | telegramApi (`CREDENTIAL_ID_TELEGRAM`) | Send to Telegram |

## Post-Import Setup

1. Update **Config** node `targetWorkflows` with your actual workflow IDs
2. Set credential IDs for n8n API and Telegram
3. Update **Fetch Executions** URL to your n8n instance
4. Update **Send to Telegram** chat ID
5. Run via Manual Trigger to verify — should receive a Telegram report

## Sample Report

```
DB Janitor Report
Scanned: 100 recent executions
Older than 14 days: 43

- inbox-attachment-organizer: 28
- any-file2json-converter: 8
- other: 7

Estimated reclaimable: ~7.2 MB

(Stub mode — no deletions performed)
```
