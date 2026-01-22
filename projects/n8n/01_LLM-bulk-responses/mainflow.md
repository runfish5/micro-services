# Main Flow (14 Nodes)

> Last verified: 2026-01-16

## Overview
Batch processes spreadsheet rows with LLM to extract structured data, with row range filtering and rate limiting for safe operation.

## Flow Summary

### Phases
```
Initialization (Nodes 1-4)
  - Trigger → Read Excel → Select Range → Loop1 (batch iterator)
Processing Loop (Nodes 5-9)
  - format validation → process row (LLM extraction) → Write_Excel
Disabled Paths (Nodes 10-14)
  - Alternative extraction configurations and range selectors
```

### Data Flow
```
Trigger1 → Read Excel (fetch all rows)
              ↓
         Select Range (filter rows 2-99)
              ↓
         Loop1 (split in batches, reset: false)
              ↓
         format validation (check Email_Response exists)
              ↓
         process row (LLM extraction with structured output)
         ├─ LLM1 (Groq openai/gpt-oss-120b)
         └─ SO1 (structured output parser)
              ↓
         Write_Excel (update matching row)
              ↓
         Loop back to Loop1 (continue batching)
```

### Lineage Tree
```
START: Trigger1 (Manual Trigger)
  │
  └→ Read Excel (Google Sheets - read spreadsheet_id, sheet_name)
       │
       └→ Select Range (Filter: row_number >= 2 AND row_number < 100)
            │
            └→ Loop1 (Split In Batches, reset: false)
                 │
                 └→ format validation (IF: Email_Response exists)
                      │
                      └→ process row (chainLlm)
                           ├─ LLM1 (Groq gpt-oss-120b)
                           ├─ SO1 (outputParser - care facility schema)
                           │
                           └→ Write_Excel (update by Response_ID)
                                │
                                └→ Loop back to Loop1

Disabled branches:
  - Read Excel1 → Select Range1 → Write_Excel1 (alternative processing path)
  - SO (alternative structured output parser)
```

## AI Model Nodes

### 1. process row (Main Extraction)
- **Node**: process row
- **Model**: Groq `openai/gpt-oss-120b` (via LLM1)
- **Input**: Full row data as JSON (includes Email_Response field)
- **Output**: Structured data matching SO1 schema
- **Purpose**: Extract care facility information from email responses with confidence scoring
- **Schema**: Care facility analysis with fields:
  - `monthly_cost` (integer)
  - `facility_size` (string enum: small, medium, large, very_large)
  - `medical_services` (boolean)
  - `specialized_dementia_care` (boolean)
  - `staff_ratio_mentioned` (boolean)
  - `overall_suitability_score` (integer 1-10)
  - `red_flags` (array of strings)

## Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Trigger1 | manualTrigger | Manual execution start |
| 2 | Read Excel | googleSheets | Fetch all rows from target sheet |
| 3 | Select Range | filter | Filter rows 2-99 (adjustable) |
| 4 | Loop1 | splitInBatches | Iterate through filtered rows (reset: false) |
| 5 | format validation | if | Check if Email_Response field exists |
| 6 | process row | chainLlm | LLM extraction with structured output |
| 7 | LLM1 | lmChatGroq | Groq model (openai/gpt-oss-120b) |
| 8 | SO1 | outputParserStructured | Care facility schema parser |
| 9 | Write_Excel | googleSheets | Update row by Response_ID |
| 10 | Read Excel1 | googleSheets | Alternative read path (disabled) |
| 11 | Select Range1 | filter | Alternative range 11-12 (disabled) |
| 12 | Write_Excel1 | googleSheets | Alternative write path (disabled) |
| 13 | SO | outputParserStructured | Alternative schema (disabled) |
| 14 | Sticky Notes | stickyNote | Documentation nodes (3 total) |

## Notes

### Row Range Configuration
- **Select Range** node: Adjust `leftValue` and `rightValue` to process different row ranges
- Default: rows 2-99 (row 1 is typically headers)
- **Select Range1** (disabled): Example of processing rows 11-12 for testing

### Structured Output Schema (SO1)
The care facility analysis schema requires:
- **monthly_cost**: Base rate if range given
- **facility_size**: Approximate size classification
- **medical_services**: On-site nursing/medical care
- **specialized_dementia_care**: Dementia/Alzheimer's programs
- **staff_ratio_mentioned**: Staff-to-resident ratios mentioned
- **overall_suitability_score**: 1-10 rating
- **red_flags**: Array of concerning elements

### Update Matching
- Write_Excel updates rows by matching `Response_ID` column
- Uses `appendOrUpdate` operation (will create new rows if no match found)

### Alternative Schema (SO - disabled)
The disabled `SO` node shows a simpler schema focusing on:
- availability_status
- cost_range (enum: under_3000, 3000_4000, 4000_5000, 5000_7000, over_7000)
- cognitive_stimulation_programs
- facility_size

### Best Practices
1. Test with small ranges first (e.g., rows 11-12 using Select Range1)
2. Monitor LLM rate limits (Groq free tier: varies by model, use 5 req/min as safe default for batch processing)
3. Use `reset: false` in Loop1 to continue from last position if workflow fails
4. Verify `Response_ID` column exists in your sheet for matching

---
