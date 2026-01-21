# Row Index Pattern for Batch Table Operations

## The Problem

When a workflow reads tabular data (from Google Sheets, databases, etc.) and processes items through multiple nodes, **data identity gets lost**. Nodes like Google Sheets Append return API responses, not the original input data. In loops, n8n's item matching (`.item`) can reference the wrong item.

This causes bugs like:
- Deleting the wrong row after processing
- Updating the wrong record
- Losing track of which source row an item came from

## The Solution

**Assign row indices immediately after fetching the table.** Carry these indices through the entire workflow. Use indices for any row-level operations.

```
Read Table → Assign Indices → [... processing ...] → Update/Delete by Index
```

## Implementation

### Step 1: Assign Indices After Read

Add a Code node right after reading the table:

```javascript
// Assign _rowIndex at fetch time
// Google Sheets: row 1 = header, data starts at row 2
return $input.all().map((item, index) => ({
  json: {
    ...item.json,
    _rowIndex: index + 2  // 0-based JS index → 1-based sheet row (+ header)
  }
}));
```

### Step 2: Preserve Through Flow

The `_rowIndex` field flows naturally when you spread the object:

```javascript
// Good - preserves _rowIndex
return [{ json: { ...$json, newField: value } }];

// Bad - loses _rowIndex
return [{ json: { onlyThisField: value } }];
```

### Step 3: Use Index for Operations

Delete by row number instead of matching:
```javascript
// In "Prepare Delete" node before Google Sheets Delete
return [{ json: { _rowIndex: $json._rowIndex } }];
```

Then configure Delete node with `startRowNumber: {{ $json._rowIndex }}`.

## Critical: Row Shift Problem

When you delete row 3, row 4 becomes row 3. If you then try to delete "row 4", you'll delete what was row 5.

**Solution**: Process deletions in reverse order (highest index first).

```javascript
// Sort by _rowIndex descending before Loop Over Items
return $input.all().sort((a, b) => b.json._rowIndex - a.json._rowIndex);
```

Or: Collect all indices to delete, sort descending, delete in one batch.

## When to Use This Pattern

Use row indices when:
- Reading a table for batch processing
- Items will be updated or deleted later
- Data flows through nodes that don't preserve input (API calls, external services)
- Using Split In Batches / Loop Over Items

## Real Example: 8-Hour Incident Resolver

The workflow reads FailedItems, retries each execution, then archives successes and deletes them from the source table.

**Before (buggy)**:
```
Read FailedItems → Filter → Loop → [retry logic] → Delete by execution_id match
```
Problem: After Google Sheets Append (archive), the execution_id reference was lost.

**After (fixed)**:
```
Read FailedItems → Assign Indices → Filter → Sort DESC → Loop → [retry logic] → Delete by _rowIndex
```

The `_rowIndex` is assigned once, preserved through all nodes, and used reliably at delete time.

## Node Reference Ordering

When referencing earlier nodes with `$('NodeName').first().json`, the referenced node must be BEFORE any data-losing nodes (HTTP requests, Google Sheets operations) in the data flow.

**Problem pattern:**
```
PrepareData → Append (loses data) → Delete (references PrepareData - UNRELIABLE!)
```

**Solution pattern:**
```
PrepareData → SaveForDelete → Append (loses data) → Delete (references SaveForDelete - RELIABLE)
```

The key is positioning your "save point" node BEFORE the data-losing operation. When you reference it later, the data is still intact because it was captured before the loss.

## Related Patterns

- **Database transactions**: Similar to assigning row IDs before batch updates
- **Immutable references**: Index is a stable identifier that doesn't change during processing
- **Cursor-based pagination**: Keeping track of position in a dataset
- **Checkpoint/save pattern**: Capture data before operations that don't preserve input
