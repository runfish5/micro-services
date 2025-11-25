# 🔄 Main Flow (39 Nodes Total)
📋 Workflow Overview

This workflow automates the entire invoice processing
  pipeline from email receipt to organized storage with
  minimal human intervention.


## 🎯 Workflow Flow Summary


### Phases:
```
Email Monitoring (1-6)
Attachment Processing (7-15)
LM1: AI Classification (16)
Routing & Filtering (17-23)
Deep Invoice Extraction (24-34)
LM2: detailed invoice data (28)
Storage & Logging (29, 31, 33)
Notifications (23, 34)
Alternative Entry (2)
```

### Data Flow

Note: This particular telegram cohnfiguration must still be implemented.
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


### Key Workflow Logic
```
  Flow Summary:
  Gmail → Filter Promotions → Extract Attachments
    ↓
    ├─ No Attachments → Clean Text
    └─ Has Attachments → Convert to Text → Aggregate
    ↓
  LM1: AI Classify → Determine Document Type
    ↓
  Is Financial? → Check Whitelist → Deep Extract (Llama 4)
    ↓
  LM2: Accountant Info Extraction → Upload to Drive → Log to Sheets →
  Notify Telegram
```

### Lineage logging
```
START: Gmail Trigger
  │
  ├→ Stop promotions (filter)
  ├→ Set File ID
  ├→ Gmail (get full email + attachments)
  ├→ Get binary data
  └→ Empty? (check attachments)
     │
     ├─ NO ATTACHMENTS:
     │  ├→ Code in JavaScript1 (clean text)
     │  └→ new section *16
     │     (subject-classifier-LM)
     │
     └─ HAS ATTACHMENTS:
        ├→ sp (split attachments)
        ├→ Loop Over Items
        │  ├→ Clean Email Text
        │  ├→ Analyze file (convert to text)
        │  └→ Merge
        ├→ Aggregate1 (combine all)
        ├→ attachement_as_text
    *16 └→ subject-classifier-LM
           │
           ├→ non-spam lineage
           └→ financial doc router
              │
              └─ IF FINANCIAL:
                 ├→ user_email__whitelist
                 ├→ whitelist validator
                 │  ├→ format rejection
                 │  └→ notify rejection
                 ├→ verify sender

    *24          ├→ extract attachments
                 ├→ prepare attachment meta
                 ├→ split attachments
                 └→ loop invoices
                    ├→ Accountant-concierge-LM (deep AI extraction)
                    ├→ prepare folder lookup
                    ├→ Call 'Google Drive Folder Lookup'
                    ├→ get file binary
                    ├→ save doc to folder
                    ├→ insert doc record
                    └→ Telegram & done

```

## 🦜 AI Models Nodes

### 1. Classification
- **Node**: subject-classifier-LM
- **Input**: Email text + attachment content
- **Output**: Document type, action required, Telegram summary
- **Classification Types**:
  - confirmation, financial, newsletter, appointment, marketing, operational, other

### 2. Extraction
- **Node**: Accountant-concierge
- **Input**: Cleaned invoice/receipt text
- **Output**: Structured invoice data with all fields
- **Key Capabilities**:
  - Categorization: Revenue vs Expense
  - Type detection: Invoice vs Receipt
  - Field extraction: dates, amounts, parties, line items

## 🔗 External Workflows Called

### 1. any-file2json-converter
- **Called by**: Analyze file (Node 12)
- **Purpose**: Converts various file formats to text/JSON
- **Supported formats**: PDF, DOCX, images (via OCR), etc.
- **Output**: Extracted text content from documents

### 2. google-drive-folder-id-lookup
- **Called by**: Call 'Google Drive Folder ID Lookup' (Node 32)
- **Purpose**: Finds or creates Google Drive folder structure
- **Requirements**: PathToIDLookup Google Sheet (columns: `path | folder_id | child_ids | last_update`)
- **Input**: Path components (year, month, category)
- **Output**: Folder ID for file upload
- **Behavior**: Creates folders if they don't exist, caches results in PathToIDLookup sheet for performance
- **Uses**: google-drive-folder-id-recursion subworkflow for recursive folder creation

💡 **Design Principle:** Single-provider architecture using Google OAuth (Gmail + Drive + Sheets) eliminates multi-platform authentication complexity. This consolidation reduces deployment overhead from typical 3-5 credential configurations to one.


## 📝 Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive