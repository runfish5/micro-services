# any-file2json-converter Flow

```
Trigger → Input Validator → Modify File & Input → Switch
                                                    │
   ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
   0      1      2      3      4      5      6      7      8
 image   pdf   json  excel  gsheet  doc   csv   URL  fallback
   │      │      │      │      │      │      │      │      │
   │      └──────┴──────┴──────┴──────┴──────┴──────┘      │
   │                          │                            │
   │                    Has Schema?                        │
   │                     /      \                          │
   │                  Yes        No                        │
   │                   │          │                        │
   │           Text-to-Structured │                        │
   │              (LLM)         │                        │
   │                   │          │                        │
   └───────────────────┴──────────┴────────────────────────┘
                              │
                        Return node
```

## Switch Routing

| # | MIME | Handler |
|---|------|---------|
| 0 | `image/*` | conversion → Image-to-text (vision LLM) |
| 1 | `application/pdf` | Extract PDF Text → Has Schema? |
| 2 | `application/json` | Extract from JSON → Has Schema? |
| 3 | `application/vnd.ms-excel` | Extract from Excel → Aggregate → Summarize → Has Schema? |
| 4 | `application/vnd.google-apps.spreadsheet` | Extract from CSV → Aggregate → Summarize → Has Schema? |
| 5 | `application/vnd.google-apps.document` | Extract Document Text → Has Schema? |
| 6 | `text/csv` | Extract from CSV → Aggregate → Summarize → Has Schema? |
| 7 | `text/x-url` (pseudo) | Fetch URL (Jina) → Has Schema? |
| 8 | fallback | Unresolved Handler |

## Key Nodes

- **Input Validator**: Defaults `extraction`
- **Modify File & Input**: Builds dynamic JSON Schema from `extraction.field_schemas`, flattens binary files, detects URL input and sets pseudo-MIME `text/x-url`
- **Output Schema**: Uses dynamic expression `$json.output_schema` for image path
- **Image-to-text**: Uses dynamic prompt from Input Validator, enforced by Output Schema (images only)
- **Has Schema?**: IF node checking `extraction.field_schemas.length > 0` - routes text extractors to LLM when schema provided
- **Text-to-Structured**: LLM chain that converts extracted text to structured JSON using `output_schema`
- **Text Output Schema**: Same dynamic schema pattern as images, for text-based extraction
- **Fetch URL (Jina)**: HTTP GET to `https://r.jina.ai/{url}` for markdown conversion
- **Unresolved Handler**: Returns structured error for unknown types
- **Return node**: Normalizes all paths to unified output

## Schema-Aware Extraction

When callers pass `extraction.field_schemas`, the Modify File & Input node dynamically expands the JSON Schema:

```
extraction: {
  field_schemas: [
    {name: "color tone", type: "str", description: "..."},
    {name: "object", type: "str", description: "..."},
    {name: "emotional mood", type: "class", classes: "calm,neutral,excited"}
  ]
}
```

**Type mapping:**
| Schema Type | JSON Schema Type |
|-------------|-----------------|
| `str` | `string` |
| `int` | `number` |
| `list` | `array` (items: string) |
| `class` | `string` with `enum` from classes |

User columns become **required** properties, forcing the LLM to include them or fail validation.

### Behavior by File Type

| File Type | No Schema | With Schema |
|-----------|-----------|-------------|
| Image | Vision LLM → structured JSON | Vision LLM → structured JSON (same path) |
| PDF | Raw text passthrough | LLM → structured JSON |
| JSON | Raw JSON passthrough | LLM → structured JSON |
| CSV/Excel | Concatenated text passthrough | LLM → structured JSON |
| Document | Raw text passthrough | LLM → structured JSON |
| URL | Markdown passthrough | LLM → structured JSON |

## LLM

- **Images**: Vision-capable LLM (must accept image input)
- **Text-to-Structured**: Any LLM with structured output support

Classification required for all LLM paths (images and text-to-structured).
