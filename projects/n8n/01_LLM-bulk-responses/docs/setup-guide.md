## Quick Start

**Time:** 15 minutes | **Difficulty:** Easy | **Cost:** Free

### 1. Import Workflow
Copy the JSON workflow into n8n (`Ctrl+V` on canvas):
- [1_LLM-bulk-responses.n8n.json](../1_LLM-bulk-responses.n8n.json)

### 2. Setup Credentials
Two credentials needed:

**Google Sheets OAuth**
- n8n Menu → Credentials → Add → Google Sheets OAuth2
- Follow OAuth flow

**Groq API (Free)**
- Get key at [console.groq.com](https://console.groq.com)
- n8n Menu → Credentials → Add → Groq

### 3. Configure Your Sheet

1. Create or use existing Google Sheet with your data
2. Ensure sheet has:
   - A **unique ID column** for matching (e.g., `Response_ID`, `row_id`)
   - A **source text column** containing data to analyze (e.g., `Email_Response`, `Description`)
   - **Output columns** for extracted fields

3. Update these nodes:
   - **Read Excel**: Select your sheet and tab
   - **Write_Excel**: Select same sheet, configure column mappings

### 4. Configure Extraction Schema

Edit the **SO1** node's JSON Schema to match your extraction needs.

**Example schemas available:**
- `content-analysis.st.json` - Content categorization
- `document-processing.st.json` - Document field extraction

**Schema structure:**
```json
{
  "type": "object",
  "properties": {
    "your_field": {
      "type": "string",
      "description": "What this field should contain"
    }
  },
  "required": ["your_field"]
}
```

### 5. Test Run

1. Set **Select Range** filter to process only 2-3 test rows
2. Click "Test workflow"
3. Verify extracted data appears in your sheet
4. Expand range for full batch processing

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Empty results | Check `format validation` field name matches your data column |
| Rate limits | Loop node already handles batching; reduce concurrent executions if needed |
| Wrong columns | Verify Write_Excel column mappings match your schema fields |
