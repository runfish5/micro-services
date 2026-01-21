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
