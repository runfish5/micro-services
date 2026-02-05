# any-file2json-converter Flow

```
Trigger → Input Validator → Modify File & Input → Switch
                                                                    │
   ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
   0      1      2      3      4      5      6      7      8
 image   pdf   json  excel  gsheet  doc   csv   URL  fallback
   │      │      │      │      │      │      │      │      │
   └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
                              │
                        Return node
```

## Switch Routing

| # | MIME | Handler |
|---|------|---------|
| 0 | `image/*` | conversion → Image-to-text (Gemini) |
| 1 | `application/pdf` | Extract PDF Text |
| 2 | `application/json` | Extract from JSON |
| 3 | `application/vnd.ms-excel` | Extract from Excel → Aggregate |
| 4 | `application/vnd.google-apps.spreadsheet` | Extract from CSV → Aggregate |
| 5 | `application/vnd.google-apps.document` | Extract Document Text |
| 6 | `text/csv` | Extract from CSV → Aggregate |
| 7 | `text/x-url` (pseudo) | Fetch URL (Jina) → Return node |
| 8 | fallback | Unresolved Handler |

## Key Nodes

- **Input Validator**: Defaults `extraction`, passes `metadata`
- **Modify File & Input**: Builds dynamic JSON Schema from `extraction.field_schemas`, flattens binary files, detects URL input and sets pseudo-MIME `text/x-url`
- **Output Schema**: Uses dynamic expression `$json.output_schema` with fallback to base schema
- **Image-to-text**: Uses dynamic prompt from Input Validator, enforced by Output Schema
- **Fetch URL (Jina)**: HTTP GET to `https://r.jina.ai/{url}` for markdown conversion
- **Unresolved Handler**: Returns structured error for unknown types
- **Return node**: Normalizes all paths to unified output

## Schema-Aware Extraction

When callers pass `extraction.field_schemas`, the Build Output Schema node dynamically expands the JSON Schema:

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

## LLM

Google Gemini via `CREDENTIAL_ID_GEMINI`. Classification required for images only.
