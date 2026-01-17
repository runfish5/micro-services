---
name: n8n-executions
description: Fetch and display recent n8n workflow execution logs from the Railways-hosted instance.
user_invocable: true
---

# n8n Execution Logs

Fetch recent execution logs from the n8n instance to debug workflows and monitor execution status.

## Configuration

- **Environment file:** `.claude/n8n-api.env`
- **Variables:** `N8N_API_URL`, `N8N_API_KEY`

## Instructions

When this skill is invoked:

1. **Load environment variables** from `.claude/n8n-api.env`:
   ```bash
   source .claude/n8n-api.env
   ```

2. **Fetch executions** using curl:
   ```bash
   curl -s "$N8N_API_URL/api/v1/executions?limit=<LIMIT>" \
     -H "X-N8N-API-KEY: $N8N_API_KEY"
   ```

   Default limit is 3 unless the user specifies otherwise.

3. **Parse and display** the results in a readable format:

   For each execution, show:
   - **Execution ID**
   - **Workflow name** (fetch from workflow details if needed)
   - **Status** (success/error/running/waiting)
   - **Started at** (human-readable timestamp)
   - **Finished at** (if completed)
   - **Duration** (calculated)
   - **Error message** (if failed)
   - **Mode** (manual/trigger/webhook)

4. **Format output** as a table or structured list:

   ```
   ## Recent Executions

   | # | Workflow | Status | Started | Duration | Mode |
   |---|----------|--------|---------|----------|------|
   | 1 | workflow-name | ✅ Success | 2h ago | 1.2s | trigger |
   | 2 | workflow-name | ❌ Error | 5h ago | 0.3s | manual |
   ```

   For failed executions, include the error details below the table.

## Arguments

- `limit=N` - Number of executions to fetch (default: 3, max: 100)
- `workflow=ID` - Filter by specific workflow ID
- `status=success|error|waiting` - Filter by status

## Example Usage

```
/n8n-executions              # Last 3 executions
/n8n-executions limit=10     # Last 10 executions
/n8n-executions status=error # Recent failures only
```

## Error Handling

- If API returns 401: API key may be invalid or expired
- If API returns 404: Check the n8n instance URL
- If connection fails: Instance may be sleeping (Railways free tier) - retry in 30s
