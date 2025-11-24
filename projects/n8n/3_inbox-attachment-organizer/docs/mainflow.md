# 🔄 Main Flow (39 Nodes Total)
📋 Workflow Overview

This workflow automates the entire invoice processing
  pipeline from email receipt to organized storage with
  minimal human intervention.


## 🎯 Workflow Flow Summary

Key Workflow Logic
```
  Flow Summary:
  Gmail → Filter Promotions → Extract Attachments
    ↓
    ├─ No Attachments → Clean Text
    └─ Has Attachments → Convert to Text → Aggregate
    ↓
  AI Classify (Gemini) → Determine Document Type
    ↓
  Is Financial? → Check Whitelist → Deep Extract (Llama 4)
    ↓
  Organize Folders → Upload to Drive → Log to Sheets →
  Notify Telegram
```
It is comprised of:
```
Email Monitoring (1-5)
Attachment Processing (6-15)
AI Classification First Pass (16-18)
Routing & Filtering (19-23)
Deep Invoice Extraction (24-28)
detailed invoice data (29-30)
Storage & Logging (31-35)
Notifications (36-38)
Alternative Entry (39)
```

lineage logging
```
START: Gmail Trigger (Every 1 minute)
  │
  ├→ Stop promotions (filter)
  ├→ Set File ID
  ├→ Gmail (get full email + attachments)
  ├→ Get binary data
  ├→ Edit Fields
  └→ Empty? (check attachments)
     │
     ├─ NO ATTACHMENTS:
     │  ├→ Code in JavaScript1 (clean text)
     │  └→ subject-classifier-LM (AI classify)
     │
     └─ HAS ATTACHMENTS:
        ├→ sp (split attachments)
        ├→ Loop Over Items
        │  ├→ Clean Email Text
        │  ├→ Analyze file (convert to text)
        │  └→ Merge
        ├→ Aggregate1 (combine all)
        ├→ attachement_as_text
        └→ subject-classifier-LM (AI classify)
           │
           └→ Switch (check if financial)
              │
              └─ IF FINANCIAL:
                 ├→ Accounting-email-List (whitelist check)
                 ├→ Switch2 (verify sender)
                 ├→ binary_data
                 ├→ Edit Fields2
                 ├→ Split Out
                 └→ Loop Over Items1
                    ├→ Accountant-concierge (deep AI extraction)
                    ├→ Edit Fields1
                    ├→ Google Drive Folder Lookup
                    ├→ binary_data_files
                    ├→ Upload file to Drive
                    ├→ Google Sheets2 (log data)
                    ├→ Telegram1 (notify type)
                    ├→ Switch3
                    ├→ Edit Fields5
                    └→ Telegram (final notification)
```
  AI Models Used:
  - Google Gemini 2.5: Initial classification &
  summarization
  - Groq Llama 4: Deep invoice data extraction

  External Workflows Called:
  1. "Any-file2json converter" - Converts various file
  formats to text
  2. "Google Drive Folder ID Lookup" - Creates/finds
  folder structure
```
  Storage Structure:
  /Accounting/
    └─ 2025/
        └─ 05_May/
            ├─ Revenue/
            └─ Expense/
```

## 🤖 AI Models & Their Roles

### 1. Google Gemini 2.5 (Classification)
- **Node**: subject-classifier-LM
- **Purpose**: First-pass document classification
- **Input**: Email text + attachment content
- **Output**: Document type, action required, Telegram summary
- **Classification Types**:
  - confirmation
  - financial
  - newsletter
  - appointment
  - marketing
  - operational
  - other

### 2. Groq Llama 4 Maverick (Extraction)
- **Node**: Accountant-concierge
- **Model**: meta-llama/llama-4-maverick-17b-128e-instruct
- **Purpose**: Deep invoice data extraction
- **Input**: Cleaned invoice/receipt text
- **Output**: Structured invoice data with all fields
- **Key Capabilities**:
  - Categorization: Revenue vs Expense
  - Type detection: Invoice vs Receipt
  - Field extraction: dates, amounts, parties, line items
  - Swiss business context awareness

---

## 🔗 External Workflows Called

### 1. Any-file2json converter
- **Called by**: Analyze file (Node 12)
- **Purpose**: Converts various file formats to text/JSON
- **Supported formats**: PDF, DOCX, images (via OCR), etc.
- **Output**: Extracted text content from documents

### 2. Google Drive Folder ID Lookup
- **Called by**: Call 'Google Drive Folder ID Lookup' (Node 32)
- **Purpose**: Finds or creates Google Drive folder structure
- **Input**: Path components (year, month, category)
- **Output**: Folder ID for file upload
- **Behavior**: Creates folders if they don't exist

---

## 📊 Data Flow

```
Email → Text Extraction → AI Classification
                              ↓
                         Is Financial?
                              ↓
                      Whitelist Check
                              ↓
                      AI Deep Extraction
                              ↓
                    ┌─────────┴──────────┐
                    ↓                    ↓
              Google Drive          Google Sheets
              (Organized)            (Logged)
                    │                    │
                    └─────────┬──────────┘
                              ↓
                      Telegram Notification
```

## 📝 Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive