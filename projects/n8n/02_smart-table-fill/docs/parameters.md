# LIST MODE Parameters

Parameters that enable multi-row processing.

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `text_column` | string | `Text_to_interpret` | Column containing text to extract from |
| `match_column` | string | `email` | Column used to find/update existing rows |
| `match_same_row` | boolean | `true` | `true`=update existing, `false`=always append |
| `row_number` | number | `null` | Explicit row index (overrides match_column) |
| `batch_size` | number | `10` | Fields per LLM call (for rate limiting) |

## How LIST MODE Works

- Input N items → Output N rows
- Each row split into schema batches → parallel LLM processing → merged back
- Automatic: detected when String Input receives multiple items
