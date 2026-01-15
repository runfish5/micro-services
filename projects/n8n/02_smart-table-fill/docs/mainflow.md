# Main Flow (20 Nodes)

## Overview
Extracts structured data from unstructured text into Google Sheets using dynamic schema with auto-creation on first run. Uses Apps Script to write data AND create contact folders in a single HTTP call.

## Flow Summary

### Phases
```
Triggers (Nodes 1-2)
Schema Check & Creation (Nodes 3-10)
  - Fetch data headers → Check schema exists → Create if needed
Data Extraction (Nodes 11-16)
  - Build JSON schema → LLM extraction → Write via Apps Script
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
         Create Sheet (API)             │
              ↓                         │
         LLM: Generate Schema           │
              ↓                         │
         Create & Write Schema ─────────┘
                                        ↓
                              Build Output Schema
                              (sources data from upstream)
                                        ↓
                              LLM: Extract Data
                                        ↓
                              Merge Outputs
                                        ↓
                    ┌─────────────────────────────────────────┐
                    │ Standalone: Write_Excel (native Sheets) │
                    └─────────────────────────────────────────┘
                                        │
                                        │ (or CRM mode)
                                        ↓
                              Write via Apps Script (HTTP POST)
                                        ↓
                              IF: Apps Script Success?
                                        ↓ (true)
                              Prep Email Store Input
                                        ↓
                              Call contact-memory-update
```

### Lineage Tree
```
START: Manual Trigger / When Executed by Another Workflow
  │
  └→ String Input (config: spreadsheet_id, data_sheet_name, schema_sheet_name, body_core, match_value)
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
                         │     ├─ Schema LLM (llama-3.1-8b-instant)
                         │     └─ Schema Output Parser
                         └→ Create & Write Schema Sheet (Sheets batchUpdate API)
                              └→ Build Output Schema (uses LLM: Generate Schema data)
                          │
                          └→ Extract Data from String
                          │     ├─ LLM Processor (gpt-oss-120b)
                          │     └─ Dynamic Output Parser
                          │
                          └→ Merge Outputs
                               │
                               └→ Write via Apps Script (HTTP POST to doPost)
                                    - Writes all extracted fields to sheet
                                    - Creates folder + emails/ subfolder if needed
                                    - Returns folder_id, emails_folder_id
```

## AI Model Nodes

### 1. Schema Generation (first run only)
- **Node**: LLM: Generate Schema
- **Model**: llama-3.1-8b-instant (Groq)
- **Input**: Column names from data sheet
- **Output**: JSON array with ColumnName, Type, Description, Classes
- **Purpose**: Intelligently infer schema from column names

### 2. Data Extraction
- **Node**: Extract Data from String
- **Model**: gpt-oss-120b (Groq)
- **Input**: Raw text + dynamic JSON schema
- **Output**: Structured data matching schema
- **Purpose**: Extract values from unstructured text

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
| 12 | Extract Data from String | chainLlm | LLM data extraction |
| 13 | LLM Processor | lmChatGroq | Language model for extraction |
| 14 | Dynamic Output Parser | outputParser | Parse extracted data |
| 15 | Merge Outputs | code | Merge batch outputs |
| 16 | Write via Apps Script | httpRequest | Write data + create folder via doPost |

## Notes
- Schema sheet name `Description_hig7f6` has suffix for disambiguation
- First run creates schema; subsequent runs skip creation
- Edit schema sheet to customize extraction (types, descriptions, enum values)
- BatchSize controls how many fields per LLM call
- **Apps Script handles both writing and folder creation** - no triggers needed

---

## Subworkflows

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

