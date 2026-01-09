# Apps Script Execution API Setup

**Time:** 20 min | **Difficulty:** Intermediate | **Cost:** Free

This guide configures n8n to call Google Apps Script via the Execution API with OAuth authentication. No public endpoints, no tokens - secure OAuth only.

---

## Prerequisites

- [Google Cloud Console](https://console.cloud.google.com) access
- [n8n](https://n8n.io) instance (self-hosted or cloud)
- Google Sheet with your data (e.g., "Entries" sheet)
- [03_inbox-attachment-organizer](../../03_inbox-attachment-organizer) workflow with [smart-table-fill subworkflow](email-crm-guide.md) (activate the HTTP node instead of Excel)

---

## Step 1: Find Your GCP Project Number & Enable API

Your existing n8n Google credentials use a GCP project. We need to link Apps Script to the **same project**.

> **Why this matters:** Every Apps Script is assigned a hidden, Google-managed GCP project by default. This works fine for built-in services (GmailApp, DriveApp, CalendarApp) and manual/trigger runs - the script stays "inside" Google's ecosystem. But when an *external* app like n8n calls via the Execution API, it needs OAuth credentials that match the script's project. The hidden default can't issue credentials, so you must link both to the same visible GCP project.

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. In the project dropdown (top left), find the project your n8n credentials use
   - If unsure: check your n8n credential's Client ID - it contains the project info
3. Once in the correct project, go to **Dashboard**
4. Note the **Project Number** (numeric, e.g., `126925216054`) - NOT the Project ID
5. Enable Apps Script API: Go to [Apps Script API](https://console.cloud.google.com/apis/library/script.googleapis.com) and click **Enable**

---

## Step 2: Create Apps Script Project

### 2.1 Create New Script

Open your Google Sheet, go to **Extensions** > **Apps Script** - this creates a script bound to your sheet (or go to [script.google.com](https://script.google.com) > **New project** and name it).

### 2.2 Add the Code

1. Delete any default code in `Code.gs`
2. Copy the entire contents of [`scripts/AppScript-new-contact-setup.js`](../scripts/AppScript-new-contact-setup.js) from this repo
3. Paste into `Code.gs`
4. Update `CONFIG` with your settings:
   - `spreadsheetId`: the Google Sheet that smart-table-fill writes to
   - `folderPath`: path where you want ContactManager to live (e.g., `['MyDrive', 'ContactManager', 'names_folders']`)

### 2.3 Add OAuth Scopes to appsscript.json

1. In Apps Script editor: **Project Settings** (gear icon)
2. Enable **"Show 'appsscript.json' manifest file in editor"**
3. Click **Editor** (left sidebar) then click on `appsscript.json`
4. Add the `oauthScopes` array - your file should look like this:

```json
{
  "timeZone": "Europe/Zurich",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/script.scriptapp"
  ]
}
```

**Scope breakdown:**
| Scope | Required | Purpose |
|-------|----------|---------|
| `spreadsheets` | **Yes** | Read/write sheet data |
| `drive` | **Yes** | Create contact folders |
| `script.scriptapp` | **Yes** | Trigger setup & testing from Apps Script editor |

**Note:** Keep any other settings your file already has (like `webapp` or `executionApi`). Just add the `oauthScopes` array.

5. Save (Ctrl+S)

---

## Step 3: Link Apps Script to GCP Project

1. In Apps Script editor: **Project Settings** (gear icon)
2. Under "Google Cloud Platform (GCP) Project", click **Change project**
3. Enter the **Project Number** from Step 1 (numeric, NOT the Project ID)
4. Click **Set project**

---

## Step 4: Deploy as API Executable

1. In Apps Script editor: **Deploy** > **New deployment**
2. Click the gear icon next to "Select type"
3. Select **API Executable** - a new "API Executable" section appears, leave the field "Who has access as "Only myself"
4. Click **Deploy**

### Verify Your Deployment

1. Go to **Deploy** > **Manage deployments**
2. You should see an **API executable** section with a URL like:
   ```
   https://script.googleapis.com/v1/scripts/AKfycbz...your-id...:run
   ```
3. **Copy this entire URL** - paste it into the "Write via Apps Script" HTTP node at the end of [smart-table-fill](../workflows/smart-table-fill.n8n.json)

Just copy this full URL and paste it into the HTTP node. (Note: Google's docs mention using Script ID, but the Deployment ID `AKfycb...` in this URL is what actually works.)

---

## Step 5: Authorize the Script

1. In Apps Script editor with `Code.gs` open, select `testWriteContactData` from the function dropdown (next to the Debug button in the toolbar)
2. Click **Run** (play button)
3. Authorization popup will appear:
   - Click **Review permissions**
   - Select your Google account
   - Click **Advanced** > **Go to {project name} (unsafe)** - this warning appears because your app isn't verified by Google, but it's your own script so it's safe
   - Click **Allow** to grant all permissions
4. Check Execution log - should show success response

**Note:** If you see permission errors, verify `appsscript.json` has the required scopes.

---

## Step 6: Create n8n OAuth Credential

> **Why another credential?** Your existing Gmail/Drive credentials have fixed scopes you can't change. Scopes are security - only grant what's needed; Google has no "access everything" option. Here we need multiple (Sheets + Drive), so we use the generic "Google OAuth2 API" which lets you combine them. For Execution API, n8n must request the *exact same scopes* as `appsscript.json`.

1. In n8n: **Settings** > **Credentials** > **Add Credential**
2. Search for: **Google OAuth2 API**
3. Configure:
   - **Name:** `Inbox-AppsScript` (or similar)
   - **Client ID:** from the GCP project in Step 1 (where you enabled Apps Script API)
   - **Client Secret:** from the same GCP project
   - **Scope(s):** paste all 3 scopes (space-separated):
     ```
     https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/script.scriptapp
     ```

     > **Note:** The third scope (`script.scriptapp`) is required for trigger setup and testing from the Apps Script editor, not just for n8n API calls.
4. Click **Save**
5. Click **Connect** to complete OAuth flow
6. Grant all requested permissions (safe - it's your own script)
7. In the **Write via Apps Script** HTTP node (if you haven't already):
   - Paste the URL from Step 4
   - Under Credential, select the credential you just created
8. Click **Publish** to save

**Almost done!** Return to [email-crm-guide.md → 6. Enable CRM Nodes](email-crm-guide.md#6-enable-crm-nodes) to finish setup.

---

## Troubleshooting

### 404 "Requested resource/entity was not found"

- **Most common:** You're using Script ID instead of Deployment ID
- **Fix:** Get the Deployment ID from Deploy > Manage deployments (starts with `AKfycb...`)

### Permission Errors

- Re-run `testWriteContactData` in Apps Script editor
- Complete the authorization flow again
- Verify all 3 scopes in `appsscript.json`

### GCP Project Mismatch

- Apps Script must be linked to the **same** GCP project as your OAuth credentials
- Verify Project Number (not ID) matches in both places

---

## Key Points Summary

1. Use **Deployment ID** (AKfycb...), NOT Script ID
2. **3 OAuth scopes** required in BOTH `appsscript.json` and n8n credential:
   - `spreadsheets` - read/write sheet data
   - `drive` - create folders
   - `script.scriptapp` - trigger setup & testing from editor
3. Apps Script linked to **same GCP project** as n8n OAuth
4. **Enable Apps Script API** in GCP Console
5. **Authorize locally first** (run test function) before n8n calls

## Dataset Size Warning

The Apps Script loads the entire sheet into memory to find rows:
- Works well for sheets < 5,000 rows
- May timeout or fail on very large sheets (10,000+ rows)
- Apps Script has 6-minute execution limit and ~6MB heap
