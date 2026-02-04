# any-file2json-converter

Converts files (images, PDFs, spreadsheets) to structured JSON. Images use Gemini OCR; others use native extraction.

## Input

Binary data + optional JSON:
- `extraction_prompt` - Custom prompt for image OCR (default: "Extract all visible data")
- `metadata` - Passthrough object

## Output

| Field | Type | Notes |
|-------|------|-------|
| `status` | `resolved` \| `unresolved` | |
| `data.text` | string | Extracted content |
| `data.content_class` | string | `primary_document`, `style_element`, `unclassified`, `UNK` |
| `data.class_confidence` | number \| `UNK` | 0.0-1.0 for images |
| `metadata` | object | Passthrough |

Unsupported types return `status: "unresolved"` with `error_code: "UNSUPPORTED_MIME_TYPE"`.

## Called By

- `04_inbox-attachment-organizer`
- `02_smart-table-fill/folder-processor.json`
