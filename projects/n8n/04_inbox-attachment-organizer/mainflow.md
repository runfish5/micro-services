# Main Flow (37 Nodes)

> **Version 2.3.1** | Last verified against the workflow JSON: 2026-10-15

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
Contact branch (record-search → smart-CRM-fill)
Alternative Entry: When Called for Catch-up
```

### Data Flow

```
Email → Tag 'inProgress' → Download Attachments → Text Extraction → AI Classification
                                                                          ↓
                                                                    Switch Router
                                                           ┌──── financial ──┴── fallback ─────────┐
                                                           ↓                                       ↓
                                                  [disabled] Whitelist                         Merge[2]
                                                           ↓                                       ↑
                                                  Prepare Attachments                              │
                                                           ↓                                       │
                                                  AI Deep Extraction                               │
                                                           ↓                                       │
                                                  Has Attachments?                                 │
                                           ┌──── Yes ──┴── No ────┐                               │
                                           ↓                      ↓                               │
                                      Google Drive           Prepare Ledger Row ──→ Sheets ──→ Send Completion Message
                                      (Organized)                ↑                                 │
                                           ↓                     │                                 │
                                      Tag 'gdr' ──→ Prepare Ledger Row ──→ Sheets ──→ Send Completion Message
                                                                                                   │
  Contact branch ───────────→ Merge[0] ────────────────────────────────────────────────────────────┤
  Classify Email (direct) ──→ Merge[1] ───────────────────────────────────────────────────────────────────────┤
                                                                                                   ↓
                                                                                     Merge All Branches (3 inputs)
                                                                                                   ↓
                                                                                             Tag 'n8n'
                                                                                                   ↓
                                                                                          Remove 'inProgress'
```


### Key Workflow Logic
```
  Flow Summary:
  When Email Received → Skip Promotions → Set Run Config → Add inProgress Label → Get Email With Attachments
    ↓
  If No Attachments
    ├─ No Attachments → Clean Email Body
    └─ Has Attachments → Split Attachments → Convert Attachments to Text (subworkflow)
                          ↓
                        Clean Email Body
    ↓
  Build Email Context → Classify Email (Classifier LLM)
    ↓
  Three routing branches (all converge at Merge All Branches):
    ├→ Route by Email Category (Switch with fallbackOutput: "extra")
    │     ├─ financial → [disabled] Filter by Sender Whitelist → Prepare Attachments → Extract Invoice Data → If Has Attachments
    │     │     ├─ Yes → Upload File to Drive → Add gdr Label → Prepare Ledger Row → Upsert Ledger Row in Sheets → Send Completion Message → Merge[2]
    │     │     └─ No  → Prepare Ledger Row → Upsert Ledger Row in Sheets → Send Completion Message → Merge[2]
    │     ├─ actionable + requires_action → Send Category Message (Telegram) → Merge[2]
    │     └─ fallback → Merge[2]
    ├→ Merge[1] (direct)
    └→ Look Up Contact → Prepare Contact Input → Update Contact Record → Merge[0]
    ↓
  Merge All Branches (3 inputs) → Add n8n Label → Remove inProgress Label
```

### Contact-Centric Data Model

"Contact" = the other party (inbound: sender, outbound: recipient).

**Clean Email Body** computes `direction`, `owner_email`, `contact_email`, `contact_name` once.
**Build Email Context** references these via `{{ $json.* }}`.

### Lineage logging
```
START: When Email Received
  │
  ├→ Skip Promotions (filter)
  ├→ Set Run Config (email_ID, owner_name, company_name, label_ID, archive_when_filed)
  ├→ Add inProgress Label (add Gmail label)
  ├→ Get Email With Attachments (get full email + download attachments)
  └→ If No Attachments (check binary attachment count)
     │
     ├─ NO ATTACHMENTS:
     │  └→ Clean Email Body
     │     └→ Build Email Context *11
     │
     └─ HAS ATTACHMENTS:
        ├→ Split Attachments (split binaries)
        ├→ Convert Attachments to Text (subworkflow, runs per item)
        ├→ Clean Email Body
        └→ Build Email Context
   *11    └→ Classify Email
              │
              ├→ Merge[1] (direct)
              ├→ Contact branch
              │     └→ Look Up Contact
              │        └→ Prepare Contact Input
              │           └→ Update Contact Record ──→ Merge[0]
              └→ Route by Email Category (Switch, fallbackOutput: "extra")
                    │
                    ├─ FINANCIAL (output 0):
                    │  └→ [disabled] Filter by Sender Whitelist
                    │     └→ Prepare Attachments
                    │        └→ Extract Invoice Data
                    │           └→ If Has Attachments
                    │              │
                    │              ├─ YES (upload + log):
                    │              │  └→ Build Folder Path
                    │              │     └→ Find or Create Drive Folder
                    │              │        └→ Restore Attachment File
                    │              │           └→ Upload File to Drive
                    │              │              └→ Add gdr Label ──→ Prepare Ledger Row
                    │              │                                └→ Upsert Ledger Row in Sheets
                    │              │                                   └→ Build Report Message
                    │              │                                      └→ Send Completion Message ──→ Merge[2]
                    │              │
                    │              └─ NO (log only):
                    │                 └→ Prepare Ledger Row
                    │                    └→ Upsert Ledger Row in Sheets
                    │                       └→ Build Report Message
                    │                          └→ Send Completion Message ──→ Merge[2]
                    │
                    ├─ ACTIONABLE + requires_action (output 1):
                    │  └→ Send Category Message (Telegram) ──→ Merge[2]
                    │
                    └─ FALLBACK (output 2):
                       └→ Merge[2]

  ──→ Merge All Branches (3 inputs) → Add n8n Label → Remove inProgress Label (also removes INBOX when archive_when_filed is on and Add gdr Label ran)

