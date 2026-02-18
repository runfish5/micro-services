# Steward Setup Guide

Post-import checklist for getting the steward workflows running on a fresh n8n instance. Every item here has caused a real failure during development.

## 1. Set Workflow IDs in menu-handler Config

The Config node in `menu-handler.json` registers subworkflows by their n8n workflow ID. After importing, these IDs won't match your instance.

**Where**: menu-handler.json > Config node > `agents` object

| Registry key | Target workflow | What to set |
|---|---|---|
| `expenses.workflowId` | expense-trend-report (project 04) | The deployed workflow's ID |
| `deals.workflowId` | deal-finder (subworkflows/) | The deployed workflow's ID |
| `learning.workflowId` | learning-notes (subworkflows/) | The deployed workflow's ID (see section 6) |

**How to find a workflow ID**: Open the workflow in n8n UI. The ID is in the URL: `https://your-instance.up.railway.app/workflow/<THIS_IS_THE_ID>`.

If a `workflowId` is empty but `ready: true`, the Normalize node will gracefully route to the AI Classifier path instead of crashing. But the skill won't actually dispatch until a valid ID is set.

## 2. Set Google Sheet Document ID

deal-finder and price-checker Config nodes default `sheetId` to `'Steward_Deals'` -- that's a **name**, not an ID. Google Sheets nodes use `mode: "id"` and need the actual document ID.

**Where**: deal-finder.json > Config node > `sheetId` AND price-checker.json > Config node > `sheetId`

**How to find**: Open the Google Sheet. The ID is in the URL:
```
https://docs.google.com/spreadsheets/d/<THIS_IS_THE_ID>/edit
```

**Sheet setup**: Create a Google Sheet with two tabs:
- `Requirements` -- columns: `category`, `constraints`, `max_price`, `priority`, `status`, `recommendations`, `last_researched`
- `Tracked Prices` -- columns: `url`, `product_name`, `domain`, `current_price`, `currency`, `previous_price`, `lowest_price`, `highest_price`, `first_tracked`, `last_checked`, `status`, `notify_mode`, `price_threshold`

Full column schemas are in [mainflow.md](workflows/mainflow.md#google-sheet-schemas).

## 3. Set price-checker Workflow ID in deal-finder

deal-finder's "Execute Price Checker" node has placeholder `YOUR_PRICE_CHECKER_WORKFLOW_ID`.

**Where**: deal-finder.json > "Execute Price Checker" node > `workflowId`

Set this to the deployed price-checker.json workflow ID (found the same way as step 1).

## 4. Publish All Subworkflows

Draft workflows cannot receive Execute Workflow calls. After importing, each subworkflow must be **published**:

- [ ] deal-finder.json
- [ ] price-checker.json
- [ ] expense-trend-report.json (project 04)
- [ ] learning-notes.json

If publish fails with "1 node has issues", go to Executions > pick a successful run > Copy to Editor > Publish.

## 5. Set Credential IDs

All committed JSON files use `CREDENTIAL_ID_*` placeholders. After importing, n8n auto-assigns credential IDs. Verify each node's credential is correctly linked.

| Credential | Used by | Placeholder |
|---|---|---|
| Telegram Bot | menu-handler, Send Reply, deal-finder, learning-notes | `CREDENTIAL_ID_TELEGRAM` |
| Groq API | Classifier LLM, Reasoning LLM | `CREDENTIAL_ID_GROQ` |
| Postgres | Router Memory, learning-notes memory | `CREDENTIAL_ID_POSTGRES` |
| Brave Search (Header Auth) | Brave Search HTTP Request | `CREDENTIAL_ID_BRAVE_SEARCH` |
| Perplexity | Perplexity Research, deal-finder | `CREDENTIAL_ID_PERPLEXITY` |
| Google Sheets OAuth | deal-finder, price-checker | `CREDENTIAL_ID_GOOGLE_DRIVE` |
| Notion | learning-notes | `CREDENTIAL_ID_NOTION` |
| Google Gemini | learning-notes | `CREDENTIAL_ID_GEMINI` |

For Brave Search specifically: create a **Header Auth** credential with Name: `X-Subscription-Token`, Value: your API key.

See [credentials-guide.md](../../credentials-guide.md) for detailed setup instructions.

## 6. Set learning-notes Workflow ID

learning-notes is now enabled (`ready: true`) in the Config registry. Update the placeholder:

**Where**: menu-handler.json > Config node > `learning.workflowId`

Replace `YOUR_LEARNING_NOTES_WORKFLOW_ID` with the deployed learning-notes.json workflow ID.

**Prerequisites**: Verify Notion, Gemini, Postgres, and Telegram credentials are linked in the learning-notes workflow.

## 7. Verify alwaysOutputData on Google Sheets Nodes

deal-finder.json has `alwaysOutputData: true` on these Google Sheets nodes to prevent silent failures on empty sheets:

- `Load Requirements` -- empty Requirements tab on digest
- `Load for Modify` -- empty Requirements tab on remove/pause/resume
- `Load Tracked for Untrack` -- empty Tracked Prices tab on untrack
- `Load All Tracked` -- already had it

If you re-import deal-finder, verify these flags survive the import. n8n's UI doesn't expose `alwaysOutputData` directly -- check the JSON.
