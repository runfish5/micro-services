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
  │                batch_size, llm_rate_limit, llm_rate_delay)
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
| 11 | Build Output Schema | code | Build JSON schema (sources from upstream) |
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

### Update-or-Append Logic (Merge Outputs)

The Merge Outputs node handles row matching for the Write_Excel node:

1. **Dynamic match column**: Sets `merged[matchColumn]` from the `match_column` config
2. **Write_Excel compatibility**: Always copies match value to `merged.email` (Write_Excel hardcoded to match on "email" column)
3. **Overwrite prevention**: Only sets `merged[textColumn]` if `textColumn !== matchColumn` to prevent the text body from overwriting the match value

This ensures rows UPDATE at correct positions instead of appending new rows when `match_column` is set to a non-email field like `Text_to_interpret`.

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

