## Setup Guide — Folder-to-Table Extraction

**Time:** ~10 min | **Difficulty:** Easy | **Cost:** Free

Point at a Google Drive folder, get one structured row per file in your Google Sheet.

> **Prerequisite:** The [any-file2json-converter](../../03_any-file2json-converter) sub-workflow must be imported and published in your n8n instance. Update it first when you update both: this workflow reads the converter's `status: "unsupported"`, which converter versions before 2026-10 called `unresolved` (an unsupported file would then be written as `ok: text only`).

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
3. Open **Convert File to Text** and select **your** imported `any-file2json-converter` in the workflow picker (the id in the file belongs to another instance). If the `extraction` input is blank afterwards, paste it back from the blue sticky behind the node.
4. **Save**, then **Publish**

---

### Step 3: Connect Credentials

- **Google Drive (OAuth2)** — for reading folder contents and downloading files
- **Google Sheets (OAuth2)** — for reading headers and writing rows
- **LLM API key** — add in the **Schema LLM** node (free tier is fine)

Assign each credential to its matching nodes. (n8n highlights missing credentials in red.)

See [credentials-guide.md](../../credentials-guide.md) for details.

---

### Step 4: Configure

Open the **Config** node and set:

| Field | Where to find it |
|-------|-----------------|
| `folder_id` | Google Drive URL: `drive.google.com/drive/folders/`**`THIS_PART`** |
| `spreadsheet_id` | Sheets URL: `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit` |
| `data_sheet_name` | The tab name at the bottom of your sheet. Default `Sheet1`; a German Google account names it `Tabelle1` |

All other Config fields have working defaults.

> **Wrong tab name?** The run fails at **Ensure Headers** with `Unable to parse range: Sheet1!A1`, after it has already created an empty `Description_hig7f6` tab. Delete that tab, fix `data_sheet_name`, and re-run.

---

### Step 5: Run

Click **Test Workflow**. On first run the workflow auto-creates a schema sheet from your column headers, then processes each file in the folder.

Check your Google Sheet — one new row per file, with extracted data matching your columns. The workflow adds three helper columns if they are missing: `source_file`, `Text_to_interpret` (the converter's raw output) and `extraction_status`.

### When a file fails

One bad file does not stop the other files. It still gets a row, with `source_file` filled, your columns left empty, and `extraction_status` saying what happened:

| `extraction_status` | Meaning |
|---|---|
| `ok` | Fields extracted into your columns |
| `ok: text only, no fields parsed` | The converter returned text but not JSON; see `Text_to_interpret` |
| `failed: download - …` | Google Drive refused the file (after 3 tries) |
| `failed: converter - …` | The converter failed on this file (e.g. a corrupt PDF), or could not be called at all (not published, not selected). n8n's own error message follows; the converter's execution shows which node failed |
| `skipped: unsupported file type (mime)` | The converter has no route for this file type. Not retried: a retry cannot change the type |

**After the last file, the run fails if any file failed**, with a list like
`2 of 12 files failed. Rerun to retry only those. scan.pdf: failed: converter - …`.
That is deliberate: a run that ends green is never seen by an error workflow. Set
`fail_run_on_file_errors` to `false` in **Config** if you would rather it finish green.
Retrying that failed execution from n8n's execution list re-runs only the final check, so start a
fresh run instead.

> **Resumable:** Re-running skips files whose row does not start with `failed`. A `failed` file is tried again and its row is updated in place, so it never appears twice.
> If writing to the sheet itself fails (quota, permissions), the run retries 3 times and then stops. Every file written so far is kept; fix the cause and re-run.
> If you hit LLM rate limits, increase `rate_limit_wait_seconds` in Config and restart.
