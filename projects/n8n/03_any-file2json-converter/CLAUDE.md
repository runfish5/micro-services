# any-file2json-converter

Converts files (images, PDFs, spreadsheets) to structured JSON. Images use a vision-capable LLM for OCR; others use native extraction.

## Input

Binary data + optional `extraction` object (see schema below).

## Output

| Field | Type | Notes |
|-------|------|-------|
| `status` | `ok` \| `unsupported` | |
| `error` | object \| null | `{code, mimeType, fileName, message}` for unsupported files |
| `data.text` | string | Extracted content |
| `data.content_class` | string | `primary_document`, `style_element`, `unclassified`, `UNK` |
| `data.class_confidence` | number \| `UNK` | 0.0-1.0 for images |

Unsupported types return `status: "unsupported"`, `error.code: "UNSUPPORTED_MIME_TYPE"`. That is not an error:
no retry can change a file's type. For them `data.text` holds `[unsupported] No route for file type …`.

A step that fails on a file (corrupt PDF, LLM schema miss, unreachable URL) **fails the run**, as it always
has. The caller's Execute Workflow node then fails too, so its error workflow (`007` → FailedItems →
resolver) records the failing node and n8n's message. A caller that wants to keep going per file sets
its own Execute Workflow node to continue on error and handles `{error}`, as `smart-folder2table` does.
Deliberately not done here: wiring every node's error output into one handler. It hid failures from
callers that do not check `status` (`04` would have filed the error text as a document).

## Called By

- `04_inbox-attachment-organizer`
- `02_smart-table-fill/workflows/smart-folder2table.json`
- `06_exact-recall-across-collections`

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
