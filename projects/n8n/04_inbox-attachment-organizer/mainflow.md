# Main Flow (34 Nodes)

> **Version 2.0.0** | Last verified: 2026-01-31

## Overview

This workflow automates the entire invoice processing
  pipeline from email receipt to organized storage with
  minimal human intervention.


## Workflow Flow Summary


### Phases:
```
Email Trigger & Labeling
Attachment Processing
Subject Classifier & Routing
Deep Invoice Extraction & Storage
  - Storage: Google Sheets + Google Drive
  - Notifications: Telegram & Gmail labels
ContactManager Integration [disabled by default]
Alternative Entry: When Executed by Another Workflow
```

### Data Flow

```
Email → Label 'n8n' → Download Attachments → Text Extraction → AI Classification
                                                                    ↓
                                                               Is Financial?
                                                                    ↓
                                                          [disabled] Whitelist
                                                                    ↓
                                                          Prepare Attachments
                                                                    ↓
                                                          AI Deep Extraction
                                                                    ↓
                                                          Has Attachments?
                                                      ┌────── Yes ──┴── No ──────┐
                                                      ↓                          ↓
                                                Google Drive              Mark Processed
                                                (Organized)                     ↓
                                                      ↓                   Remove 'n8n' Label
                                                Mark Processed                  ↓
                                                      ↓                   Google Sheets
                                                Remove 'n8n' Label            (Logged)
                                                      ↓                        ↓
                                                Google Sheets           Telegram Notification
                                                  (Logged)
                                                      ↓
                                                Telegram Notification
```


### Key Workflow Logic
```
  Flow Summary:
  Gmail Trigger → Stop promotions → Set File ID → Tag Mail with 'n8n' → Gmail (download attachments)
    ↓
  Empty? (check for attachments)
    ├─ No Attachments → Clean Email object
    └─ Has Attachments → sp (split) → Create Attachment Profile (subworkflow)
                          ↓
                        Clean Email object
    ↓
  email-info-hub → subject-classifier-LM (LM1)
    ↓
  Routing branches:
    ├→ financial doc router → [disabled] sender_whitelist
    ├→ [disabled] notify the category (Telegram)
    └→ [disabled] ContactManager-lineage → record-search → smart-table-fill
    ↓
  IF FINANCIAL:
  Prepare Attachments → Accountant-concierge-LM (LM2)
    ↓
  If (has attachments?)
    ├─ Yes → input folder lookup → Call 'gdrive-recursion' → Get binary data2 → save doc to folder
    │        → Mark as Processed1 → Remove label from message → insert doc record → craft report note → Telegram & done
    └─ No  → Mark as Processed1 → Remove label from message → insert doc record → craft report note → Telegram & done
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
  ├→ Set File ID (email_ID, owner_name, company_name, label_ID)
  ├→ Tag Mail with 'n8n' (add Gmail label)
  ├→ Gmail (get full email + download attachments)
  └→ Empty? (check binary attachment count)
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
              ├→ [disabled] notify the category (Telegram)
              ├→ [disabled] ContactManager-lineage
              │     └→ Call 'record-search'
              │        └→ Prepare Contact Input
              │           └→ Call 'smart-table-fill'
              └→ financial doc router → [disabled] sender_whitelist

              IF FINANCIAL (via router):
              └→ Prepare Attachments
                 └→ Accountant-concierge-LM
                    └→ If (has attachments?)
                       │
                       ├─ YES (upload + log):
                       │  └→ input folder lookup
                       │     └→ Call 'gdrive-recursion'
                       │        └→ Get binary data2
                       │           └→ save doc to folder
                       │              └→ Mark as Processed1
                       │                 └→ Remove label from message
                       │                    └→ insert doc record
                       │                       └→ craft report note
                       │                          └→ Telegram & done
                       │
                       └─ NO (log only):
                          └→ Mark as Processed1
                             └→ Remove label from message
                                └→ insert doc record
                                   └→ craft report note
                                      └→ Telegram & done

ALTERNATIVE ENTRY: When Executed by Another Workflow → Set File ID
```

## AI Models Nodes

Both AI nodes use an LLM with structured output support.

