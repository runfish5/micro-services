# 🔄 Main Flow (10 Active Nodes)

📋 Workflow Overview

This workflow batch-processes rows from a Google Sheet through an LLM to extract structured data, eliminating manual copy-paste operations.


## 🎯 Workflow Flow Summary


### Phases:
```
Data Input (1-3)
Batch Loop (4-5)
LLM Extraction (6-8)
Write Results (9)
```

### Data Flow
```
Google Sheet → Filter Range → Loop Over Rows
                                    ↓
                              Has Content?
                                    ↓
                              LLM Extract
                                    ↓
                              Write Back
                                    │
                                    └→ Next Row (loop)
```


### Key Workflow Logic
```
  Flow Summary:
  Manual Trigger → Read Excel → Select Range (rows 2-100)
    ↓
  Loop1 (batch processor)
    ↓
  format validation → Skip if empty
    ↓
  process row (LLM Chain + Structured Output)
    ↓
  Write_Excel → Update row → Loop back
```

### Lineage
```
START: Trigger1 (Manual)
  │
  └→ Read Excel (Google Sheets)
     │
     └→ Select Range (filter rows 2-100)
        │
        └→ Loop1 (Split in Batches)
           │
           └→ format validation (If Email_Response exists)
              │
              ├─ FALSE: skip
              │
              └─ TRUE:
                 └→ process row (LLM Chain)
                    │
                    ├── LLM1 (Groq model)
                    └── SO1 (Structured Output Parser)
                    │
                    └→ Write_Excel (update row)
                       │
                       └→ Loop1 (next item)
```

## 🦜 AI Model Nodes

### 1. process row (LLM Chain)
- **Node**: process row
- **Input**: Row data as JSON in `<source_text>` tags
- **Output**: Structured extraction per schema
- **Prompt Strategy**: Requests exact extraction, no fabrication, uses "-" or "0" for missing values

### 2. SO1 (Structured Output Parser)
- **Node**: SO1
- **Schema**: Inline JSON Schema (customizable)
- **Current Example**: Facility analysis fields
- **Alternative Schemas**: See `.st.json` files in project root

## 📝 Notes
- Loop processes one row at a time to avoid LLM rate limits
- Matches rows by `Response_ID` column for updates
- Disabled nodes (Read Excel1, Write_Excel1, SO) show alternative configurations
