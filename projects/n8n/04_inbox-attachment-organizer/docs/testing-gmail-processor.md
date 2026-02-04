# Testing the Gmail Systematic Processor

Step-by-step guide for testing the `gmail-processor-datesize` workflow without affecting production emails.

## 1. Before you start

- Send 1-2 emails **to yourself** with a PDF attachment (invoice, receipt, anything).
- In the **Set Label Variable** node, add your own email address to `email_whitelist` so the If node doesn't skip your test messages.

## 2. Configure for testing

In **Set Label Variable**, change these fields:

| Field | Test value | Why |
|-------|-----------|-----|
| `email_limit` | `2` | Only fetch 2 emails per chunk — keeps test runs fast |
| `lookback_days` | `1` | Only scan yesterday + today |

Leave `batch_mode` as `date` and `interval_days` as `3` for your first test.

### Dry run

Set `email_limit` to `0`. The workflow will execute the setup branch (label creation) but skip all Gmail fetches. Useful for verifying the label logic without touching any emails.

## 3. Disable Analyze file (optional)

If you just want to verify the fetch/filter/label logic without triggering the full classifier subworkflow, **disable** the Analyze file node (right-click > Disable).

Mark as Processed will still run, so you can confirm labeling works independently.

## 4. Run and inspect

Click **Execute Workflow**, then click each node to see its output:

- **Set Date-Range to process** — should show 1 date interval (yesterday to tomorrow)
- **Get many messages** — should return at most 2 emails per chunk
- **Edit Fields** — should show extracted `id` and `from-address`
- **If** — should route your whitelisted emails to the True branch
- **Mark as Processed** — should apply the `GdriveFiled` label

## 5. Second test: size mode

To process emails regardless of when they arrived:

| Field | Value |
|-------|-------|
| `batch_mode` | `size` |
| `email_limit` | `50` |

This fetches up to 50 of your newest emails (single wide date range from 2000 to tomorrow). Good for catching emails that fell outside your `lookback_days` window.

## 6. Clean up labels

After testing, remove the `GdriveFiled` label from your test emails. Two options:

**Option A** — Enable the **Remove label from message** node in the workflow and re-run. It's wired after Mark as Processed but disabled by default.

**Option B** — In Gmail, search `label:GdriveFiled`, select all results, click the label icon, and uncheck `GdriveFiled`.

## 7. Restore production settings

Reset all fields in **Set Label Variable**:

| Field | Production value |
|-------|-----------------|
| `batch_mode` | `date` |
| `email_limit` | `500` |
| `lookback_days` | `1` |
| `interval_days` | `3` |

Also:
- Re-enable Analyze file (if you disabled it)
- Disable Remove label from message (if you enabled it)
