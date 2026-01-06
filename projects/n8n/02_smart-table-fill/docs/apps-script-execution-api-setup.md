# Apps Script Execution API Setup

**Time:** 20 min | **Difficulty:** Intermediate | **Cost:** Free

This guide configures n8n to call Google Apps Script via the Execution API with OAuth authentication. No public endpoints, no tokens - secure OAuth only.

---

## Prerequisites

- Google Cloud Console access
- n8n instance (self-hosted or cloud)
- Google Sheet with your data (e.g., "Entries" sheet)
- 03_inbox-attachment-organizer workflow with smart-table-fill subworkflow (activate the HTTP node instead of Excel)

---

## Step 1: Find Your GCP Project Number & Enable API

Your existing n8n Google credentials use a GCP project. We need to link Apps Script to the **same project**.

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
2. Copy the entire contents of `scripts/AppScript-new-contact-setup.js` from this repo
3. Paste into `Code.gs`
4. Update `CONFIG` with your settings:
   - `spreadsheetId`: your Google Sheet ID
   - `folderPath`: array of folder names where contact folders are created (e.g., `['MyDrive', 'ContactManager', 'names_folders']`)

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
    "https://www.googleapis.com/auth/script.external_request",
    "https://www.googleapis.com/auth/script.scriptapp"
  ]
}
```

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
3. **Copy this entire URL** - paste it directly into your n8n HTTP node

Just copy this full URL and paste it into your n8n HTTP node. (Note: Google's docs mention using Script ID, but the Deployment ID `AKfycb...` in this URL is what actually works.)

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

**Note:** If you see permission errors, ensure `appsscript.json` has all 4 scopes.

---

## Step 6: Create n8n OAuth Credential

1. In n8n: **Settings** > **Credentials** > **Add Credential**
2. Search for: **Google OAuth2 API**
3. Configure:
   - **Name:** `Inbox-AppsScript` (or similar)
   - **Client ID:** from the GCP project in Step 1 (where you enabled Apps Script API)
   - **Client Secret:** from the same GCP project
   - **Scope(s):** paste all 4 scopes (space-separated):
     ```
     https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/script.external_request https://www.googleapis.com/auth/script.scriptapp
     ```
4. Click **Save**
5. Click **Connect** to complete OAuth flow
6. Grant all requested permissions (safe - it's your own script)

---

## Step 7: Import & Configure Workflow

1. Import `workflows/smart-table-fill.n8n.json` into n8n
2. Click **Publish** to save
3. Edit the **String Input** node: set `SpreadsheetId` to your Google Sheet ID
4. Edit the **Write via Apps Script** HTTP node:
   - Paste the URL from Step 4
   - Under Credential, select your credential from Step 6

---

## Troubleshooting

### 404 "Requested resource/entity was not found"

- **Most common:** You're using Script ID instead of Deployment ID
- **Fix:** Get the Deployment ID from Deploy > Manage deployments (starts with `AKfycb...`)

### Permission Errors

- Re-run `testWriteContactData` in Apps Script editor
- Complete the authorization flow again
- Verify all 4 scopes in `appsscript.json`

### GCP Project Mismatch

- Apps Script must be linked to the **same** GCP project as your OAuth credentials
- Verify Project Number (not ID) matches in both places

---

## Key Points Summary

1. Use **Deployment ID** (AKfycb...), NOT Script ID
2. All **4 scopes required** in BOTH:
   - `appsscript.json` manifest
   - n8n Google OAuth2 API credential
3. Apps Script linked to **same GCP project** as n8n OAuth
4. **Enable Apps Script API** in GCP Console
5. **Authorize locally first** (run test function) before n8n calls
