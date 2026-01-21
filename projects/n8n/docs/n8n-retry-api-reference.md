# n8n API Retry Endpoint Response

## How to Fetch Execution Data

```bash
# Get basic execution info
source .claude/n8n-api.env && curl -s "$N8N_API_URL/api/v1/executions/{ID}" -H "X-N8N-API-KEY: $N8N_API_KEY"

# Get full execution with node data
source .claude/n8n-api.env && curl -s "$N8N_API_URL/api/v1/executions/{ID}?includeData=true" -H "X-N8N-API-KEY: $N8N_API_KEY" > temp.json

# Extract specific node (PowerShell)
powershell -Command "(Get-Content 'temp.json' | ConvertFrom-Json).data.resultData.runData.'NodeName' | ConvertTo-Json -Depth 10"
```

## Endpoint
```
POST /api/v1/executions/{id}/retry
```

## Response Behavior

The retry endpoint returns **immediately when the retry STARTS**, not when it completes.

### Success Response (retry started)
```json
{
  "id": "36001",
  "finished": false,
  "mode": "retry",
  "retryOf": "35923",
  "status": "running",
  "startedAt": "2026-01-21T10:17:45.000Z",
  "stoppedAt": null,
  "workflowId": "lRCrJIj1AEsuNxts"
}
```

**Note:** The `id` is at the root level, NOT wrapped in a `data` object.

### Error Response (execution not found, already running, etc.)
```json
{
  "message": "Execution not found",
  "code": 404
}
```
Or no `id` field present at root.

## Key Points

1. **`id`** - New execution ID for the retry (at root level). Check this to confirm retry started.
2. **Response is immediate** - Does not wait for execution to finish.
3. **Poll for completion** - Use `GET /api/v1/executions/{new_id}` to check actual result.
4. **`retryOf` field** - Links new execution to original failed execution.

## Polling for Completion

```
GET /api/v1/executions/{new_execution_id}
```

Response includes:
- `status`: "success", "error", "running", "waiting", "canceled"
- `finished`: boolean indicating execution completed
- Check `status === 'success' && finished === true` for true success.
