# n8n Workflow Patterns Reference

Apply when redesigning or debugging workflows. Stop reading if not relevant.

## Index

| Pattern | Use When |
|---------|----------|
| [Row Index](#pattern-1-row-index) | Batch table ops, wrong row deleted, data lost after API |
| [Wait Optimization](#pattern-2-wait-optimization) | `Code→If→Wait→end` bloat, rate limits |

---

## Pattern 1: Row Index

**Problem:** Data identity lost when processing table rows through multiple nodes. Google Sheets Append/HTTP nodes return API responses, not original data. Causes wrong row deletions/updates.

**Solution:** Assign `_rowIndex` immediately after reading table. Preserve through flow. Use for operations.

### Implementation

After Read Table node:
```javascript
return $input.all().map((item, index) => ({
  json: { ...item.json, _rowIndex: index + 2 }  // +2 for header row
}));
```

Preserve in transforms (always spread):
```javascript
return [{ json: { ...$json, newField: value } }];  // Good - keeps _rowIndex
// NOT: return [{ json: { onlyThis: value } }];    // Bad - loses _rowIndex
```

### Critical: Row Shift on Delete

Deleting row 3 makes row 4 become row 3. **Sort descending before batch delete:**
```javascript
return $input.all().sort((a, b) => b.json._rowIndex - a.json._rowIndex);
```

### Node Reference Ordering

Reference nodes must be BEFORE data-losing operations:
```
BAD:  PrepareData → Append (loses data) → Delete (refs PrepareData - BROKEN)
GOOD: PrepareData → SaveForDelete → Append → Delete (refs SaveForDelete - WORKS)
```

### When to Apply
- Reading table for batch processing
- Items will be updated/deleted later
- Data flows through API calls, Google Sheets, HTTP nodes
- Using Split In Batches / Loop Over Items

---

## Pattern 2: Wait Optimization

**Problem:** Rate limits or polling issues lead to bloated sequences:
```
Code Node → If Node → Wait Node → end
```

**Solution:** If Code node already exists before the If, consolidate delay logic into JavaScript.

### Implementation

Conditional delay inside Code node:
```javascript
if (shouldWait) {
  await new Promise(resolve => setTimeout(resolve, 1000));
}
return items;
```

Early return (skip Wait entirely):
```javascript
if (noMoreWorkNeeded) {
  return [];  // Ends branch - no Wait needed
}
return items;
```

Rate limiting inside loop:
```javascript
const results = [];
for (const item of $input.all()) {
  const response = await fetch(/* ... */);
  results.push({ json: response });
  await new Promise(resolve => setTimeout(resolve, 200));  // Delay between calls
}
return results;
```

### When to Apply
- See `Code → If → Wait → end` sequence
- Code node already exists at that position
- Wait is conditional (not always needed)

### When NOT to Apply
- No Code node exists (don't add one just for this)
- Wait is unconditional for all items
- Need n8n Wait features (webhook resume, specific datetime)

---

## Quick Decision Guide

| Symptom | Pattern | Fix |
|---------|---------|-----|
| Wrong row deleted/updated | Row Index | Add `_rowIndex` after read, sort DESC before delete |
| Data lost after API call | Row Index | Spread `...$json` or add SaveForDelete node before |
| `Code→If→Wait→end` bloat | Wait Optimization | Move delay into Code node |
| Rate limit errors | Both | Code node with delay loop + preserve indices |
