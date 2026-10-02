## Auto-File Email Attachments to Google Drive

Reads each email's attachments, files financial documents to a dated Drive folder (`Accounting/2026/05_May/Expense/`) and records the invoice in Google Sheets.

### How it works
1. The Gmail trigger picks up each new email and tags it `inProgress`.
2. *any-file2json-converter* turns attachments (PDF, images, documents) into text.
3. An LLM classifies the email: financial, actionable, informational or other.
4. For financial emails, a second LLM extracts the invoice data.
5. *gdrive-recursion* finds or creates the folder. The file is saved and the email tagged `gdr`.
6. One row per invoice goes to `Billing_Ledger` and a report to Telegram. The email is tagged `n8n`.

### Setup
Each step in detail: [setup-guide.md](https://github.com/runfish5/micro-services/blob/main/projects/n8n/04_inbox-attachment-organizer/docs/setup-guide.md)
- [ ] Import and publish `any-file2json-converter` and `gdrive-recursion`, then select them in **Create Attachment Profile** and **Call 'gdrive-recursion'**
- [ ] Contact branch: import the project 02 workflows, or disable **Call 'record-search'**, **Prepare Contact Input** and **Call 'smart-CRM-fill'**
- [ ] Connect Google OAuth (Gmail, Drive, Sheets) and your LLM credential
- [ ] Create the Gmail labels `inProgress`, `n8n` and `gdr`, and set them in **Set File ID**, **Tag n8n** and **Tag gdr**
- [ ] Create the sheets `Billing_Ledger` and `PathToIDLookup`
- [ ] Set `owner_name` in **Set File ID** and `root_folder_id` in **Call 'gdrive-recursion'**
- [ ] Connect a Telegram bot, or disable **Telegram & done**
- [ ] Publish, then send yourself an email with an invoice attached

### Customization
- Mail already in the mailbox: run `gmail-processor-datesize`. The trigger only sees new mail.
- Other document types: extend the schema in **output profile**.

📂 **[Full docs and source code on GitHub](https://github.com/runfish5/micro-services/tree/main/projects/n8n/04_inbox-attachment-organizer)**
