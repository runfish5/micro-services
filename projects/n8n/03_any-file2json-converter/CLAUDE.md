# any-file2json-converter

Converts files (images, PDFs, spreadsheets) to structured JSON. Images use a vision-capable LLM for OCR; others use native extraction.

## Input

Binary data + optional `extraction` object (see schema below).

## Output

| Field | Type | Notes |
|-------|------|-------|
| `status` | `ok` \| `unsupported` \| `stopped` | `stopped`: an image not read because the vision daily quota is used up |
| `error` | object \| null | `{code, mimeType, fileName, message}` for unsupported files; `{code: VISION_DAILY_QUOTA, model, quota_limit, resets_at, message}` for stopped ones |
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

## Routing rules to keep

- **Vision requests are paced across runs: one request per 13 s, whichever run sends it.** The
  next free time is the single row of the data table `vision_pacing` (`next_request_at`).
  `Read Vision Slot` + `Take Vision Slot` move it 13 s on by compare-and-swap (the update matches
  only the value just read; `If Slot Taken` sends a run that lost the race back to read again),
  then `Pace Vision Requests` waits for the slot and `Restore Vision Image` hands the image to
  `Image-to-Text`. The free vision tier allows 5 requests per minute, and runs overlap: several
  callers, a poll during a backfill. Node retries cannot do this (they wait at most 5 s). With no
  row in the table, requests go out unpaced: keep the one row.
- **A used-up DAILY vision quota stops the vision calls until it resets.** `Check Vision Quota` +
  `Gate Vision Requests` read the data table `vision_quota`; a blocked image returns
  `status: stopped` with `error.code: VISION_DAILY_QUOTA` and `resets_at`, and no request is sent.
  On an Image-to-Text error, `Read Quota Error` repeats the call over HTTP because the LLM node
  drops the 429 body; `Classify Vision Error` blocks only on a per-day quota id. A per-minute
  429, or one whose repeat already succeeds, goes through `If Minute Limit` to
  `Wait Out Vision Limit` (the provider's retry delay, at most 61 s) and takes a new slot, at most
  4 times per run. Everything else is rethrown. Callers must treat `stopped` as "not read yet",
  not as empty text; `04` holds the email back.

- **SVG goes to the text route, not the image route.** In `Route by File Type`, rule 0 excludes
  `svg` and rule 5 accepts it: the image branch (`Convert Image Format`) cannot decode SVG. The
  condition looks odd; do not tidy it out. General rule: route by what a branch can do, not by
  what the MIME label says.
- **`anything converter`** on the instance is an active, uncalled duplicate of this workflow.
  Only this one is called; the duplicate should be deleted.

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
