# Main Flow (20 Nodes)

> Last verified: 2025-01-18

## Overview
Extracts structured data from unstructured text into Google Sheets using dynamic schema with auto-creation on first run. Uses Apps Script to write data AND create contact folders in a single HTTP call.

## Flow Summary

### Phases
```
Triggers (Nodes 1-2)
Schema Check & Creation (Nodes 3-10)
  - Fetch data headers → Check schema exists → Create if needed
Data Extraction (Nodes 11-14)
  - Build JSON schema → Extract Data from String (one LLM call per batch) → Merge outputs → Write
```

### Data Flow
```
Trigger → String Input (config)
              ↓
    Fetch Data Sheet Headers
              ↓
    Try Fetch Schema Sheet
              ↓
         Schema Exists?
         ├─ YES ────────────────────────┐
         └─ NO                          │
              ↓                         │
         Generate Schema with LLM           │
              ↓                         │
         Create and Write Schema Sheet ─────────┘
                                        ↓
                              Build Output Schema
                              (sources data from upstream)
                                        ↓
                              Extract Data from String
                              (one LLM call per schema batch, no pause)
                                        ↓
                              Merge Outputs
                                        ↓
                    ┌─────────────────────────────────────────┐
                    │ Standalone: Write Extracted Row (native Sheets) │
                    └─────────────────────────────────────────┘
                                        │
                                        │ (or CRM mode)
                                        ↓
                              CRM Write via Apps Script (HTTP POST)
                                        ↓
                              CRM Prep Email Store Input
                                        ↓
                              CRM Call Contact Memory Update
```

### Lineage Tree
```
START: Manual Trigger → Get Rows in Sheet / When Executed by Another Workflow
  │
  └→ String Input (config: spreadsheet_id, data_sheet_name, schema_sheet_name,
  │                body_core, contact_name, contact_email, subject,
  │                match_column, match_value, batch_size, extract_depth)
       │
       └→ Fetch Data Sheet Headers (row 1 of data sheet)
            │
            └→ Try Fetch Schema Sheet (Description_hig7f6)
                 │
                 └→ If Schema Exists
                      │
                      ├─ TRUE:
                      │  └→ Build Output Schema (uses Try Fetch Schema Sheet data)
                      │
                      └─ FALSE:
                         ├→ Generate Schema with LLM
                         │     ├─ Schema LLM (Groq)
                         │     └─ Schema Output Parser
                         └→ Create and Write Schema Sheet (Sheets batchUpdate API)
                              └→ Build Output Schema (uses Generate Schema with LLM data)
                          │
                          └→ Extract Data from String (LLM chain, one call per batch)
                          │     ├─ LLM Processor
                          │     └─ Dynamic Output Parser
                          │     - No rate limiting here. After a 429 the error handler's
                          │       recovery path takes over (see llm-extract-rate-limited below)
                          │
                          └→ Merge Outputs
                               │
                               ├→ Write Extracted Row (disabled, standalone mode)
                               │
                               └→ CRM Write via Apps Script (HTTP POST to doPost)
                                    │  - Writes all extracted fields to sheet
                                    │  - Creates folder + emails/ subfolder if needed
                                    │  - Returns folder_id, emails_folder_id
                                    │
                                    └→ CRM Prep Email Store Input
                                         │
                                         └→ CRM Call Contact Memory Update
```

## AI Model Nodes

### 1. Schema Generation (first run only)
- **Node**: Generate Schema with LLM
- **Model**: Groq LLM (configurable)
- **Input**: Column names from data sheet
- **Output**: JSON array with ColumnName, Type, Description, Classes
- **Purpose**: Intelligently infer schema from column names

### 2. Data Extraction
- **Node**: Extract Data from String (LLM Processor + Dynamic Output Parser)
- **Model**: LLM (configurable)
- **Input**: Raw text + dynamic JSON schema, one call per schema batch
- **Output**: Structured data matching schema + confidence scores
- **Purpose**: Extract values from unstructured text. Rate limits are handled after the fact by the
  error handler, not here (see llm-extract-rate-limited)

## Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Manual Trigger | trigger | Manual execution |
| 2 | Get Rows in Sheet | googleSheets | Manual runs: reads the data tab. **The one place the importer picks spreadsheet + tab**; String Input reads both via `$('Get Rows in Sheet').params` |
| 3 | When Executed by Another Workflow | trigger | Subworkflow entry (passthrough) |
| 4 | String Input | set | Configuration variables; caller values win, else Get Rows in Sheet params, else defaults |
| 5 | Fetch Data Sheet Headers | httpRequest | Get column names from data sheet |
| 6 | Try Fetch Schema Sheet | googleSheets | Check if schema sheet exists (`onError: continueRegularOutput`) |
| 7 | If Schema Exists | if | Branch on schema existence |
| 8 | Generate Schema with LLM | chainLlm | Generate schema definitions |
| 9 | Schema LLM | lmChat | Language model for schema |
| 10 | Schema Output Parser | outputParser | Parse schema JSON |
| 11 | Create and Write Schema Sheet | httpRequest | Create sheet + write schema via batchUpdate |
| 12 | Build Output Schema | code | Build JSON schema with depth-based field filtering via DEPTH_MAP; at most `batch_size` fields per LLM call, split evenly; the match column, the text column and every `known_values` key are never sent to the LLM; row_id from match_column → match_value → email; `row_key` groups one row's batches. A row with nothing left to extract (or empty text) becomes one `direct` item |
| 12b | If LLM Needed | if | `direct` items skip the LLM and go straight to Merge Outputs |
| 13 | Extract Data from String | chainLlm | LLM extraction, one item per row × column batch. `retryOnFail` (2 tries), then `onError: continueRegularOutput` so a failed batch becomes `{ error }` at the same index |
| 14 | LLM Processor | lmChat | Extraction model |
| 15 | Dynamic Output Parser | outputParser | Schema from `$json.schema`, autoFix on |
| 16 | Merge Outputs | code | Merge batch outputs per `row_key`; failed batches → `extraction_error`; `known_values` win over LLM values; empty values are dropped |
| 17 | Write Extracted Row | googleSheets | Mode A write (active) |
| 18 | CRM Write via Apps Script | httpRequest | Mode B: write data + create folder via doPost (**disabled**; URL placeholder `YOUR_APPS_SCRIPT_ID`) |
| 19 | CRM Prep Email Store Input | set | Mode B: prepare data for contact-memory-update (**disabled**) |
| 20 | CRM Call Contact Memory Update | executeWorkflow | Mode B: store email metadata in contact memory (**disabled**; workflow id placeholder `YOUR_CONTACT_MEMORY_UPDATE_WORKFLOW_ID`) |

**Per-row failures.** A row whose extraction fails is still written: the error text goes to `extraction_error` (written only if the sheet has that column; cleared on success). The run continues with the other rows. A disabled Mode B branch passes data through its disabled nodes and ends, so it does not affect Mode A.

## Notes
- Schema sheet name `Description_hig7f6` has suffix for disambiguation
- First run creates schema; subsequent runs skip creation
- Edit schema sheet to customize extraction (types, descriptions, enum values)
- `batch_size` = data fields per LLM call (default 10). 13 fields at 10 become 7 + 6, not 10 + 3
- **Every call repeats the prompt and the whole text.** Batches are sent at the same time, so the number of calls, not the field count, is what hits a tokens-per-minute limit. Keep calls few
- **Rate limiting** is not done in this flow. See llm-extract-rate-limited below
- **Apps Script handles both writing and folder creation** - no triggers needed (CRM mode)

### Update-or-Append Logic (Merge Outputs + Write Extracted Row)

The Merge Outputs node prepares clean data for Write Extracted Row:

1. **Dynamic match column**: Sets `merged[matchColumn]` from the `match_column` config
2. **Write Extracted Row compatibility**: Always copies match value to `merged.email` (Write Extracted Row hardcoded to match on "email" column)
3. **Overwrite prevention**: Only sets `merged[textColumn]` if `textColumn !== matchColumn` to prevent the text body from overwriting the match value
4. **Clean output**: The LLM reports only `confidence.overall`; it is logged in the execution but deleted from `merged` before output. Internal fields (`_row_id`, `_meta`, `_match_same_row`, `_row_number`) are explicitly deleted before Write Extracted Row.

