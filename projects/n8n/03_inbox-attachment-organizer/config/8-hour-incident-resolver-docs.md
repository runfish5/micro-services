# 8-Hour Task Resolver

Auto-retries failed workflow executions logged in FailedItems sheet every 8 hours.

## Flow

```
Every 8 Hours → Read FailedItems → Prepare Items → Loop Over Items
                                        ↓
                              (assign _rowIndex, filter pending_retry, sort DESC)
```

**Per item in loop:**
```
retry_count < 3?
├─ YES → Calculate Delay → Wait → Execute Retry via API → Poll Loop → If Success?
│                                                              ├─ YES → Archive → Delete → Loop
│                                                              └─ NO  → Update retry_count → Loop
└─ NO  → Mark Escalated → Update Sheet → Telegram Alert → Loop
```

## Row Index Pattern (v6)

**Why `_rowIndex`?** Google Sheets delete shifts rows up. Without tracking original row numbers, deleting row 5 makes former row 6 become new row 5, causing wrong deletions.

**Solution:**
1. Assign `_rowIndex` at fetch time (data row = JS index + 2, since row 1 is header)
2. Sort DESC before processing (delete row 10 first, then row 5)
3. Use `startRowNumber` in delete operation

The "Prepare Items" node does all three: assigns indices, filters, and sorts in one step.

---

## CRITICAL: Use n8n API Retry Only

**DO NOT replace with Execute Workflow nodes.** The resolver uses:
```
POST /api/v1/executions/{execution_id}/retry
```

- **API Retry** preserves original trigger data (Gmail message, webhook payload)
- **Execute Workflow** loses trigger context - the retry would start with empty input

---

## Setup

### 1. Create n8n API Key

1. n8n Settings → n8n API → Create an API Key
2. Copy the key immediately (shown only once)

### 2. Create Header Auth Credential

1. Credentials → Add Credential → Header Auth
2. Configure:
   - **Name:** `n8n API`
   - **Name (header field):** `X-N8N-API-KEY`
   - **Value:** `<your API key>`

### 3. Link Credential

Open workflow and select the "n8n API" credential in both HTTP Request nodes:
- "Execute Retry via API"
- "Poll Execution Status"

### 4. Set Error Handler as Default

Settings → Error Workflow → Select "Error Handler"

---

## Networking

| Setup | URL |
|-------|-----|
| **Railway / Cloud** | External URL (e.g., `https://your-app.up.railway.app`) |
| Docker Desktop | `http://host.docker.internal:5678` |
| Docker Linux | `http://172.17.0.1:5678` |
| Native install | `http://localhost:5678` |

**Current:** Railway (`https://primary-production-2e961.up.railway.app`)

---

## Troubleshooting

### "ECONNREFUSED ::1:5678"
n8n is in Docker but URL uses localhost. Change to `host.docker.internal:5678`.

### API returns 401 Unauthorized
API key invalid or credential not linked. Recreate API key and re-link credential.

### Execution times out (30 polls = 5 min)
Increase threshold in "Should Continue Polling?" node (e.g., `poll_count < 60` for 10 min).

### Retry starts but fails again
Underlying issue not resolved. Check the new execution's error for root cause.

### Items incorrectly archived (pre-v6)
If items were deleted despite failed retry, check All-Time Logs for `execution_status: "error"` entries - these were incorrectly archived due to earlier bugs.
