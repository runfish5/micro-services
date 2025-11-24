## Auto-File Email Attachments to Google Drive

### How it works
1. Monitors Gmail for new emails with attachments
2. Classifies documents (invoice, receipt, confirmation, newsletter, etc.)
3. For financial documents, extracts structured data and verifies sender
4. Files attachments to organized Google Drive folders (Accounting/2025/05_May/Expense/)
5. Logs invoice details to Google Sheets
6. Sends notifications via Telegram

### Setup
- [ ] Import all 5 workflows (main + 4 subworkflows)
- [ ] Connect Google OAuth (Gmail + Drive + Sheets)
- [ ] Add AI provider credentials (Groq or Gemini)
- [ ] Create Google Sheet named "2505_Invoices" with required columns
- [ ] Download and upload folder structure template to Google Drive
- [ ] Configure sender whitelist: add your own email address to test
- [ ] Test: forward an existing invoice email with attachments to yourself
- [ ] Optional: Run `gmail-systematic-processor` workflow to clean up and process all existing emails/attachments in your inbox for a truly organized system (the Gmail trigger only catches new incoming emails)
- [ ] Optional: Connect Telegram bot for notifications
- [ ] Activate Gmail trigger
