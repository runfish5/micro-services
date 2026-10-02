# Auto-file email attachments to Google Drive with AI

This workflow reads the attachments of every incoming email (images, PDFs, documents), extracts the invoice data and files each document to the right dated Google Drive folder.

It suits receipts, invoices and any other attachment you would otherwise sort by hand. The AI reads the document itself, also from an image, and decides the category (Expense or Revenue) and the filing date (for example `Accounting/2026/02_February/Expense/`).

> ### ⚡ Why This Workflow Is Different
>
> * **One Google OAuth connection** covers Gmail, Drive and Sheets. Besides that you need an LLM API key.
> * **Standard n8n nodes only**: no community nodes, runs on n8n Cloud and self-hosted.

**Good to know**

* Reads all common formats: images (vision-capable LLM), PDFs and documents (text extraction), JSON.
* Creates the folder structure on demand: `Accounting/YYYY/MM_Month/Category/`.
* One ledger row per invoice: an invoice and its receipt share a row.
* Telegram report per filed document (optional).
* A free LLM tier is enough for new mail. Catching up a backlog of old mail needs a paid tier.

# How it works

* The Gmail trigger checks the inbox every minute and skips promotions.
* The `any-file2json-converter` sub-workflow turns each attachment into text.
* **subject-classifier-LM** sorts the email into financial, actionable, informational or other.
* For financial emails, **Accountant-concierge-LM** extracts the invoice data, the document type (invoice or receipt) and the year and month for filing.
* The file is saved to Drive and the invoice is written to Google Sheets.
* Gmail labels show the state of every email: `inProgress` while a run is going, `n8n` when it finished, `gdr` when a file was saved.

# How to use

* Import this workflow and its sub-workflows `any-file2json-converter` and `gdrive-recursion`.
* Connect your Google account (Gmail, Drive, Sheets) and your LLM credential.
* Create three Gmail labels and two Google Sheets, and enter your Drive folder ID.
* Each step in detail: [setup guide](https://github.com/runfish5/micro-services/blob/main/projects/n8n/04_inbox-attachment-organizer/docs/setup-guide.md).

# Requirements

* Gmail, Google Drive and Google Sheets
  * Two Google Sheets: `Billing_Ledger` (the invoice ledger) and `PathToIDLookup` (folder cache, fills itself)
* An LLM API key with one vision-capable model
* Optional: Telegram bot

# Customising this workflow

The workflow files financial documents out of the box. To handle other emails (contracts, reports, customer inquiries), add document types to the schema in **output profile** and a branch for each to **financial doc router**.

---

📂 **[Full documentation & source code](https://github.com/runfish5/micro-services/tree/main/projects/n8n/04_inbox-attachment-organizer)**
