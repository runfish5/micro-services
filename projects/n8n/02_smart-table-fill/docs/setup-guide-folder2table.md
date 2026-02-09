## Setup Guide — Folder-to-Table Extraction

**Time:** ~10 min | **Difficulty:** Easy | **Cost:** Free

Point at a Google Drive folder, get one structured row per file in your Google Sheet.

> **Prerequisite:** The [any-file2json-converter](../../03_any-file2json-converter) sub-workflow must be imported and published in your n8n instance.

---

### Step 1: Create Your Google Sheet

1. Create a new spreadsheet at [sheets.google.com](https://sheets.google.com)
2. Add column headers to **row 1** describing the data you want to extract:

| Date | Amount | Vendor | Category | Notes |
|------|--------|--------|----------|-------|

Leave every other row empty — the workflow fills them.

---

### Step 2: Import the Workflow

1. Download [`smart-folder2table.json`](../workflows/smart-folder2table.json)
2. In n8n: **Workflows → Import from File** → select the JSON
3. **Save**, then **Publish**

---

### Step 3: Connect Credentials

- **Google Drive (OAuth2)** — for reading folder contents and downloading files
- **Google Sheets (OAuth2)** — for reading headers and writing rows
- **LLM API key** — add in the **Schema LLM** node (free tier is fine)

Assign each credential to its matching nodes. (n8n highlights missing credentials in red.)

See [credentials-guide.md](../credentials-guide.md) for details.

---

### Step 4: Configure

Open the **Config** node and set:

| Field | Where to find it |
|-------|-----------------|
| `folder_id` | Google Drive URL: `drive.google.com/drive/folders/`**`THIS_PART`** |
| `spreadsheet_id` | Sheets URL: `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit` |

All other Config fields have working defaults.

---

### Step 5: Run

Click **Test Workflow**. On first run the workflow auto-creates a schema sheet from your column headers, then processes each file in the folder.

Check your Google Sheet — one new row per file, with extracted data matching your columns.

> **Resumable:** Re-running skips already-processed files. If you hit rate limits, increase `rate_limit_wait_seconds` in Config and restart.
