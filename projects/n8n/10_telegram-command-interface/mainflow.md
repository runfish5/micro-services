# Telegram Command Interface - Mainflow Documentation

## Overview

Command-line style interface via Telegram for monitoring and querying the home lab automation system.

**Workflow ID:** (assigned after import)
**Node Count:** 22 (including 4 sticky notes)

## Architecture

```
Telegram Trigger
      │
      ▼
┌─────────────┐
│ Whitelist   │──(unauthorized)──> [drop/ignore]
│ Check       │
└─────────────┘
      │ (authorized)
      ▼
┌─────────────┐
│ Parse       │  Extract command + args from /command text
│ Command     │
└─────────────┘
      │
      ▼
┌─────────────────────────────────────────────────┐
│              Command Router (Switch)             │
├─────────┬─────────┬─────────┬─────────┬─────────┤
│ /help   │ /status │/failures│ /retry  │ /search │
└────┬────┴────┬────┴────┬────┴────┬────┴────┬────┘
     │         │         │         │         │
     ▼         ▼         ▼         ▼         ▼
  Format    n8n API   Sheets    n8n API   Sheets
  Help      Status    Read      Retry     Query
     │         │         │         │         │
     └─────────┴─────────┴────┬────┴─────────┘
                              ▼
                    ┌─────────────────┐
                    │  Merge + Split  │
                    │  Long Messages  │
                    └────────┬────────┘
                             ▼
                    ┌─────────────────┐
                    │ Send Telegram   │
                    │ Response        │
                    └─────────────────┘
```

## Node Reference

### Entry & Security (Nodes 1-2)

| Node | Type | Purpose |
|------|------|---------|
| Telegram Trigger | telegramTrigger | Receives messages, credential: `n8n_house_bot` |
| Whitelist Check | IF | Validates chat ID against `['7582730035', '7281469586']` |

### Command Parsing (Nodes 3-4)

| Node | Type | Purpose |
|------|------|---------|
| Parse Command | Code | Extracts `{chatId, command, args, rawText}` from message |
| Command Router | Switch | Routes to handler based on command name |

### Command Handlers

#### /help (Node 5)

| Node | Type | Purpose |
|------|------|---------|
| Format Help | Code | Returns static help text with command list |

#### /status (Nodes 6-7)

| Node | Type | Purpose |
|------|------|---------|
| Get Executions | HTTP Request | `GET /api/v1/executions?limit=10` |
| Format Status | Code | Formats execution list with status emojis |

#### /failures (Nodes 8-9)

| Node | Type | Purpose |
|------|------|---------|
| Read FailedItems | Google Sheets | Reads from `FailedItems` sheet |
| Format Failures | Code | Filters pending_retry/escalated, formats with severity emojis |

#### /retry (Nodes 10-13)

| Node | Type | Purpose |
|------|------|---------|
| Has Execution ID? | IF | Validates args contains execution ID |
| Retry Missing ID | Code | Error response if no ID provided |
| Execute Retry | HTTP Request | `POST /api/v1/executions/{id}/retry` |
| Format Retry | Code | Reports new execution ID or error |

#### /search (Nodes 14-17)

| Node | Type | Purpose |
|------|------|---------|
| Has Search Query? | IF | Validates args contains search term |
| Search Missing Query | Code | Error response if no query provided |
| Read Invoices | Google Sheets | Reads from `2505_Invoices` sheet |
| Format Search | Code | Case-insensitive filter by supplier_name |

#### Fallback (Node 18)

| Node | Type | Purpose |
|------|------|---------|
| Unknown Command | Code | Handles unrecognized commands and non-command messages |

### Response Pipeline (Nodes 19-22)

| Node | Type | Purpose |
|------|------|---------|
| Merge Responses | Merge | Combines all handler outputs |
| Split Long Message | Code | Chunks messages >4000 chars |
| Loop Over Chunks | Split In Batches | Iterates over chunks |
| Send Response | Telegram | Sends with Markdown parsing, adds part numbers |

## Data Flow

### Input (from Telegram Trigger)
```json
{
  "message": {
    "chat": { "id": 7582730035 },
    "text": "/status"
  }
}
```

### After Parse Command
```json
{
  "chatId": "7582730035",
  "command": "status",
  "args": "",
  "rawText": "/status"
}
```

### Handler Output (all handlers)
```json
{
  "chatId": "7582730035",
  "response": "formatted message text"
}
```

### After Split Long Message
```json
{
  "chatId": "7582730035",
  "chunk": "message chunk",
  "part": 1,
  "total": 1
}
```

## Credentials Used

| Credential | ID | Used By |
|------------|-----|---------|
| n8n_house_bot (Telegram) | `OiAg5ImWe61JXymC` | Trigger, Send Response |
| Header Auth account (n8n API) | `vjEcFZksIjUCKNRz` | Get Executions, Execute Retry |
| GoogleDriveMAIN | `O03W9YZyCWUacxnv` | Read FailedItems, Read Invoices |

## External Dependencies

| Resource | Document ID | Sheet |
|----------|-------------|-------|
| FailedItems | `1m-CxKMnfImceMJL1Fzv98jbVz6a9bGqqhy6ekPI-Cac` | gid=0 |
| 2505_Invoices | `1ZfqdUCMMWFvN-AMUKL7n-TIbSZAer3fqiH6Oy03tM94` | gid=0 |
| n8n API | `https://primary-production-2e961.up.railway.app` | - |

## Commands Reference

| Command | Args | Description |
|---------|------|-------------|
| `/help` | - | Show available commands |
| `/status` | - | List 10 most recent executions |
| `/failures` | - | List pending failures from FailedItems |
| `/retry` | `<execution_id>` | Retry a failed execution |
| `/search` | `<query>` | Search invoices by supplier name |

## Response Formatting

### Status Emojis
- `✅` success
- `❌` error
- `⏳` running
- `⏸` waiting
- `⛔` canceled

### Severity Emojis (failures)
- `🔴` critical
- `🟠` high
- `🟡` medium
- `🟢` low

## Message Chunking

Telegram has a 4096 character message limit. Messages over 4000 characters are automatically split into multiple messages with part indicators:

```
[1/3] First chunk of message...
[2/3] Second chunk...
[3/3] Final chunk.
```

## Security

- **Whitelist-based**: Only chat IDs in the whitelist array are processed
- **Silent rejection**: Unauthorized messages are dropped without response
- **No command injection**: Command parsing uses regex, args are passed as strings to API

## Extending Commands

To add a new command:

1. Add a new case to **Command Router** switch node
2. Create handler nodes (validation → action → format response)
3. Connect format node to **Merge Responses**
4. Handler must output `{chatId, response}`
