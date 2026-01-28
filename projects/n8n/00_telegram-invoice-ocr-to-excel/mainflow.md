# Main Flow (14 Nodes)

> Last verified: 2026-01-16

## Overview
Telegram bot that extracts structured invoice data from photos using OCR and LLM, then logs results to Google Sheets.

## Flow Summary

### Phases
```
Trigger & Input (Nodes 1-4)
  - Telegram → Photo download → Image conversion
OCR Processing (Nodes 5-6)
  - Vision LLM extracts text from image
Data Extraction (Nodes 7-11)
  - LLM converts text to structured JSON → Edit Fields cleanses JSON
Output & Storage (Nodes 12-14)
  - Write to Google Sheets → Format summary → Send Telegram notification
```

### Data Flow
```
Telegram Trigger → Telegram1 (get photo) → conversion (edit image)
                                                ↓
                                         Image-to-text (Gemini Vision)
                                                ↓
                                         Basic LLM Chain (extract to JSON)
                                                ↓
                                         Edit Fields (clean JSON)
                                         ↓              ↓
                               Google Sheets    Edit Fields1 (format message)
                                                        ↓
                                                  Telegram2 (notify)
```

### Lineage Tree
```
START: Telegram Trigger1 (message with photo)
  │
  └→ Telegram1 (download photo file)
       │
       └→ conversion (edit image - border processing)
            │
            └→ Image-to-text (chainLlm with image binary input)
                 ├─ Google Gemini Chat Model1 (gemini-2.5-flash-preview)
                 │
                 └→ Basic LLM Chain (text to JSON extraction)
                      ├─ Google Gemini Chat Model (gemini-2.5-flash-preview)
                      │
                      └→ Edit Fields (strip ```json markdown, parse as object)
                           ├─ Google Sheets (append invoice data)
                           │
                           └→ Edit Fields1 (format notification message)
                                │
                                └→ Telegram2 (send confirmation)

Disabled branches:
  - Basic LLM Chain1 → Google Gemini Chat Model2 (alternative extraction path)
```

## AI Model Nodes

### 1. Image-to-text (OCR)
- **Node**: Image-to-text
- **Model**: Google Gemini 2.5 Flash Preview (`models/gemini-2.5-flash-preview-05-20`)
- **Input**: Photo binary from Telegram
- **Output**: Raw text extracted from invoice image
- **Purpose**: Precision OCR - extract all visible text while maintaining reading order

### 2. Basic LLM Chain (Data Extraction)
- **Node**: Basic LLM Chain
- **Model**: Google Gemini 2.5 Flash Preview
- **Input**: OCR text
- **Output**: Structured JSON with invoice fields
- **Purpose**: Extract standard invoice fields (supplier_name, invoice_date, total_amount_due, currency_code, payment_method, etc.) with snake_case keys in English

### 3. Basic LLM Chain1 (Disabled)
- **Node**: Basic LLM Chain1
- **Model**: Google Gemini 2.5 Flash Preview
- **Purpose**: Alternative extraction path with simpler prompt (not currently used)

## Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Telegram Trigger1 | telegramTrigger | Listens for incoming messages with photos |
| 2 | Telegram1 | telegram | Downloads photo file from Telegram |
| 3 | conversion | editImage | Adds 1px border to image (format processing) |
| 4 | Image-to-text | chainLlm | OCR extraction using vision LLM |
| 5 | Google Gemini Chat Model1 | lmChatGoogleGemini | Vision model for OCR |
| 6 | Basic LLM Chain | chainLlm | Converts OCR text to structured JSON |
| 7 | Google Gemini Chat Model | lmChatGoogleGemini | Text model for extraction |
| 8 | Edit Fields | set | Strips markdown formatting from JSON response |
| 9 | Google Sheets | googleSheets | Appends extracted data to Billing_Ledger sheet |
| 10 | Edit Fields1 | set | Formats Telegram notification message |
| 11 | Telegram2 | telegram | Sends confirmation with extracted data preview |
| 12 | Basic LLM Chain1 | chainLlm | Alternative extraction path (disabled) |
| 13 | Google Gemini Chat Model2 | lmChatGoogleGemini | Alternative model (disabled) |
| 14 | Google Gemini Chat Model (unused) | lmChatGoogleGemini | Placeholder node |

## Notes
- Chat ID for Telegram bot: `7281469586` (see Telegram Trigger1 notes)
- Google Sheets document: `Billing_Ledger` (ID: `1ZfqdUCMMWFvN-AMUKL7n-TIbSZAer3fqiH6Oy03tM94`)
- Output columns mapped: supplier_name, supplier_address, invoice_date, total_amount_due, currency_code, subtotal_amount, recipient_business_name, payment_method, date_paid, payment_reference
- Edit Fields node uses regex to strip markdown code blocks: `.replace(/^(```json\\n)?(.*?)(\\n```)?$/s, '$2')`
- Uses Telegram photo array index `[3]` for highest resolution
- Telegram2 notification includes: timestamp, truncated JSON preview (first 1000 chars), formatted with line breaks

---
