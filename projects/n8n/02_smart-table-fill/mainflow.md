# Main Flow (17 Nodes)

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
  - Build JSON schema → Call rate-limited subworkflow → Merge outputs → Write
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
         LLM: Generate Schema           │
              ↓                         │
         Create & Write Schema ─────────┘
                                        ↓
                              Build Output Schema
                              (sources data from upstream)
                                        ↓
                              Call llm-extract-rate-limited
                              (subworkflow with rate limiting)
                                        ↓
                              Merge Outputs
                                        ↓
                    ┌─────────────────────────────────────────┐
                    │ Standalone: Write_Excel (native Sheets) │
                    └─────────────────────────────────────────┘
                                        │
                                        │ (or CRM mode)
                                        ↓
                              [CRM] Write via Apps Script (HTTP POST)
                                        ↓
                              [CRM] Prep Email Store Input
                                        ↓
                              [CRM] Call contact-email-store
```

### Lineage Tree
```
START: Manual Trigger / When Executed by Another Workflow
  │
  └→ String Input (config: spreadsheet_id, data_sheet_name, schema_sheet_name,
  │                body_core, contact_name, contact_email, subject,
  │                match_column, match_value, batch_size)
       │
       └→ Fetch Data Sheet Headers (row 1 of data sheet)
            │
            └→ Try Fetch Schema Sheet (Description_hig7f6)
                 │
                 └→ IF: Schema Exists?
                      │
                      ├─ TRUE:
                      │  └→ Build Output Schema (uses Try Fetch Schema Sheet data)
                      │
                      └─ FALSE:
                         ├→ LLM: Generate Schema
                         │     ├─ Schema LLM (Groq)
                         │     └─ Schema Output Parser
                         └→ Create & Write Schema Sheet (Sheets batchUpdate API)
                              └→ Build Output Schema (uses LLM: Generate Schema data)
                          │
                          └→ Call llm-extract-rate-limited (subworkflow)
                          │     - Handles rate limiting for Groq free tier
                          │     - Batches schema fields per llm_rate_limit
                          │     - Waits llm_rate_delay seconds between batches
                          │
                          └→ Merge Outputs
                               │
                               ├→ Write_Excel (disabled, standalone mode)
                               │
                               └→ [CRM] Write via Apps Script (HTTP POST to doPost)
                                    │  - Writes all extracted fields to sheet
                                    │  - Creates folder + emails/ subfolder if needed
                                    │  - Returns folder_id, emails_folder_id
                                    │
                                    └→ [CRM] Prep Email Store Input
                                         │
                                         └→ [CRM] Call contact-email-store
```

## AI Model Nodes

### 1. Schema Generation (first run only)
- **Node**: LLM: Generate Schema
- **Model**: Groq LLM (configurable)
- **Input**: Column names from data sheet
- **Output**: JSON array with ColumnName, Type, Description, Classes
- **Purpose**: Intelligently infer schema from column names

### 2. Data Extraction (via subworkflow)
- **Subworkflow**: llm-extract-rate-limited
- **Model**: Groq LLM (configurable)
- **Input**: Raw text + dynamic JSON schema + rate limiting config
- **Output**: Structured data matching schema + confidence scores
- **Purpose**: Extract values from unstructured text with rate limiting for Groq free tier

## Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Manual Trigger | trigger | Manual execution |
| 2 | When Executed by Another Workflow | trigger | Subworkflow entry |
| 3 | String Input | set | Configuration variables |
| 4 | Fetch Data Sheet Headers | httpRequest | Get column names from data sheet |
| 5 | Try Fetch Schema Sheet | googleSheets | Check if schema sheet exists |
| 6 | IF: Schema Exists? | if | Branch on schema existence |
| 7 | LLM: Generate Schema | chainLlm | Generate schema definitions |
| 8 | Schema LLM | lmChatGroq | Language model for schema |
| 9 | Schema Output Parser | outputParser | Parse schema JSON |
| 10 | Create & Write Schema Sheet | httpRequest | Create sheet + write schema via batchUpdate |
| 11 | Build Output Schema | code | Build JSON schema; row_id from match_column → match_value → email |
| 12 | Call llm-extract-rate-limited | executeWorkflow | Subworkflow for rate-limited LLM extraction |
| 13 | Merge Outputs | code | Merge batch outputs + confidence data |
| 14 | Write_Excel | googleSheets | Standalone mode write (disabled by default) |
| 15 | [CRM] Write via Apps Script | httpRequest | Write data + create folder via doPost |
| 16 | [CRM] Prep Email Store Input | set | Prepare data for email store subworkflow |
| 17 | [CRM] Call contact-email-store | executeWorkflow | Store email metadata in contact memory |

## Notes
- Schema sheet name `Description_hig7f6` has suffix for disambiguation
- First run creates schema; subsequent runs skip creation
- Edit schema sheet to customize extraction (types, descriptions, enum values)
- `batch_size` controls how many fields per LLM call (batching within subworkflow)
- **Rate limiting**: Configure `llm_rate_limit` (requests before pause) and `llm_rate_delay` (seconds to wait) for Groq free tier
- **Apps Script handles both writing and folder creation** - no triggers needed (CRM mode)

### Update-or-Append Logic (Merge Outputs + Write_Excel)

The Merge Outputs node prepares clean data for Write_Excel:

1. **Dynamic match column**: Sets `merged[matchColumn]` from the `match_column` config
2. **Write_Excel compatibility**: Always copies match value to `merged.email` (Write_Excel hardcoded to match on "email" column)
3. **Overwrite prevention**: Only sets `merged[textColumn]` if `textColumn !== matchColumn` to prevent the text body from overwriting the match value
4. **Clean output**: Confidence/observability fields are logged but deleted from `merged` before output. Internal fields (`_row_id`, `_meta`, `_match_same_row`, `_row_number`) are explicitly deleted before Write_Excel.

Write_Excel reads `match_same_row` directly from String Input to decide `append` vs `appendOrUpdate`. The `handlingExtraData: "ignoreIt"` option silently drops any fields that don't have matching column headers in the sheet.

### Caller-Overridable Config (String Input)

When called as a subworkflow, callers can override these fields (defaults apply if not provided):

| Field | Default | Purpose |
|-------|---------|---------|
| `spreadsheet_id` | `1xGxyFu3...` | Google Sheets document ID |
| `data_sheet_name` | `Sheet1` | Sheet tab name |
| `schema_sheet_name` | `Description_hig7f6` | Schema definition sheet |
| `batch_size` | `10` | Fields per LLM batch |
| `match_column` | `email` | Which column to match on |
| `match_value` | `$json[$json.match_column]` | Value to match; auto-resolved from `match_column` field name |
| `match_same_row` | `true` | `false` = append-only mode |

---

## Subworkflows

### llm-extract-rate-limited

**File:** `workflows/subworkflows/llm-extract-rate-limited.json`

**Purpose:** Wraps LLM extraction with rate limiting to avoid Groq free tier limits.

#### Flow
```
When Executed by Another Workflow
  ↓
Set Config (capture rate limit params)
  ↓
Prepare Schemas (split schemas to individual items)
  ↓
Split in Batches (batch by llm_rate_limit)
  ↓
Extract Data from String (LLM chain)
  ├─ LLM Processor (Groq)
  └─ Dynamic Output Parser
  ↓
Wait (llm_rate_delay seconds)
  ↓
Loop back to Split in Batches (until all batches processed)
```

#### Inputs

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| schemas | array | - | JSON schema objects from Build Output Schema |
| body_core | string | - | Text to extract data from |
| contact_name | string | '' | Contact context for extraction |
| contact_email | string | '' | Contact context for extraction |
| subject | string | '' | Email subject context |
| llm_rate_limit | number | 5 | Requests before rate limit pause |
| llm_rate_delay | number | 60 | Seconds to wait between batches |

#### Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Manual Trigger | trigger | Testing entry |
| 2 | When Executed by Another Workflow | trigger | Subworkflow entry |
| 3 | Set Config | set | Capture rate limit config |
| 4 | Prepare Schemas | code | Split schemas to items |
| 5 | Split in Batches | splitInBatches | Batch by llm_rate_limit |
| 6 | Extract Data from String | chainLlm | LLM extraction |
| 7 | LLM Processor | lmChatGroq | Extraction model |
| 8 | Dynamic Output Parser | outputParser | Parse extracted JSON |
| 9 | Wait | wait | Rate limit delay |

#### Rate Limiting Behavior

The subworkflow implements a batch + wait pattern:
1. Processes `llm_rate_limit` schemas per batch (default: 5)
2. Waits `llm_rate_delay` seconds after each batch (default: 60)
3. Loops until all schemas are processed

This prevents hitting Groq's free tier rate limits (varies by model; use 5 req/min as safe default for batch processing).

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
Batch Read Sheets (HTTP GET: spreadsheets.get with includeGridData - gracefully handles missing sheets)
     ↓
Parse Sheet Data (Code: normalize response, extract schemaValues/dataValues)
     ↓
IF: Schema Exists? (check if schema sheet has rows)
     ├─ TRUE → Ensure Headers
     └─ FALSE → LLM: Generate Schema → Create & Write Schema Sheet → Ensure Headers
     ↓
Ensure Headers (HTTP POST: add source_file/Text_to_interpret if missing)
     ↓
List Drive Files (Google Drive: list files in folder)
     ↓
Prepare & Filter (Code: build extraction object + filter already-processed)
     ↓
Loop Over Files (1 at a time)
     ↓
Download File (Google Drive: download binary per item)
     ↓
Convert File to Text (Execute Workflow: any-file2json-converter with extraction hints)
     ↓
Rate Limit Wait (dynamic: from Config, default 0s)
     ↓
Prepare Write Data (Code: parse converter JSON output)
     ↓
Write to Sheet (Google Sheets: append row directly)
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
| `match_column` | `source_file` | For extraction row grouping |
| `batch_size` | `10` | Fields per LLM extraction call |
| `schema_sheet_name` | `Description_hig7f6` | Schema sheet (auto-created on first run) |
| `rate_limit_wait_seconds` | `0` | Delay between files (passed by error handler on retry) |

#### Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Manual Trigger | trigger | Manual execution |
| 2 | When Executed by Another Workflow | trigger | Receives config + rate_limit_wait_seconds from error handler |
| 3 | Config | set | Configuration with fallbacks (reads from workflow input or defaults) |
| 4 | Batch Read Sheets | httpRequest | Read all sheets via spreadsheets.get (gracefully handles missing schema sheet) |
| 5 | Parse Sheet Data | code | Normalize response, extract schemaValues/dataValues, set schemaExists boolean |
| 6 | IF: Schema Exists? | if | Check if schema sheet has data rows |
| 7 | LLM: Generate Schema | chainLlm | Generate schema definitions from column headers |
| 8 | Schema LLM | lmChatGroq | Language model for schema generation |
| 9 | Schema Output Parser | outputParser | Parse schema JSON array |
| 10 | Create & Write Schema Sheet | httpRequest | Create sheet + write schema via batchUpdate |
| 11 | Ensure Headers | httpRequest | Add missing `source_file`/`Text_to_interpret` headers via batchUpdate |
| 12 | List Drive Files | googleDrive | List all files in target folder |
| 13 | Prepare & Filter | code | Build extraction object + skip already-processed files |
| 14 | Loop Over Files | splitInBatches | Process one file at a time |
| 15 | Download File | googleDrive | Download file binary data |
| 16 | Convert File to Text | executeWorkflow | Calls any-file2json-converter with extraction hints |
| 17 | Rate Limit Wait | wait | Dynamic delay from Config (default 0s) |
| 18 | Prepare Write Data | code | Parse converter JSON output for sheet write |
| 19 | Write to Sheet | googleSheets | Append row directly to data sheet |

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
- **Production mode**: When published and called via subworkflow trigger, the 007-error-handler handles it automatically - extracts retry timing from 429 errors and restarts with the correct delay.

#### Resumability (Skip-on-Retry)

1. Each Write to Sheet appends a row with `source_file` = filename and `Text_to_interpret` = converter output
2. On retry, `Batch Read Sheets` reads both schema and data sheets in one call
3. `Prepare & Filter` checks the `source_file` column to get processed filenames
4. Already-done files are skipped; only new/failed files are processed

The `source_file` column is auto-created by the Ensure Headers logic. `Text_to_interpret` contains the raw converter output (JSON string with extracted fields).

#### Schema-Aware Extraction

The Prepare & Filter node reads the schema (from sheet or freshly-generated LLM output) and constructs an extraction object that hints the any-file2json-converter about priority fields. The converter uses this to dynamically build a JSON Schema that **enforces** user columns as required fields.

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
Prepare & Filter
  ↓ extraction: {
      focus_fields: [...],
      field_schemas: [...]
    }
────────────────────────────────────→ Input Validator
                                      ↓
                                    Build Output Schema (Code node)
                                      ↓ builds JSON Schema from field_schemas
                                    (File-rename)
                                      ↓ preserves output_schema
                                    Output Schema node
                                      ↓ uses dynamic schema expression
                                    Image-to-text LLM
                                      ↓ enforced schema!
────────────────────────────────────← returns data.text (JSON string)
Prepare Write Data
  ↓ parses JSON, merges with source_file
Write to Sheet
  ↓ appends directly (no smart-table-fill!)
```

**field_schemas type mapping (converter's Build Output Schema):**
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

Per-file execution means each file gets its own Write to Sheet append. If file #6 fails, files 1-5 are already written. On retry, the resumability check skips those 5.

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
1. Parses `data.text` as JSON to get the extracted fields
2. Adds `source_file` (filename) and `Text_to_interpret` (raw JSON string)
3. Removes internal fields (content_class, class_confidence, confidence)
4. Returns clean row data for Write to Sheet

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
1. `Batch Read Sheets` uses `spreadsheets.get` with `includeGridData=true` - returns all sheets that exist (no error if schema sheet is missing)
2. `Parse Sheet Data` normalizes the response, finds schema/data sheets by title, sets `schemaExists` boolean
3. `IF: Schema Exists?` branches on `schemaExists` (false on first run)
4. `LLM: Generate Schema` generates schema from data sheet column headers
5. `Create & Write Schema Sheet` creates the sheet + writes schema rows via batchUpdate
6. Flow continues to Ensure Headers → normal processing

**Why spreadsheets.get instead of batchGet:** The `values:batchGet` API fails entirely if ANY range references a non-existent sheet. With `spreadsheets.get`, missing sheets simply aren't in the response - no error thrown. This enables graceful first-run handling without try/catch workarounds.

The schema generation uses the same LLM chain pattern as smart-table-fill (Groq with gpt-oss-120b, structured output parser).