### 1. Classification
- **Node**: subject-classifier-LM
- **Model**: LLM with structured output
- **Input**: Email text + attachment content + contact context from email-info-hub
- **Output**: Document type, action required, Telegram summary, body_core (stripped content), optional `contact_name_extracted`
- **Classification Types**:
  - financial, actionable, informational, Other
- **Note**: `contact_name_extracted` is optional - the LLM extracts a clearer name if available in the email body (separate from header-derived `contact_name`)

### 2. Extraction
- **Node**: Accountant-concierge-LM
- **Model**: LLM with structured output
- **Input**: Email context (subject, from, date, body_core) + parsed attachment text
- **Output**: Structured invoice data following the **Billing_Ledger schema** + filing metadata (accounting_category, document_type, year, month)
- **Key Capabilities**:
  - Categorization: Revenue vs Expense
  - Type detection: Invoice vs Receipt
  - Field extraction: dates, amounts, parties, line items
  - Filing path computation: year + month for folder structure

**Billing_Ledger Schema** (15 fields, all required):

| Source | Fields |
|--------|--------|
| **LLM** (Accountant-concierge-LM) | `counterparty_name`, `invoice_date`, `total_amount_due`, `currency_code`, `invoice_number`, `subtotal_amount`, `tax_amount`, `discount_amount`, `due_date_or_payment_terms`, `payment_method`, `payment_reference`, `date_paid`, `purchase_order_number`, `accounting_category` |
| **Node** (email-info-hub) | `email_id`, `attachment_count` |

> **counterparty_name** = the OTHER party on the invoice (supplier for Expense, customer for Revenue). Replaces legacy `supplier_name`/`recipient_business_name` fields.

## External Workflows Called

### 1. any-file2json-converter
- **Called by**: Create Attachment Profile
- **Location**: `../03_any-file2json-converter/workflows/any-file2json-converter.json`
- **Purpose**: Converts various file formats to text/JSON
- **Supported formats**: PDF, DOCX, images (via OCR), etc.
- **Input**: Binary data (per attachment). No extraction passed.
- **Output**:
  - `status`: `resolved` | `unresolved`
  - `data.text`: Extracted text content (string or JSON)
  - `data.content_class`: `primary_document` | `style_element` | `unclassified` | `UNK`
  - `data.class_confidence`: `0.0-1.0` | `UNK`
- **Note**: Classification only available for image path (LLM-based). PDF/text paths return `UNK`. Unsupported MIME types return `status: "unresolved"` with resolver_hint.

### 2. gdrive-recursion
- **Called by**: Call 'gdrive-recursion'
- **Purpose**: Finds or creates Google Drive folder structure
- **Requirements**: PathToIDLookup Google Sheet (columns: `path | folder_id | child_ids | last_update`)
- **Input**: Path components (year, month, category) via `target_path`, `root_folder_id`, `root_path`
- **Output**: Folder ID for file upload
- **Behavior**: Self-recursive workflow—calls itself when folders don't exist, auto-creates missing folders, caches results in PathToIDLookup sheet. Uses OR query for batch cache lookup (Google Sheets v4.7)

### 3. record-search [ContactManager]
- **Called by**: ContactManager-lineage (disabled by default)
- **Purpose**: Tiered contact lookup before calling smart-table-fill
- **Location**: `../02_smart-table-fill/workflows/subworkflows/record-search.json`
- **Output**: `{ found, matchType, contact }`

### 4. smart-table-fill [ContactManager]
- **Called by**: Prepare Contact Input
- **Purpose**: Extracts structured data from email body into contact sheet
- **Location**: `../02_smart-table-fill/workflows/smart-table-fill.n8n.json`
- **Note**: Uses rate-limited LLM extraction subworkflow internally

**Design Principle:** Single-provider architecture using Google OAuth (Gmail + Drive + Sheets) eliminates multi-platform authentication complexity. This consolidation reduces deployment overhead from typical 3-5 credential configurations to one.


## Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive
- The 'n8n' label acts as a processing-in-progress indicator: Tag Mail adds it early (before downloading attachments), and Remove label from message strips it after successful processing. Emails still carrying the label indicate incomplete or failed processing.
- Financial documents without attachments still get logged via the "No" branch (LLM extracts data from email body)
- sender_whitelist is disabled by default; enable it to restrict financial processing to known senders only
