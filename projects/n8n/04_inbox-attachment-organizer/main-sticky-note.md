## Auto-File Email Attachments to Google Drive

Reads email attachment content, extracts key data to determine filing location (Accounting/2025/05_May/Expense/), and records details to Google Sheets.

### How it works
1. Monitors Gmail for new emails with attachments
2. Classifies documents (invoice, receipt, confirmation, newsletter, etc.)
   - *any-file2json-converter*: Extracts text from PDFs, images (OCR), and documents
3. For financial documents, verifies sender whitelist and extracts structured data
4. Files attachments to organized Google Drive folders (Accounting/2025/05_May/Expense/)
   - *gdrive-recursion*: Locates or creates correct folder structure
5. Logs invoice details to Google Sheets
6. Sends notifications via Telegram

### Setup
- [ ] Import all 5 workflows (1 main + 2 subworkflows + 1 recursive + 1 batch processor) · [with triggers on github](https://github.com/runfish5/micro-services/tree/main/projects/n8n/3_inbox-attachment-organizer/workflows/subworkflows)
- [ ] Connect Google OAuth (Gmail + Drive + Sheets)
- [ ] Add AI provider credentials (Groq or Gemini)
- [ ] Create Gmail label `inProgress` and update Set File ID (see setup-guide.md step 3)
- [ ] Create Google Sheet named "Billing_Ledger" with required columns (see setup-guide.md)
- [ ] Create Google Sheet named "PathToIDLookup" in root directory (columns: path, folder_id, child_ids, last_update)
- [ ] Download and upload folder structure template to Google Drive
- [ ] Configure sender whitelist: add your own email address to test
- [ ] Activate Gmail trigger

- [ ] Test: forward an existing invoice email with attachments to yourself

---
#### After First Run
- [ ] Run `gmail-processor-datesize` workflow to clean up and process all existing emails/attachments in your inbox for a truly organized system (the Gmail trigger only catches new incoming emails)
- [ ] Connect Telegram bot for notifications

---
📂 **[View full docs & source code on GitHub →](https://github.com/runfish5/micro-services/tree/main/projects/n8n/3_inbox-attachment-organizer)**
