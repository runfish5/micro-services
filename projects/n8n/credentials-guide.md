# Credentials Guide

## AI Chatbot APIs

These power the AI nodes in n8n that extract data from text and images.

### Groq

Free tier API for text-based AI (data extraction, classification).

- Get API key at [console.groq.com](https://console.groq.com)
- n8n: Credentials → Add → Groq

### Google Gemini

Free tier API for image/PDF reading (OCR, vision).

- Get API key at [aistudio.google.com](https://aistudio.google.com)
- n8n: Credentials → Add → Google Gemini API

---

## n8n Service Credentials

General n8n credential setup: [docs.n8n.io/credentials](https://docs.n8n.io/credentials/)

### Gmail

For email monitoring and reading attachments.

- Uses Google OAuth2 (same credential works for Drive and Sheets)
- n8n: Credentials → Add → Gmail OAuth2

### Google Drive

For uploading files and creating folder structures.

- Uses same Google OAuth2 credential as Gmail
- n8n: Credentials → Add → Google Drive OAuth2

### Telegram

For bot notifications (optional).

- Create bot via [@BotFather](https://t.me/botfather), get token
- n8n: Credentials → Add → Telegram

### Brave Search

For factual web lookups (used by steward's menu-handler).

- 2'000 free requests/month
- n8n: Credentials → Add → **Header Auth**
- Name: `X-Subscription-Token`, Value: your API key
- Get API key at [brave.com/search/api](https://brave.com/search/api/)


### Google Apps Script (Execution API)

For calling Apps Script functions from n8n (n8n API writes don't trigger `onEdit`).

- n8n: Credentials → Add → **Google OAuth2 API**
- Fields:
  | Field | Value |
  |-------|-------|
  | Client ID | From the GCP project your Apps Script is linked to |
  | Client Secret | From the same GCP project |
  | Scope(s) | `https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/script.scriptapp` (space-separated) |
  | Allowed HTTP Request Domains | `https://script.googleapis.com` (only if your instance restricts outbound requests) |
- Click **Save** → **Connect** → grant permissions

> **Why a separate credential?** Built-in n8n credential types (Gmail OAuth2, Google Sheets OAuth2, Google Drive OAuth2) have **fixed scopes** — you can't add `script.scriptapp` to them. The generic **Google OAuth2 API** type lets you specify custom scopes. The scopes in the n8n credential must **exactly match** the `oauthScopes` in your `appsscript.json`.

In the HTTP node (e.g., `[CRM] Write via Apps Script`), select this credential and paste the Apps Script deployment URL.

#### 403 Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 "The caller does not have permission" | Reusing a built-in credential (Gmail/Drive/Sheets OAuth2) — token lacks script scopes | Create a new **Google OAuth2 API** credential with all 3 scopes |
| 403 after adding scopes to existing credential | Old token cached without new scopes | **Disconnect** the credential in n8n, then **Reconnect** to get a fresh token |
| 403 despite correct scopes | Script linked to different GCP project than the credential | In Apps Script → Project Settings → verify GCP Project Number matches |
| 403 after switching to a new GCP project | Apps Script still linked to old project | Re-link: Apps Script → Project Settings → **Change project** → new Project Number. Then re-run `testWriteContactData()` from editor to re-authorize. Also enable Apps Script API in the new GCP Console |
| 403 despite everything matching | Script not authorized locally yet | Run the test function once from Apps Script editor (triggers consent screen) |

**Full setup** (GCP project, script creation, deployment, troubleshooting): [Apps Script Execution API Setup](02_smart-table-fill/docs/apps-script-execution-api-setup.md)

---

### Notion

For reading and writing Notion pages/databases from n8n.

- **Already have an integration?**
  Go to [notion.so/profile/integrations](https://www.notion.so/profile/integrations) → find your integration → click **Connections** on the right → click the three dots (`...`) → **Copy internal integration token** → paste into n8n: Credentials → Add → Notion API

- **Don't have one yet?**
  Follow the [Notion integration setup guide](https://www.notion.so/help/create-integrations-with-the-notion-api) to create one, then copy the token as above.

This is one of the simplest connections — just paste the token and you're done.