ALTERNATIVE ENTRY: When Called for Catch-up → Set Run Config
```

## AI Models Nodes

Both AI nodes use an LLM with structured output support. Their sub-nodes: `Classifier LLM` + `Classifier Output Schema` (classifier), `Extractor LLM` + `Invoice Output Schema` (extractor).

### 1. Classification
- **Node**: Classify Email
- **Model**: LLM with structured output
- **Input**: Email text + attachment content + contact context from Build Email Context
- **Output**: Document type, action required, Telegram summary, body_core (stripped content), optional `contact_name_extracted`
- **Classification Types**:
  - financial, actionable, informational, Other
- **Note**: `contact_name_extracted` is optional - the LLM extracts a clearer name if available in the email body (separate from header-derived `contact_name`)

### 2. Extraction
- **Node**: Extract Invoice Data
- **Model**: LLM with structured output
- **Input**: Email context (subject, from, date, body_core) + parsed attachment text
- **Output**: Structured invoice data following the **Billing_Ledger schema** + filing metadata (accounting_category, document_type, year, month)
- **Key Capabilities**:
  - Categorization: Revenue vs Expense
  - Type detection: Invoice vs Receipt
  - Field extraction: dates, amounts, parties, line items
  - Filing path computation: year + month for folder structure

### Ledger grain (one row = one invoice)

**One row per invoice, keyed by `invoice_number`** — not per attachment, not per email.
`Prepare Ledger Row` groups the extracted documents; `Upsert Ledger Row in Sheets` upserts on that column.
The settlement columns (`date_paid`, `payment_reference`, `payment_method`) are filled in later,
when the receipt arrives. `invoice_status` is never written by the workflow.

Rules, constraints and the case table: `CLAUDE.md` (Ledger Grain) and `README.md` (FAQ).

**Billing_Ledger Schema** (16 columns, 15 auto-populated + `invoice_status` manual):

| Source | Fields |
|--------|--------|
| **LLM** (Extract Invoice Data) | `counterparty_name`, `invoice_date`, `currency_code`, `invoice_number`, `subtotal_amount` (holds the extractor's `total_amount_due`), `tax_amount`, `discount_amount`, `due_date_or_payment_terms`, `payment_method`, `payment_reference`, `date_paid`, `purchase_order_number`, `accounting_category` |
| **Node** (Build Email Context) | `email_id`, `attachment_count` |

> **Prepare Ledger Row** (Code node) flattens the LLM output + Build Email Context fields into a single flat JSON object, enabling "Upsert Ledger Row in Sheets" to use Auto-Map mode (resilient to Google Sheets re-selection in the n8n UI).

> **counterparty_name** = the OTHER party on the invoice (supplier for Expense, customer for Revenue). Replaces legacy `supplier_name`/`recipient_business_name` fields.

## External Workflows Called

### 1. any-file2json-converter
- **Called by**: Convert Attachments to Text
- **Location**: `../03_any-file2json-converter/workflows/any-file2json-converter.json`
- **Purpose**: Converts various file formats to text/JSON
- **Supported formats**: PDF, DOCX, images (via OCR), etc.
- **Input**: Binary data (per attachment). No extraction passed.
- **Output**:
  - `status`: `ok` | `unsupported` (a step that fails inside the converter fails this workflow, so 007 records it)
  - `error`: `{code, mimeType, fileName, message}` for unsupported files, else null
  - `data.text`: Extracted text content (string or JSON)
  - `data.content_class`: `primary_document` | `style_element` | `unclassified` | `UNK`
  - `data.class_confidence`: `0.0-1.0` | `UNK`
- **Note**: Classification only available for image path (LLM-based). PDF/text paths return `UNK`. Unsupported MIME types return `status: "unsupported"` with the MIME type in `error`.

### 2. gdrive-recursion
- **Called by**: Find or Create Drive Folder
- **Purpose**: Finds or creates Google Drive folder structure
- **Requirements**: PathToIDLookup Google Sheet (columns: `path | folder_id | child_ids | last_update`)
- **Input**: Path components (year, month, category) via `target_path`, `root_folder_id`, `root_path`
- **Output**: Folder ID for file upload
- **Behavior**: Self-recursive workflow—calls itself when folders don't exist, auto-creates missing folders, caches results in PathToIDLookup sheet. Uses OR query for batch cache lookup (Google Sheets v4.7)

### 3. record-search [ContactManager]
- **Called by**: Look Up Contact
- **Purpose**: Tiered contact lookup before calling smart-table-fill
- **Location**: `../02_smart-table-fill/workflows/subworkflows/record-search.json`
- **Output**: `{ found, matchType, contact }`

### 4. smart-table-fill [ContactManager]
- **Called by**: Update Contact Record (the workflow is named `smart-CRM-fill` on the instance)
- **Purpose**: Extracts structured data from email body into contact sheet
- **Location**: `../02_smart-table-fill/workflows/smart-table-fill.n8n.json`
- **Note**: One LLM call per schema batch, sent without pause. A rate-limit failure is the error handler's to recover (`llm-extract-rate-limited`, spec only)

**Design Principle:** Gmail, Drive and Sheets share one Google OAuth credential. The only other credentials are the LLM API key and the optional Telegram bot.

Each Execute Workflow node lists the inputs it passes in its Notes (the restore reference if n8n clears `workflowInputs`).


## Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive
- **Three Gmail labels**: `inProgress` is a temporary canary applied at start and removed on success (emails still carrying it indicate failed processing). `n8n` is a permanent success marker applied once after the Merge convergence. `gdr` marks emails whose attachments were saved to Google Drive (attachment branch only).
- **Merge convergence**: All three output branches (contact, notify, financial/fallback) feed into the 3-input `Merge All Branches` node. `Add n8n Label` and `Remove inProgress Label` execute exactly once after it, regardless of which branches were active.
- **Action alert**: an `actionable` email with `requires_action` leaves `Route by Email Category` on output 1 and goes straight to Telegram (`Send Category Message`, then Merge[2]). A financial email with `requires_action` (failed payment, reminder, debt collection) starts its report with `⚡ ACTION: money`. Fallback is output 2.
- Financial documents without attachments still get logged via the "No" branch (LLM extracts data from email body)
- Filter by Sender Whitelist is disabled by default; before enabling it, edit its sender array (a red warning sticky marks it), or every financial email is dropped
