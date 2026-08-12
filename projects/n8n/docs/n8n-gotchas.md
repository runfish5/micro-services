# n8n Gotchas & Rare Bugs

Quick reference for rare issues encountered. Not in CLAUDE.md - just personal notes.

---

## If Node v2 vs v3 (2025-01)

The If node has two JSON formats (`version: 2` vs `3`) with different behavior. Version 2 has looser type coercion that routes ALL items to the same branch regardless of actual values.

**Symptoms:**
- If node routes all items to the same output branch
- String comparisons don't differentiate values correctly
- Workflow worked in testing but fails with real data variety

**Fix (easy):** Delete the If node in n8n UI and recreate it. New nodes use v3 by default.

**Fix (manual JSON):**
1. Change `version: 2` → `version: 3`
2. Move `combinator` from inside `options` to be a sibling of `conditions` array
3. Add to `options`: `caseSensitive: true`, `leftValue: ""`, `typeValidation: "strict"`
4. Add `id` field (any UUID) to each condition

<details>
<summary>Version 2 (broken) vs Version 3 (working)</summary>

**Version 2 (broken):**
```json
{
  "conditions": {
    "options": {
      "version": 2,
      "combinator": "and"  // <-- combinator inside options
    },
    "conditions": [...]
  }
}
```

**Version 3 (working):**
```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict",
      "version": 3
    },
    "conditions": [...],
    "combinator": "and"  // <-- combinator outside options
  }
}
```
</details>

---

## Google Sheets v4: `defineBelow` needs `columns.schema` (2026-08)

A hand-authored Sheets node using `mappingMode: "defineBelow"` fails at runtime with:

```
Could not get parameter "columns.schema"
```

The `columns` object needs a **`schema` array** alongside `mappingMode` / `matchingColumns` /
`value`. The n8n UI generates it by reading the sheet's header row, so a node built in the
canvas always has one and a node written directly into JSON never does.

```json
"columns": {
  "mappingMode": "defineBelow",
  "matchingColumns": ["task_id"],
  "value": { "task_id": "={{ $json.taskId }}", "status": "done" },
  "schema": [
    { "id": "task_id", "displayName": "task_id", "type": "string",
      "canBeUsedToMatch": true, "display": true, "required": false,
      "defaultMatch": false, "removed": false },
    { "id": "notes", "displayName": "notes", "type": "string",
      "canBeUsedToMatch": true, "display": true, "required": false,
      "defaultMatch": false, "removed": true }
  ]
}
```

List **every** header column; set `removed: true` on the ones not in `value`.

**`autoMapInputData` needs no schema**, which is what makes this confusing — in
`16_commitments-ledger/commitments.json` the append node worked from day one while the
`appendOrUpdate` node in the same workflow failed on the first real button tap.

Two things made it expensive to diagnose, both worth remembering:

- The message names a *parameter*, not a column or a credential, so it reads like an n8n
  internal fault rather than something missing from your JSON.
- **`continueOnFail` on the calling Execute Workflow node does not contain it.** A sub-workflow
  that fails this way still fails the parent — verified: `menu-handler`'s `Run Skill` carries
  `continueOnFail: true` and the parent execution errored anyway. Do not assume a guarded
  Execute Workflow node makes a broken subworkflow survivable.

---
