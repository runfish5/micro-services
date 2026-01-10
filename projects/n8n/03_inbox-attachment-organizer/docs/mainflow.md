# 🔄 Main Flow (30 Nodes)
📋 Workflow Overview

This workflow automates the entire invoice processing
  pipeline from email receipt to organized storage with
  minimal human intervention.


## 🎯 Workflow Flow Summary


### Phases:
```
Email Trigger (Nodes 1-5)
Attachment Processing (Nodes 6-10)
Subject Classifier & Routing (Nodes 11-18)
Deep Invoice Extraction & Storage (Nodes 19-30)
  - LM2: Accountant-concierge-LM
  - Storage: Google Sheets + Google Drive
  - Notifications: Telegram & Gmail labels
Alternative Entry: When Executed by Another Workflow
```

### Data Flow

Note: This particular telegram configuration must still be implemented.
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
  Gmail Trigger → Stop promotions → Set File ID → Gmail (get attachments)
    ↓
  Empty? (check for attachments)
    ├─ No Attachments → Clean Email object
    └─ Has Attachments → sp (split) → Create Attachment Profile (subworkflow)
                          ↓
                        Clean Email object
    ↓
  email-info-hub → subject-classifier-LM (LM1)
    ↓
  financial doc router → user_email_whitelist → whitelist validator
    ↓
  Has Attachments? → Prepare Attachments → Accountant-concierge-LM (LM2)
    ↓
  input folder lookup → Call 'Google Drive Folder ID Lookup' → save doc to folder
                  └→ insert doc record
    ↓
  Await Storage Complete → craft report note → Telegram & done / Mark as Processed1
```

### Contact-Centric Data Model

"Contact" = the other party (inbound: sender, outbound: recipient).

**Clean Email object** computes `direction`, `owner_email`, `contact_email`, `contact_name` once.
**email-info-hub** references these via `{{ $json.* }}`.

### Lineage logging
```
START: Gmail Trigger
  │
  ├→ Stop promotions (filter)
  ├→ Set File ID
  ├→ Gmail (get full email + attachments)
  └→ Empty? (check attachments)
     │
     ├─ NO ATTACHMENTS:
     │  └→ Clean Email object
     │     └→ email-info-hub *11
     │
     └─ HAS ATTACHMENTS:
        ├→ sp (split binaries)
        ├→ Create Attachment Profile (subworkflow, runs per item)
        ├→ Clean Email object
        └→ email-info-hub
   *11    └→ subject-classifier-LM
              │
              ├→ financial doc router
              ├→ Tag Mail with 'n8n' → notify rejection
              └→ appointment router → Trigger non-spam lineage

              IF FINANCIAL:
              ├→ user_email_whitelist
              ├→ whitelist validator
              └→ Has Attachments?
                 │
                 └→ Prepare Attachments
                    └→ Accountant-concierge-LM
                       │
                       ├→ input folder lookup
                       │  └→ Call 'Google Drive Folder ID Lookup'
                       │     └→ Get binary data2
                       │        └→ save doc to folder ─┐
                       │                               │
                       └→ insert doc record ───────────┤
                                                       │
                          Await Storage Complete ◄─────┘
                             └→ craft report note
                                ├→ Telegram & done
                                └→ Mark as Processed1

ALTERNATIVE ENTRY: When Executed by Another Workflow → Set File ID
```

## 🦜 AI Models Nodes

### 1. Classification
- **Node**: subject-classifier-LM
- **Input**: Email text + attachment content + contact context from email-info-hub
- **Output**: Document type, action required, Telegram summary, optional `contact_name_extracted`
- **Classification Types**:
  - confirmation, financial, newsletter, appointment, marketing, operational, other
- **Note**: `contact_name_extracted` is optional - the LLM extracts a clearer name if available in the email body (separate from header-derived `contact_name`)

### 2. Extraction
- **Node**: Accountant-concierge-LM
- **Input**: Cleaned invoice/receipt text
- **Output**: Structured invoice data with all fields
- **Key Capabilities**:
  - Categorization: Revenue vs Expense
  - Type detection: Invoice vs Receipt
  - Field extraction: dates, amounts, parties, line items

## 🔗 External Workflows Called

### 1. any-file2json-converter
- **Called by**: Create Attachment Profile
- **Purpose**: Converts various file formats to text/JSON
- **Supported formats**: PDF, DOCX, images (via OCR), etc.
- **Output**:
  - `data.text`: Extracted text content (string or JSON)
  - `data.content_class`: `primary_document` | `style_element` | `unclassified` | `UNK`
  - `data.class_confidence`: `0.0-1.0` | `UNK`
- **Note**: Classification only available for image path (LLM-based). PDF/text paths return `UNK`.

### 2. google-drive-folder-id-lookup
- **Called by**: Call 'gdrive-recursion'
- **Purpose**: Finds or creates Google Drive folder structure
- **Requirements**: PathToIDLookup Google Sheet (columns: `path | folder_id | child_ids | last_update`)
- **Input**: Path components (year, month, category)
- **Output**: Folder ID for file upload
- **Behavior**: Self-recursive workflow—calls itself when folders don't exist, skips cache lookup on recursive calls for efficiency. Uses OR query for batch cache lookup (Google Sheets v4.7)

💡 **Design Principle:** Single-provider architecture using Google OAuth (Gmail + Drive + Sheets) eliminates multi-platform authentication complexity. This consolidation reduces deployment overhead from typical 3-5 credential configurations to one.


## 📝 Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive