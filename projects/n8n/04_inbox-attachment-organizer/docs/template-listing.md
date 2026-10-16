# Creator-portal listing: inbox-attachment-organizer

The fields exactly as they are pasted into the n8n creator portal. Rules and limits:
[`../../docs/template-submission.md`](../../docs/template-submission.md). The main sticky lives only
in the workflow JSON.

| Field | Words | Limit |
|---|---|---|
| Quick overview | 39 | 10–50 |
| How it works | 106 | 50+ |
| Setup | 110 | 50+ |

## Title

File invoice emails to Google Drive and Google Sheets

## Quick overview

Files the invoices and receipts that arrive by email. An LLM classifies every email, extracts the invoice data from each attachment, saves the document to a dated Google Drive folder and writes one row per invoice to Google Sheets.

## How it works

1. A Gmail trigger picks up each new email, skips promotions and tags it `inProgress`.
2. The any-file2json-converter subworkflow turns every attachment (PDF, image, document) into text; images go through a vision-capable LLM.
3. An LLM classifies the email as financial, actionable, informational or other.
4. For a financial email, a second LLM extracts the invoice data, the document type and the filing date.
5. The gdrive-recursion subworkflow finds or creates the folder, such as `Accounting/2026/05_May/Expense/`, and the file is saved there.
6. One row per invoice goes to the `Billing_Ledger` sheet, a report goes to Telegram, and the email is tagged `n8n`. An email still tagged `inProgress` is a failed run.

## Setup

- Import and publish the four subworkflows: any-file2json-converter, gdrive-recursion, record-search and smart-CRM-fill. Select each one in the node that calls it.
- Connect one Google OAuth credential (Gmail, Drive, Sheets) and an LLM credential.
- Create the Gmail labels `inProgress`, `n8n` and `gdr`, then enter the `inProgress` label ID and your name in Set Run Config.
- Create the `Billing_Ledger` and `PathToIDLookup` sheets (header rows are in the setup guide) and set your `/Accounting` folder ID in Find or Create Drive Folder.
- Optional: connect a Telegram bot and set the chat ID in Send Completion Message, or disable that node.
- After the first run, import gmail-processor-datesize to catch up mail already in the inbox.

## Requirements

- Gmail, Google Drive and Google Sheets, all on one Google OAuth credential
- An LLM API key with a vision-capable model
- Optional: a Telegram bot
- Standard n8n nodes only: runs on n8n Cloud and self-hosted

## Customization

Without a contact sheet, disable the three nodes of the contact section. For other document types (contracts, reports), add them to Classifier Output Schema and add a branch for each to Route by Email Category.

## Additional info

A free LLM tier covers new mail; catching up a large backlog needs a paid tier. Setup guide, schemas and source: [github.com/runfish5/micro-services](https://github.com/runfish5/micro-services/tree/main/projects/n8n/04_inbox-attachment-organizer).
