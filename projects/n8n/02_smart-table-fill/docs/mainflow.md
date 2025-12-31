# Main Flow (21 Nodes)

## Overview
Extracts structured data from unstructured text into Google Sheets using dynamic schema with auto-creation on first run.

## Flow Summary

### Phases
```
Triggers (Nodes 1-2)
Schema Check & Creation (Nodes 3-12)
  - Fetch data headers → Check schema exists → Create if needed
Data Extraction (Nodes 13-21)
  - Build JSON schema → LLM extraction → Write to sheet
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
         ├─ YES → Merge ────────────────┐
         └─ NO                          │
              ↓                         │
         Create Sheet (API)             │
              ↓                         │
         LLM: Generate Schema           │
              ↓                         │
         Append Schema to Sheet ────────┘
                                        ↓
                              Fetch Headers (schema)
                                        ↓
                              Build Output Schema
                                        ↓
                              LLM: Extract Data
                                        ↓
                              Write to Data Sheet
```

### Lineage Tree
```
START: Manual Trigger / When Executed by Another Workflow
  │
  └→ String Input (config: SpreadsheetId, DataSheetName, SchemaSheetName)
       │
       └→ Fetch Data Sheet Headers (row 1 of data sheet)
            │
            └→ Try Fetch Schema Sheet (Description_hig7f6)
                 │
                 └→ IF: Schema Exists?
                      │
                      ├─ TRUE:
                      │  └→ Merge (input 0)
                      │
                      └─ FALSE:
                         ├→ HTTP: Create Sheet (Sheets batchUpdate API)
                         ├→ Prep Columns for LLM (extract column names)
                         ├→ LLM: Generate Schema
                         │     ├─ Schema LLM (llama-3.1-8b-instant)
                         │     └─ Schema Output Parser
                         ├→ Split Schema Rows
                         └→ Append Schema to Sheet
                              └→ Merge (input 1)

              Merge
                │
                └→ Fetch Headers (schema sheet)
                     │
                     └→ Build Output Schema (convert schema to JSON schema)
                          │
                          └→ Extract Data from String
                          │     ├─ LLM Processor (gpt-oss-120b)
                          │     └─ Dynamic Output Parser
                          │
                          └→ Merge Outputs
                               │
                               └→ Write_Excel (update data sheet)
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
| 4 | Fetch Data Sheet Headers | googleSheets | Get column names from data sheet |
| 5 | Try Fetch Schema Sheet | googleSheets | Check if schema sheet exists |
| 6 | IF: Schema Exists? | if | Branch on schema existence |
| 7 | HTTP: Create Sheet | httpRequest | Create schema sheet via API |
| 8 | Prep Columns for LLM | code | Format columns for LLM |
| 9 | LLM: Generate Schema | chainLlm | Generate schema definitions |
| 10 | Schema LLM | lmChatGroq | Language model for schema |
| 11 | Schema Output Parser | outputParser | Parse schema JSON |
| 12 | Split Schema Rows | code | Convert array to items |
| 13 | Append Schema to Sheet | googleSheets | Write schema rows |
| 14 | Merge | merge | Join schema exists/created branches |
| 15 | Fetch Headers | googleSheets | Read schema sheet |
| 16 | Build Output Schema | code | Build JSON schema from schema rows |
| 17 | Extract Data from String | chainLlm | LLM data extraction |
| 18 | LLM Processor | lmChatGroq | Language model for extraction |
| 19 | Dynamic Output Parser | outputParser | Parse extracted data |
| 20 | Merge Outputs | code | Merge batch outputs |
| 21 | Write_Excel | googleSheets | Update data sheet row |

## Notes
- Schema sheet name `Description_hig7f6` has suffix for disambiguation
- First run creates schema; subsequent runs skip creation
- Edit schema sheet to customize extraction (types, descriptions, enum values)
- BatchSize controls how many fields per LLM call
- Write_Excel uses `appendOrUpdate` operation with `email` as matching column

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
