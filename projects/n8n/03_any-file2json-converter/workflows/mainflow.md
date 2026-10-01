# any-file2json-converter Flow

```
Trigger → Set Default Extraction → Split Files and Build Schema → Route by File Type
                                                    │
   ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
   0      1      2      3      4      5      6      7      8
 image   pdf   json  excel  gsheet  text   csv   URL  fallback
   │      │      │      │      │      │      │      │      │
   │      └──────┴──────┴──────┴──────┴──────┴──────┘      │
   │                          │                            │
   │                  If Schema Provided                   │
   │                     /      \                          │
   │                  Yes        No                        │
   │                   │          │                        │
   │           Text-to-Structured │               Mark Unsupported File
   │              (LLM)           │                        │
   │                   │          │                        │
   └───────────────────┴──────────┴────────────────────────┘
                              │
                        Return Result
```

A step that fails fails the run: the caller's Execute Workflow node fails too and its error workflow sees
it. A caller that wants per-file results sets its own Execute Workflow node to continue on error.

## Switch Routing

| # | MIME | Handler |
|---|------|---------|
| 0 | `image/*` except `svg` | Convert Image Format → Image-to-Text (vision LLM) |
| 1 | `application/pdf` | Extract PDF Text → If Schema Provided |
| 2 | `application/json` | Extract JSON Content → If Schema Provided |
| 3 | `application/vnd.ms-excel`, `…spreadsheetml.sheet` (.xlsx) | Extract Excel Rows → Aggregate Rows → Join Rows into Text → If Schema Provided |
| 4 | `application/vnd.google-apps.spreadsheet` | Extract CSV Rows → Aggregate Rows → Join Rows into Text → If Schema Provided |
| 5 | `application/vnd.google-apps.document`, `*svg*`, `text/plain\|markdown\|html\|xml`, `application/xml` | Extract Document Text → If Schema Provided |
| 6 | `text/csv` | Extract CSV Rows → Aggregate Rows → Join Rows into Text → If Schema Provided |
| 7 | `text/x-url` (pseudo) | Fetch URL as Text (r.jina.ai, 3 tries) → If Schema Provided |
| 8 | fallback | Mark Unsupported File (`status: unsupported`) |

SVG is excluded from rule 0 on purpose: the image converter has no decode delegate for it.
A MIME label is a category, not a capability. See root `CLAUDE.md` § SVG.

## Key Nodes

- **Set Default Extraction**: Defaults `extraction`
- **Split Files and Build Schema**: Builds dynamic JSON Schema from `extraction.field_schemas`, flattens binary files, detects URL input and sets pseudo-MIME `text/x-url`
- **Image Output Parser**: Uses dynamic expression `$json.output_schema` for image path
- **Image-to-Text**: Uses dynamic prompt from Set Default Extraction, enforced by Image Output Parser (images only)
- **If Schema Provided**: IF node checking `extraction.field_schemas.length > 0` - routes text extractors to LLM when schema provided
- **Text-to-Structured**: LLM chain that converts extracted text to structured JSON using `output_schema`
- **Text Output Parser**: Same dynamic schema pattern as images, for text-based extraction
- **Fetch URL as Text**: HTTP GET to `https://r.jina.ai/{url}` for markdown conversion, retried 3 times
- **Mark Unsupported File**: Fallback route only. Returns `status: unsupported` with `error: {code, mimeType, fileName, message}`
- **Return Result**: Normalizes all paths to unified output

## Schema-Aware Extraction

When callers pass `extraction.field_schemas`, the Split Files and Build Schema node dynamically expands the JSON Schema:

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
