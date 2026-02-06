# any-file2json-converter

Converts files (images, PDFs, spreadsheets) to structured JSON. Images use a vision-capable LLM for OCR; others use native extraction.

## Input

Binary data + optional `extraction` object (see schema below).

## Output

| Field | Type | Notes |
|-------|------|-------|
| `status` | `resolved` \| `unresolved` | |
| `data.text` | string | Extracted content |
| `data.content_class` | string | `primary_document`, `style_element`, `unclassified`, `UNK` |
| `data.class_confidence` | number \| `UNK` | 0.0-1.0 for images |

Unsupported types return `status: "unresolved"` with `error_code: "UNSUPPORTED_MIME_TYPE"`.

## Called By

- `04_inbox-attachment-organizer`
- `02_smart-table-fill/folder-processor.json`

## Extraction Object

Binary data + optional `extraction` object for dynamic extraction context:

```json
{
  "extraction": {
    "type": "invoice|receipt|document|custom",
    "focus_fields": ["invoice_number", "total", "vendor_name"],
    "instructions": "Additional extraction guidance",
    "field_schemas": [
      {"name": "total", "type": "int", "description": "Invoice total"},
      {"name": "category", "type": "class", "description": "Document type", "classes": "invoice,receipt,other"}
    ]
  }
}
```

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| type | string | — | Document category hint for LLM |
| focus_fields | string[] | [] | Prioritized fields to extract |
| instructions | string | "" | Free-form extraction guidance |
| field_schemas | object[] | [] | Column definitions for structured extraction |

Each `field_schemas` object: `{name, type (str|int|list|class), description, classes?}`. See mainflow.md §Schema-Aware Extraction for type mapping.

All fields are optional. Omit extraction entirely for default behavior (backward compatible).
