# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

n8n workflow that extracts structured data from unstructured text using LLM and dynamically-generated schema from Google Sheets headers. Key feature: **auto-creates schema sheet on first run** using LLM to infer types, descriptions, and enum values from column names.

## How It Works

1. Reads column headers from user's data sheet (e.g., "Entries")
2. Checks if schema sheet (`Description_hig7f6`) exists
3. If not: creates it via Sheets API, uses LLM to generate Type/Description/Classes for each column
4. Generates JSON schema dynamically from schema sheet
5. Uses LLM (Groq) to extract structured data from raw text input
6. Updates matching row in data sheet with extracted fields

## Where Information Lives

### Workflows
- `workflows/smart-table-fill.n8n.json` - Main workflow (21 nodes)
- `workflows/subworkflows/record-search.json` - Contact lookup subworkflow

### Documentation
- `workflows/mainflow.md` - Complete node breakdown, data flow diagrams
- `docs/setup-guide.md` - Setup instructions

### Scripts
- `scripts/AppScript-new-contact-setup.js` - Google Apps Script for contact folder management:
  - **onEdit trigger**: Auto-creates folders when user manually edits email column in Sheets UI
  - **writeContactData(data)**: Called via Execution API from n8n (writes data + creates folders)
  - **Deploy as API Executable**: Apps Script editor → Deploy → New deployment → API Executable

## Key Configuration (String Input Node)

| Field | Purpose |
|-------|---------|
| `spreadsheet_id` | Google Sheets document ID |
| `data_sheet_name` | Your data sheet (e.g., "Entries") |
| `schema_sheet_name` | Schema definition sheet (`Description_hig7f6`) |
| `body_core` | LLM-distilled core message (semantic extraction from email) |
| `match_column` / `match_value` | Which row to update |
| `batch_size` | Fields per LLM batch |
| `extract_depth` | Extraction depth 1-3 from classifier (default 3 = all fields) |

## Schema Sheet Structure

The `Description_hig7f6` sheet is auto-generated with columns:
- `ColumnName` - Exact column name from data sheet
- `Type` - One of: `str`, `int`, `date`, `list`, `class`
- `Description` - Brief field description
- `Classes` - Comma-separated enum values (only for `class` type)

LLM infers initial values; users can refine them. Field filtering by extraction depth is handled via a hardcoded `DEPTH_MAP` in the Build Output Schema node (not in the schema sheet).

## Contact Management Extension

### RecordSearch Subworkflow (4_CM:RecordSearch)

Located at `workflows/subworkflows/record-search.json`, this subworkflow provides tiered contact lookup:

**Matching Order:**
1. **email** - Fast exact match on primary email column
2. **more_emails** - Fallback search in comma-separated additional emails
3. **name_fuzzy** - Normalized first_name + surname matching with partial match fallback
4. **none** - No match found → smart-table-fill creates new entry

**Required Sheet Columns:**
| Column | Type | Purpose |
|--------|------|---------|
| `email` | string | Primary identifier (matching key) |
| `more_emails` | string | Comma-separated additional emails |
| `first_name` | string | First name for fuzzy matching |
| `surname` | string | Last name for fuzzy matching |

**Output:**
```json
{ "found": true, "matchType": "email", "contact": {...} }
// or
{ "found": false, "matchType": "none" }
```

### Integration Flow

When called from inbox-attachment-organizer:
```
ContactManager-lineage (Switch)
    ↓
Call RecordSearch (lookup contact)
    ↓
Prepare Contact Input (set node)
    ↓
Call smart-table-fill
  → writes data to sheet via Apps Script Execution API
  → creates folders if needed (folder_id, emails_folder_id)
  → returns row_number + folder IDs
```

### Apps Script Integration

The `scripts/AppScript-new-contact-setup.js` provides two entry points:

**1. onEdit trigger (manual entries):**
- Fires when user manually edits email column in Sheets UI
- Creates: contact folder, README.md, emails/ subfolder
- Stores BOTH `folder_id` AND `emails_folder_id` in sheet columns

**2. writeContactData (n8n API entries via Execution API):**
- Called via `https://script.googleapis.com/v1/scripts/{DEPLOYMENT_ID}:run`
- Uses n8n's Google OAuth2 API credential (secure, no public endpoint)
- Writes all extracted fields to sheet AND creates folders
- Returns: `{ status, row_number, folder_id, emails_folder_id }`

**Required Sheet Columns:**
- `folder_id` - Contact folder ID
- `emails_folder_id` - Emails subfolder ID

**Required Files:**
- `scripts/appsscript.json` - Manifest with OAuth scopes (copy to Apps Script project)

**Key Points:**
1. Use **Deployment ID** (starts with `AKfycb...`), NOT Script ID
2. **3 OAuth scopes** required in both `appsscript.json` AND n8n credential:
   - `https://www.googleapis.com/auth/spreadsheets` - read/write sheet data
   - `https://www.googleapis.com/auth/drive` - create folders
   - `https://www.googleapis.com/auth/script.scriptapp` - trigger setup & testing from editor
3. Apps Script must be linked to **same GCP project** as n8n OAuth credentials
4. Must **authorize locally first** (run test function in Apps Script) before n8n calls
5. **Dataset limit:** Works well < 5,000 rows; may timeout on very large sheets

**Full Setup Guide:** See [docs/apps-script-execution-api-setup.md](docs/apps-script-execution-api-setup.md)