5. **Empty never erases**: an empty value (`""`, `[]`, `null`) means *not in this text*, so it is dropped and the cell keeps its value. Both writers (Write Extracted Row and the Apps Script) write empty strings, so before this every blank LLM answer wiped a filled cell.

6. **Class fields may be empty**: every enum also allows `""`. Without it the schema rejects an honest *not stated*, the chain retries, and the retry picks an option at random. Seen on 2026-10-01: first answer `status: ""`, rejected, second answer a guessed `Time to reach out`.

7. **Known values win**: `known_values` from the caller are applied after the LLM output. A known value of `null` means *leave this column alone*: it is neither extracted nor written.

8. **Append instead of match**: Deletes `email` when `match_same_row` is false or the email is empty. Write Extracted Row appends any item without the key; an empty string would match, and overwrite, the first row with a blank email.

Write Extracted Row always uses `appendOrUpdate` on `email`. The operation is fixed, not an expression: the editor drops an expression-driven operation's sheet and columns on import (see [troubleshooting](../troubleshooting.md#could-not-get-parameter-after-import-google-sheets)). The `handlingExtraData: "ignoreIt"` option silently drops any fields that don't have matching column headers in the sheet.

### Caller-Overridable Config (String Input)

When called as a subworkflow, callers can override these fields (defaults apply if not provided):

| Field | Default | Purpose |
|-------|---------|---------|
| `spreadsheet_id` | *(caller must provide)* | Google Sheets document ID |
| `data_sheet_name` | `Sheet1` | Sheet tab name |
| `schema_sheet_name` | `Description_hig7f6` | Schema definition sheet |
| `batch_size` | `10` | Data fields per LLM call |
| `known_values` | `{}` | Facts the caller already has, e.g. `{ last_topic: subject, last_contacted: date }`. Written as given, never sent to the LLM; `null` = leave that column alone. Object or JSON string |
| `match_column` | `email` | Which column to match on |
| `match_value` | `$json[$json.match_column]` | Value to match; auto-resolved from `match_column` field name |
| `match_same_row` | `true` | `false` = append-only mode |
| `extract_depth` | `3` | Extraction depth 1-3 from classifier (default 3 = all fields) |

### Depth-Based Field Filtering (Build Output Schema)

Build Output Schema uses a hardcoded `DEPTH_MAP` to filter fields by the upstream classifier's `extract_depth` value:

| Depth | Fields | LLM calls (batch_size=10, organizer's known_values) |
|-------|--------|----------------------|
| 1 (shallow) | email, last_topic, last_being_contacted, last_contacted | 0: all known or the match value |
| 2 (medium) | depth 1 + first_name, surname, more_emails, status, association, groups, goal_contact_frequency, current_job, works_at | 1 (9 fields) |
| 3 (deep) | all fields (~18) | 2 |

Depth 1 is automated mail (notifications, receipts, alerts): by the classifier's own definition it holds no personal details, so names moved to depth 2. Before, depth 1 cost 2 calls that returned only the subject and email the caller already had. Fields not in DEPTH_MAP default to depth 3.

---

## Subworkflows

### llm-extract-rate-limited (building block, spec, not built yet)

A paced version of **Extract Data from String**: `llm_rate_limit` calls, then a pause of
`llm_rate_delay` seconds, repeated. Two uses:

1. **Standalone and tutorial copies, on by default.** Someone who downloads smart-table-fill on a
   free LLM tier has no error handler behind it. For them the slow, safe path is the right default.
   That clutter is unavoidable there, and it belongs in the repo.
2. **Recovery on a full lab.** Here the normal path stays fast, and the error handler reaches for
   this block only after a rate-limit failure was logged.

On this instance it is not needed in the normal path. If a copy exists there, it stays deactivated.

**Status:** documented in January (commit 323e778), but the JSON was never committed and is not on
the instance. The pacing that does exist is smart-folder2table's `rate_limit_wait_seconds`, driven by
the error handler's auto-retry registry.

**File (planned):** `workflows/subworkflows/llm-extract-rate-limited.json`.

#### Where it sits

```
smart-table-fill (fast: all batches at once)
       ↓ rate_limit error (429)
010-error-handler → Prepare & Classify Error (error_type = rate_limit)
       ↓ workflow in AUTO_RETRY_REGISTRY
Wait (retry_after_seconds from the error, default 60s)
       ↓
llm-extract-rate-limited (slow: llm_rate_limit calls, then wait llm_rate_delay, repeat)
```

Same pattern as the existing smart-folder2table entry in the registry ("start fast, adapt on error",
see `10_error-handler/workflows/mainflow.md` § Auto-Retry Registry). The normal path stays fast;
only a failed run pays for the waiting.

#### Planned flow

```
When Executed by Another Workflow
  ↓
Set Config (capture rate limit params)
  ↓
Prepare Schemas (one item per schema batch)
  ↓
Loop Over Batches (llm_rate_limit per round)
  ↓
Extract Data from String (LLM chain + Dynamic Output Parser)
  ↓
Wait (llm_rate_delay seconds) → back to Loop Over Batches
```

#### Planned inputs

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| schemas | array | - | JSON schema objects from Build Output Schema |
| body_core | string | - | Text to extract data from |
| contact_name | string | '' | Contact context for extraction |
| contact_email | string | '' | Contact context for extraction |
| subject | string | '' | Email subject context |
| llm_rate_limit | number | 5 | Calls per round before pausing |
| llm_rate_delay | number | 60 | Seconds to wait between rounds |

#### Open before building

- The inbox organizer needs **API retry** to keep its Gmail trigger data, so a re-run cannot start
  at smart-table-fill alone. The handler has to know which caller to resume.
- First lower what one email costs (fewer batches, shorter prompt). A recovery path that runs often
  is a sign the normal path is too expensive.

---

### RecordSearch (4_CM:RecordSearch)

**File:** `workflows/subworkflows/record-search.json`

**Purpose:** Tiered contact lookup before calling smart-table-fill, used by inbox-attachment-organizer.

#### Flow
```
When Executed by Another Workflow
  ↓
Set Search Input (email, first_name, surname)
  ↓
Read All Contacts (Google Sheets)
  ↓
Tiered Contact Search (Code node)
  ↓
Return: { found, matchType, contact }
```

#### Tiered Matching Logic
```
Step 1: email column (exact match)
  ↓
Step 2: more_emails column (contains search)
  ↓
Step 3: first_name + surname (fuzzy normalized match)
  ↓
Step 4: return found: false
```

#### Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | When Executed by Another Workflow | trigger | Subworkflow entry |
| 2 | Manual Trigger | trigger | Testing entry |
| 3 | Set Search Input | set | Capture search params |
| 4 | Read All Contacts | googleSheets | Fetch all contact rows |
| 5 | Tiered Contact Search | code | Matching logic |

#### Integration Point
Called by inbox-attachment-organizer's `ContactManager-lineage` switch node:
```
ContactManager-lineage → RecordSearch → Prepare Contact Input → smart-table-fill
```

---

### smart-folder2table

**File:** `workflows/smart-folder2table.json`

**Purpose:** Process all files in a Google Drive folder through any-file2json-converter and write directly to sheet, with skip-on-retry resumability.

#### Architecture (v2)
```
[smart-folder2table v2]
        |
        |-- calls --> any-file2json-converter  (existing subworkflow)
        |-- writes directly to sheet           (no smart-table-fill call!)
```

**Key change from v1:** Eliminated the smart-table-fill call. The any-file2json-converter already extracts data with the schema - calling smart-table-fill was redundant (it would re-read headers, re-check schema, and do ANOTHER LLM extraction).

#### Flow
```
Manual Trigger ──────┬──→ Config (Set node with fallbacks)
                     │
When Executed ───────┘   (receives config + rate_limit_wait_seconds from error handler)
     ↓
Fetch Data and Schema Sheets (HTTP GET: spreadsheets.get with includeGridData - gracefully handles missing sheets)
     ↓
If Schema Exists (inline check on raw response for schema sheet with data rows)
     ├─ TRUE → Ensure Headers
     └─ FALSE → Generate Schema with LLM → Create and Write Schema Sheet → Ensure Headers
     ↓
Ensure Headers (HTTP POST: add source_file/Text_to_interpret/extraction_status if missing)
     ↓
List Drive Files (Google Drive: list files in folder)
     ↓
Build Output Schema and Filter (Code: build extraction object + filter already-processed)
     ↓
Loop Over Files (1 at a time)
     ↓
Download File (Google Drive: download binary per item; 3 tries, error output → Prepare Write Data)
     ↓
Expand Batches (Code: split wide schemas into batch_size chunks)
     ↓
Convert File to Text (Execute Workflow: any-file2json-converter with extraction hints; errors continue)
     ↓
Rate Limit Wait (dynamic: from Config, default 0s)
     ↓
Prepare Write Data (Code: parse converter JSON output, or build a failed row with extraction_status)
     ↓
Write Extracted Row (Google Sheets: append or update on source_file)
     ↓
(loop back)
```

#### Config Parameters

| Field | Default | Purpose |
|-------|---------|---------|
| `folder_id` | *(user fills)* | Google Drive folder to process |
| `spreadsheet_id` | *(user fills)* | Target Google Sheet |
| `data_sheet_name` | `Sheet1` | Sheet tab name |
| `source_file_column` | `source_file` | Column to check for already-processed filenames |
| `file_include` | `all` | `"all"` = process every file; or comma-separated filenames to process only those |
| `file_exclude` | *(empty)* | Comma-separated filenames to skip (applied after include filter) |
| `file_limit` | `null` | `null` = no limit; set to a number (e.g. `5`) to cap files processed |
| `match_column` | `source_file` | For extraction row grouping |
| `batch_size` | `7` | Fields per LLM extraction call |
| `schema_sheet_name` | `Description_hig7f6` | Schema sheet (auto-created on first run) |
| `rate_limit_wait_seconds` | `0` | Delay between files (passed by error handler on retry) |

#### Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Manual Trigger | trigger | Manual execution |
| 2 | When Executed by Another Workflow | trigger | Receives config + rate_limit_wait_seconds from error handler |
| 3 | Config | set | Configuration with fallbacks (reads from workflow input or defaults) |
| 4 | Fetch Data and Schema Sheets | httpRequest | Read all sheets via spreadsheets.get (gracefully handles missing schema sheet) |
| 5 | If Schema Exists | if | Inline check on raw response for schema sheet with data rows |
| 6 | Generate Schema with LLM | chainLlm | Generate schema definitions from column headers |
| 7 | Schema LLM | lmChatGroq | Language model for schema generation |
| 8 | Schema Output Parser | outputParser | Parse schema JSON array |
| 9 | Create and Write Schema Sheet | httpRequest | Create sheet + write schema via batchUpdate |
| 10 | Ensure Headers | httpRequest | Add missing `source_file`/`Text_to_interpret` headers; extracts header row inline from raw response; uses `colLetter()` helper to support columns past Z (AA, AB, …) |
| 11 | List Drive Files | googleDrive | List all files in target folder |
| 12 | Build Output Schema and Filter | code | Parse raw sheet data, build extraction object, skip already-processed files |
| 13 | Loop Over Files | splitInBatches | Process one file at a time |
| 14 | Download File | googleDrive | Download file binary data |
| 15 | Convert File to Text | executeWorkflow | Calls any-file2json-converter with extraction hints |
| 16 | Rate Limit Wait | wait | Dynamic delay from Config (default 0s) |
| 17 | Prepare Write Data | code | Parse converter JSON output for sheet write |
| 18 | Write Extracted Row | googleSheets | Append or update on `source_file`. The operation is fixed, not an expression: the editor drops an expression-driven operation's sheet and columns on import |

#### Dynamic Rate Limiting (Start Fast, Adapt on Error)

The workflow uses an adaptive rate limiting pattern via Execute Workflow parameters (no sheet storage):

**Two entry points:**
- **Manual Trigger**: Uses Config defaults (`rate_limit_wait_seconds = 0`, no delay)
- **When Executed by Another Workflow**: Receives config + `rate_limit_wait_seconds` from error handler

**Pattern:**
```
smart-folder2table runs fast (0s wait)
       ↓
Rate Limit Error (429) on file #6
       ↓
Error Handler catches it
       ↓
Extract "retry in 55s" from error message
       ↓
Extract Config values from execution.runData['Config']
       ↓
Call smart-folder2table via Execute Workflow
  with: original Config + rate_limit_wait_seconds = 55
       ↓
smart-folder2table starts fresh
       ↓
Files 1-5 already in sheet → skipped (resumability check)
       ↓
File #6 onwards with 55s waits
```

**Benefits:**
- Starts fast when rate limits aren't an issue
- Automatically learns the correct delay from API errors
- No external sheet storage needed - timing passed as parameter
- Resumability ensures already-processed files are skipped

**Usage:**
- **Manual mode**: If you hit rate limits, increase `rate_limit_wait_seconds` in Config (try 60s, or more if needed). Restart the workflow - resumability skips already-processed files.
- **Production mode**: When published and called via subworkflow trigger, the 010-error-handler handles it automatically - extracts retry timing from 429 errors and restarts with the correct delay.

#### Resumability (Skip-on-Retry)

1. Each file gets exactly one row: `source_file` = filename, `Text_to_interpret` = converter output, `extraction_status` = `ok` / `ok: text only, no fields parsed` / `failed: <stage> - <detail>`. A failed download or conversion writes a failed row (user columns left empty) and the loop continues
2. On retry, `Fetch Data and Schema Sheets` reads both schema and data sheets in one call
3. `Build Output Schema and Filter` checks the `source_file` column to get processed filenames
4. Rows whose `extraction_status` starts with `failed` do not count as done: the file is retried, and Write Extracted Row (always append-or-update on `source_file`) overwrites the failed row instead of duplicating it
5. A sheet-write failure retries 3× then stops the run (systemic, not per-file); re-running resumes

The `source_file` column is auto-created by the Ensure Headers logic. `Text_to_interpret` contains the raw converter output (JSON string with extracted fields).

#### Schema-Aware Extraction

The Build Output Schema and Filter node reads the schema (from sheet or freshly-generated LLM output) and constructs an extraction object that hints the any-file2json-converter about priority fields. The converter uses this to dynamically build a JSON Schema that **enforces** user columns as required fields.

**Extraction object format:**
```json
{
  "type": "document_analysis",
  "focus_fields": ["color tone", "object", "emotional mood"],
  "field_schemas": [
    {"name": "color tone", "type": "str", "description": "Dominant color palette", "classes": ""},
    {"name": "object", "type": "str", "description": "Main visible object", "classes": ""},
    {"name": "emotional mood", "type": "class", "description": "Overall feeling", "classes": "calm,neutral,excited"}
  ],
  "instructions": "Extract ALL visible information... PRIORITIZE these fields:\n- color tone: Dominant color palette\n- object: Main visible object\n- emotional mood (enum: calm,neutral,excited): Overall feeling"
}
```

**Data flow (v2):**
```
smart-folder2table v2                 any-file2json-converter
───────────────────                 ───────────────────────
Build Output Schema and Filter
  ↓ extraction: {
      focus_fields: [...],
      field_schemas: [...]
    }
────────────────────────────────────→ Set Default Extraction
                                      ↓
                                    Split Files and Build Schema (Code node)
                                      ↓ builds JSON Schema from field_schemas
                                    Image Output Parser
                                      ↓ uses dynamic schema expression
                                    Image-to-Text LLM
                                      ↓ enforced schema!
────────────────────────────────────← returns data.text (JSON string)
Prepare Write Data
  ↓ parses JSON, merges with source_file
Write Extracted Row
  ↓ appends directly (no smart-table-fill!)
```

**field_schemas type mapping (converter's Split Files and Build Schema):**
| Schema Type | JSON Schema Type | Notes |
|-------------|-----------------|-------|
| `str` | `string` | Default |
| `int` | `number` | |
| `list` | `array` (items: string) | |
| `class` | `string` with `enum` | Uses comma-separated Classes |
| `date` | `string` | |

**Why this works:**
The `outputParserStructured` node enforces JSON Schema validation on LLM output. By making user columns **required properties**, the LLM MUST include them or the output fails validation and retries. This is much stronger than prompt hints alone.

**Backward compatibility:**
Callers that don't pass `field_schemas` get the fallback base schema (content_class, class_confidence only). Existing integrations continue to work.

**Edge cases:**
- No schema sheet yet: LLM generates schema from column headers, then extraction proceeds
- Only internal columns (`source_file`, `text_to_interpret`, `row_number`): Empty extraction passed
- Non-image files: Extraction ignored (PDF/CSV extractors don't use it)

#### Why mode: each (not batch)

Per-file execution means each file gets its own Write Extracted Row append. If file #6 fails, files 1-5 are already written. On retry, the resumability check skips those 5.

#### v2 Data Parsing

The any-file2json-converter returns structured JSON in `data.text`:
```json
{
  "data": {
    "text": "{\"field1\": \"value1\", \"field2\": \"value2\"}",
    "content_class": "primary_document",
    "class_confidence": 0.95
  }
}
```

The Prepare Write Data node:
1. Logs a `console.warn` and returns early (`return []`) if the converter output is empty — makes skipped files visible in n8n's execution log while preserving retry-on-next-run behavior
2. Parses `data.text` as JSON; if the LLM returned an array (`[{...}]`), unwraps the first element; non-object results are discarded
3. Spreads extracted fields first, then sets `source_file` and `Text_to_interpret` **after** the spread — this guarantees internal fields are never overwritten by LLM output with colliding keys
4. Removes internal fields (content_class, class_confidence, confidence)
5. Returns clean row data for Write Extracted Row

#### Target Sheet Setup

The user's Google Sheet needs column headers for their data fields. Both `source_file` and `Text_to_interpret` columns are auto-created by the Ensure Headers logic if missing.

| Column | Required | Purpose |
|--------|----------|---------|
| `source_file` | Auto-created | Filename identifier for resumability matching |
| `Text_to_interpret` | Auto-created | Raw converter JSON output |
| *(user's data columns)* | Yes | Whatever structured data to extract |

**Note:** Delete the `Description_hig7f6` schema sheet if it was generated before adding these columns, so it regenerates with the new headers.

#### Schema Auto-Creation (v2)

On first run, if the schema sheet doesn't exist:
1. `Fetch Data and Schema Sheets` uses `spreadsheets.get` with `includeGridData=true` - returns all sheets that exist (no error if schema sheet is missing)
2. `If Schema Exists` checks the raw response inline for a schema sheet with data rows (no intermediate parse node)
3. `Generate Schema with LLM` generates schema from data sheet column headers (extracted inline from raw response)
4. `Create and Write Schema Sheet` creates the sheet + writes schema rows via batchUpdate
5. Flow continues to Ensure Headers → normal processing

**Why spreadsheets.get instead of batchGet:** The `values:batchGet` API fails entirely if ANY range references a non-existent sheet. With `spreadsheets.get`, missing sheets simply aren't in the response - no error thrown. This enables graceful first-run handling without try/catch workarounds.

The schema generation uses the same LLM chain pattern as smart-table-fill (Groq with gpt-oss-120b, structured output parser).

---

## Node Mapping: smart-table-fill ↔ smart-folder2table

| Phase | smart-table-fill | smart-folder2table | Notes |
|-------|------------------|--------------------|-------|
| Trigger | When Executed by Another Workflow | When Executed by Another Workflow | Both passthrough |
| Config | String Input | Config | Different names by design |
| Read sheets | Fetch Data Sheet Headers + Try Fetch Schema Sheet | Fetch Data and Schema Sheets | 1 call vs 2 |
| Schema check | If Schema Exists | If Schema Exists | string exists vs boolean |
| Schema gen | Generate Schema with LLM | Generate Schema with LLM | Identical |
| Schema LLM | Schema LLM | Schema LLM | Identical |
| Schema parser | Schema Output Parser | Schema Output Parser | Identical |
| Schema write | Create and Write Schema Sheet | Create and Write Schema Sheet | Identical (refs differ) |
| Header setup | — | Ensure Headers | folder2table-only |
| Schema build | Build Output Schema | Build Output Schema and Filter (inline) | Different scope |
| Extraction | Extract Data from String | Convert File to Text (subworkflow) | LLM chain vs subworkflow |
| Post-process | Merge Outputs | Prepare Write Data | Different merge needs |
| Write | Write Extracted Row / CRM Write via Apps Script | Write Extracted Row | Different targets |
