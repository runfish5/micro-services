# This n8n workflow demonstrates how to use AI to automatically process incoming email attachments, extract invoice data with precision, and organize financial documents into a structured accounting system.

This n8n workflow handles email attachments automatically. It reads any format (images, PDFs, documents) using AI, extracts key information, and files everything to the correct date-based Google Drive folder.

Perfect for organizing receipts, invoices, or any email attachments without manual sorting. The AI determines the category (Expense/Revenue) and filing date (e.g., Accounting/2025/02_February/Expense/) by reading the actual document content—even from images.

> ### ⚡ Why This Workflow Is Different
>
> * **ONE Google OAuth connection** (Gmail + Drive + Sheets) — not 3-5 platforms.
> * **Standard n8n cloud nodes only** — no self-hosted requirements or community node dependencies.
>
> --> ⏱ **Setup in minutes** if n8n already connected to google account.

**Good to know**

* Reads and understands all formats: Images (through Gemini Flash's free OCR + vision), PDFs (text extraction), JSON (direct parsing), etc.
* Auto-creates folder structure: `Accounting/YYYY/MM_Month/Category/`.
* Easily extensible: Add new document types and categories via the structured output parser schema.
* Optional Telegram notifications with document summary.

# How it works

* Gmail trigger polls inbox every minute and filters promotional emails.
* "any-file2json-converter" subworkflow extracts and understands content from all attachments.
* Subject Classifier categorizes emails into types: financial, confirmation, appointment, marketing, operational, newsletter, or other.
* Accountant Concierge extracts year/month from document, and identifies document type (Invoice/Receipt).
* "google-drive-folder-id-lookup" subworkflow handles the n8n-Google Drive communication workaround to locate correct folders.
* Files upload to correct location with full metadata logging in Google Sheets.
* Optional: Telegram notifications.

# How to use

* Connect your Google account (Gmail, Drive, Sheets) - this is the only authentication needed if you already have n8n running
* Optional: Configure Telegram for notifications and adjust folder structure template

# Requirements

* Gmail, Google Drive and Google Sheets
* LLM provider: Groq (free) or Google Gemini (free tier)
* Optional: Telegram bot token

# Customising this workflow

This workflow solves financial document filing out-of-the-box. To handle non-financial emails (contracts, reports, customer inquiries), simply add new modules by extending the document type categories in the structured output parser schema.
