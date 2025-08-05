# Bulk Data Processing Workflow

Eliminates copy-pasting data rows for analysis one by one. Process hundreds of rows automatically instead of manual repetition.

## Who it's for

Anyone doing repetitive data tasks: content managers, analysts, marketers processing large datasets for categorization, extraction, or analysis.

## What it does

**🔄 Batch Queries** → Process hundreds of rows at once instead of individual copy-paste  
**📂 Categorize Documents** → Automatically sort and classify content  
**🔍 Extract Data** → Pull specific information from any text source  
**🔗 Combine Sources** → Link multiple data streams for insights  

## You need

- **n8n** access
- **Data source** (Google Sheets, CSV, etc.)
- **Access to an LLM** (OpenAI, Groq, Claude, etc.)

## How to use

1. **Get n8n**: Use directly on [n8n.cloud](https://n8n.cloud) or [self-host](https://youtu.be/kq5bmrjPPAY)
2. **Import**: Copy the JSON workflow into n8n (literally `Ctrl+V` into the canvas)
3. **Connect**: Link your data source and LLM
4. **Run**: Click trigger and watch it process hundreds of rows automatically

---

That's it! The workflow handles everything automatically. If you need help customizing the data extraction, check the troubleshooting section below.

## Troubleshooting

### Structured Output

The workflow uses JSON Schema to define what data to extract. Here are two simple examples:

**Content Analysis:**
```json
{
  "type": "object",
  "properties": {
    "target_audience": {
      "type": "string",
      "description": "Who this content is for"
    },
    "main_topic": {
      "type": "string", 
      "description": "Primary subject discussed"
    }
  },
  "required": ["target_audience", "main_topic"]
}
```

**Document Processing:**
```json
{
  "type": "object",
  "properties": {
    "document_type": {
      "type": "string",
      "description": "Category of document"
    },
    "key_date": {
      "type": "string",
      "description": "Important date mentioned"
    }
  },
  "required": ["document_type"]
}
```

Match the property names to your Excel column headers for automatic data population.
