# Testing the Gmail Systematic Processor

Step-by-step guide for testing the `3_inbox_Gmail_Systematic_Processor` workflow without affecting production emails.

## 1. Before you start

- Send 1-2 emails **to yourself** with a PDF attachment (invoice, receipt, anything).
- In the **Set Label Variable** node, add your own email address to `email_whitelist` so the If node doesn't skip your test messages.

## 2. Set test_limit

In **Set Label Variable**, change `test_limit` from `0` to a small number like `2`.

- `0` = production mode (fetches up to 500 emails per date chunk)
- `1`, `2`, `3` = fetch only that many emails per chunk

This keeps test runs fast and avoids processing your entire inbox.

## 3. Shrink the date range

In the **Set Date-Range to process** Code node, change:

```js
const startDate = daysAgo(9);
```

to:

```js
const startDate = daysAgo(1);
```

This limits the scan to yesterday + today only.

## 4. Disable Analyze file (optional)

If you just want to verify the fetch/filter/label logic without triggering the full classifier subworkflow, **disable** the Analyze file node (right-click > Disable).

Mark as Processed will still run, so you can confirm labeling works independently.

## 5. Run and inspect

Click **Execute Workflow**, then click each node to see its output:

- **Get many messages** - should return at most `test_limit` emails per chunk
- **Edit Fields** - should show extracted `id` and `from-address`
- **If** - should route your whitelisted emails to the True branch
- **Mark as Processed** - should apply the `GdriveFiled` label

## 6. Clean up labels

After testing, remove the `GdriveFiled` label from your test emails. Two options:

**Option A** - Enable the **Remove label from message** node in the workflow and re-run. It's wired after Mark as Processed but disabled by default.

**Option B** - In Gmail, search `label:GdriveFiled`, select all results, click the label icon, and uncheck `GdriveFiled`.

## 7. Go to production

Restore all test settings:

- Set `test_limit` back to `0`
- Restore `daysAgo(9)` in the Code node
- Re-enable Analyze file (if you disabled it)
- Disable Remove label from message (if you enabled it)
