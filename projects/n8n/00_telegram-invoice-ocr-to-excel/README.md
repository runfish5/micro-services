# Telegram Invoice OCR to Excel

Send invoice photos via Telegram, get structured data in Google Sheets automatically.

## Workflow Preview

<p align="center">
  <img src="assets/cover.png" alt="Workflow Preview">
</p>

📸 Photo input via Telegram
🔍 OCR text extraction
📊 Structured data to Sheets

---

## 🌟 Use Cases

**Out-of-the-box:** Invoices, receipts (via Telegram photo)

**Alternatives:** Business cards, handwritten notes, menus, price tags

## What it does

**📸 Send** → Snap a photo, send via Telegram
**🔍 OCR** → Gemini extracts text from the image
**🧠 Parse** → LLM converts text to structured invoice data
**📊 Store** → Appends extracted fields to Google Sheets
**💬 Confirm** → Sends summary back via Telegram

## Who it's for

Anyone needing to digitize paper invoices or receipts quickly via mobile — freelancers, small business owners, accountants.

## ⚡ Quick Start

1. Copy the JSON workflow into n8n (`Ctrl+V` on canvas)
2. Configure Telegram bot credentials
3. Configure Google Gemini API
4. Configure Google Sheets connection
5. Update the target spreadsheet ID

Need help with credentials? See [credentials-guide.md](../credentials-guide.md)

## 📦 Requirements

- n8n ([cloud](https://n8n.cloud) or [self-hosted](https://youtu.be/kq5bmrjPPAY))
- Telegram Bot API
- Google Gemini API
- Google Sheets (with service account)

---

## n8n Template Description

> Copy this when submitting to n8n.io/workflows

### Who is this for?
Freelancers, small business owners, and home accountants who want to digitize paper invoices and receipts without manual data entry.

### What it does
Send a photo of any invoice or receipt to your Telegram bot. The workflow will:
1. Extract text using Gemini Vision OCR
2. Parse into structured JSON (supplier, amount, date)
3. Append to your Google Sheets ledger
4. Send a confirmation message back

### How to set up
1. Create a Telegram bot via @BotFather
2. Get a Google Gemini API key (free tier works)
3. Set up a Google Service Account and share your Sheet
4. Update the Sheet ID and chat IDs in the workflow

### Requirements
- Telegram Bot token
- Google Gemini API key
- Google Service Account with Sheets access

### How to customize
- Edit the prompt in "Parse Invoice to JSON" for different fields
- Modify column mappings in "Write to Billing Ledger"
- Change the message format in "Format Notification"
