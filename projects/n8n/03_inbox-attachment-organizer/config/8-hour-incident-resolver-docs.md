# 007 Error Handler & 008 Task Resolver Setup

## Overview

- **007_error-handler.n8n.json** - Catches failed executions, classifies errors, logs to Google Sheets, sends Telegram alerts
- **008_8-hour-task-resolver.n8n.json** - Auto-retries failed executions every 8 hours via n8n API

---

## CRITICAL: Use n8n API Retry Only

**DO NOT replace with Execute Workflow nodes.** The 8-hour Task Resolver uses:
```
POST /api/v1/executions/{execution_id}/retry
```

- **API Retry** preserves original trigger data (Gmail message, webhook payload)
- **Execute Workflow** loses trigger context - requires manual `retry_input` passing which breaks when empty

---

## Setup Steps

### 1. Create n8n API Key

1. Open n8n Settings (user icon bottom left → Settings)
2. Navigate to "n8n API" section (or go to `http://localhost:5678/settings/api`)
3. Click "Create an API Key"
4. Name it (e.g., "8-hour-resolver")
5. **Copy the key immediately** - you'll only see it once

### 2. Create Header Auth Credential

1. Go to Credentials in n8n sidebar
2. Click "+ Add Credential"
3. Search for and select "Header Auth"
4. Configure:
   - **Name:** `n8n API`
   - **Name (header field):** `X-N8N-API-KEY`
   - **Value:** `<paste your API key here>`
5. Save

### 3. Import Workflows

Import both workflows into n8n:
- `007_error-handler.n8n.json`
- `008_8-hour-task-resolver.n8n.json`

### 4. Link Credential to Workflow

1. Open the 8-hour-task-resolver workflow
2. Click the "Execute Retry via API" node
3. In Credentials dropdown, select the "n8n API" credential you created

### 5. Set Error Handler as Default

1. Go to n8n Settings → Error Workflow
2. Select "Error Handler" workflow

---

## Networking Note

The 8-hour resolver calls the n8n API to retry executions. The URL depends on your hosting:

| Setup | URL to use |
|-------|------------|
| **Railway / Cloud platforms** | Your external URL (e.g., `https://your-app.up.railway.app`) |
| Docker Desktop (Windows/Mac) | `http://host.docker.internal:5678` |
| Docker on Linux | `http://172.17.0.1:5678` |
| Native install (no Docker) | `http://localhost:5678` |

**Current config uses:** Railway external URL (`https://primary-production-2e961.up.railway.app`)

If you get `ECONNREFUSED` or `ETIMEDOUT` errors, the URL doesn't match your setup. Edit the "Execute Retry via API" node URL directly in n8n.

---

## Troubleshooting

### "ECONNREFUSED ::1:5678"
n8n is in Docker but trying to reach `localhost`. Change URL to `host.docker.internal:5678`.

### "$env is not defined" or expression errors
`$env` requires n8n paid plan. The URL is now hardcoded - no env variables needed.

### API returns 401 Unauthorized
API key is invalid or credential not linked. Recreate the API key and credential.

### Retry starts but fails again
The retry re-runs the original execution with the same input. If the underlying issue isn't resolved (e.g., external API still down), it will fail again. Check the new execution's error.
