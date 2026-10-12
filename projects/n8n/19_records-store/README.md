# 19. Records Store

One small store that other workflows call to keep, read and drop rows. Two workflows ship, with
the same inputs and the same outputs. A caller picks one in its store node and knows nothing else
about where its rows live.

| File | Rows live in |
|------|--------------|
| `workflows/records-store-sheets.n8n.json` | one tab per table of a Google spreadsheet |
| `workflows/records-store-http.n8n.json` | a records API on a server you run |
| `workflows/records-store-http.local.n8n.json` | gitignored import copy with the real bindings |

## The contract

A caller is an **Execute Workflow** node with these inputs:

| Input | Used by | Meaning |
|-------|---------|---------|
| `op` | all | `keep`, `read` or `drop` |
| `table` | all | lower-case name: a tab, or a file on the server |
| `key` | `keep`, `drop` | the row field that identifies a row, e.g. `email`; empty to always add |
| `row` | `keep` | an object, one field per column |
| `since` | `read` | ISO time; only rows kept from then on |
| `before` | `drop` | ISO time; rows added before it go |

- **keep** adds a row. With a `key`, it writes the row's fields over the row that holds the same
  value, and that row keeps every field the call does not name. Returns the whole row.
- **read** returns one item per row, each with `at`: the time the store kept it. No rows is no
  items, so set *Always Output Data* on a caller that must go on.
- **drop** returns `{ dropped }`. A keyed row is the newest word on its subject and has no age:
  only added rows go.

The Google Sheets store hands every value back as text; the HTTP store hands back what was kept.
A caller that counts wraps the field in `Number()`.

## Google Sheets store

The header row decides the columns: a field is written under the column of the same name, and a
field with no column stops the run. Row 1 of every tab starts with `at`.

**The append is a raw HTTP call, not the Google Sheets node. Do not "simplify" it back.**
Concurrent appends are only safe if Google is told to *insert* rows rather than compute a free
slot: `insertDataOption=INSERT_ROWS` on `spreadsheets.values.append`. The n8n Google Sheets node
never sends that parameter, so two overlapping writes target the same row and one is silently
overwritten while the API reports success for both.

Measured firing truly parallel visits at a live webhook:

| Write path | Result |
|------------|--------|
| Sheets node, default | **2 of 8 landed** — 6 silently lost |
| Sheets node, `useAppend: true` | 7 of 8 landed — 1 silently lost |
| HTTP + `insertDataOption=INSERT_ROWS` | **16 of 16, 12 of 12, 10 of 10 — zero lost** |

`valueInputOption=RAW` is the second half: a visitor controls what a form or a link label says,
and under `USER_ENTERED` a value of `=1+1` would be stored as a live formula.

## HTTP store

Three calls on any server that answers them, behind one bearer token:

```
POST   {records_url}/{table}            { "row": {…}, "key": "<the key field's value, or empty>" }
GET    {records_url}/{table}?since=     { "records": [{ "at", "key", "row" }] }
DELETE {records_url}/{table}?before=    { "dropped": n }
```

Each request is tried five times, five seconds apart, so a short outage of the server costs
nothing. A longer one fails the caller, and the error workflow says so. `drop` is one request
with no Code node on its path.

Setup steps are on the yellow sticky note in each workflow.
