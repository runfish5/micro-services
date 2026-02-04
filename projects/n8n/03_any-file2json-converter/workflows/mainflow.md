# any-file2json-converter Flow

```
Trigger → Input Validator → (File-rename) → Switch
                                              │
   ┌──────┬──────┬──────┬──────┬──────┬──────┼──────┐
   0      1      2      3      4      5      6      7
 image   pdf   json  excel  gsheet  doc   csv  fallback
   │      │      │      │      │      │      │      │
   └──────┴──────┴──────┴──────┴──────┴──────┴──────┘
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
| 7 | fallback | Unresolved Handler |

## Key Nodes

- **Input Validator**: Defaults `extraction_prompt`, passes `metadata`
- **Image-to-text**: Uses dynamic prompt from Input Validator
- **Unresolved Handler**: Returns structured error for unknown types
- **Return node**: Normalizes all paths to unified output

## LLM

Google Gemini via `CREDENTIAL_ID_GEMINI`. Classification required for images only.
