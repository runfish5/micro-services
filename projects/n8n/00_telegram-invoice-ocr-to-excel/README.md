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
