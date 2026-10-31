# Main Flow (55 Nodes)

> **Version 2.4.0** | Last verified against the workflow JSON: 2026-10-27

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

Every LLM call runs before the first write, so an email held back on a daily quota has nothing
written and a rerun files it once.

```
Email → Tag 'inProgress' → Download Attachments → Text Extraction (vision LLM) → AI Classification
                                                                                       ↓
                                                                          financial? ──┴── no ───────┐
                                                                               ↓                     │
                                                          Prepare Attachments → AI Deep Extraction   │
                                                          (one document per pass, Loop Over Documents)│
                                                                               ↓                     ↓
                                                                    Contact branch (record-search → smart-CRM-fill, LLM)
                                                                               ↓
                                                                     If Contact Stopped ──→ Merge[0], Merge[1]
                                                                               ↓
                                                                          Switch Router
                                                    ┌──── financial ──────────┼── actionable ──┬── fallback ──┐
                                                    ↓                         ↓                ↓              ↓
                                           [disabled] Whitelist        Telegram notice      Merge[2]       Merge[2]
                                                    ↓
                                     Join Documents (the extracted documents)
                                                    ↓
                                            Has Attachments?
                                     ┌──── Yes ──┴── No ────┐
                                     ↓                      ↓
                          Google Drive → Tag 'gdr' → Prepare Ledger Row → Sheets → Send Completion Message → Merge[2]
                                                                                                   ↓
                                                                     Merge All Branches (3 inputs) → Tag 'n8n' → Remove 'inProgress'

  Any LLM's daily quota used up (vision, classifier, extractor, contact fill) → hold back (below)
```


### Key Workflow Logic
```
  Flow Summary:
  When Email Received → Skip Promotions → Process Each Email (this workflow, once per email, enters at When Called for Catch-up)
  When Called for Catch-up → Set Run Config → Add inProgress Label → Get Email With Attachments → Drop Inline Images
    ↓
  If No Attachments
    ├─ No Attachments → Clean Email Body
    └─ Has Attachments → Split Attachments → Convert Attachments to Text (subworkflow) → If Attachments Stopped
                          ├─ an image came back stopped (vision daily quota) → hold back, see below
                          └─ otherwise → Clean Email Body
    ↓
  Build Email Context → Classify Email (Classifier LLM)
    │  error output → Check Classifier Rate Limit (llm-rate-limit) → Route Classifier Rate Limit
    │     retry → Classify Email · stop → hold back · other → Fail With LLM Error
    ↓
  If Financial Email
    ├─ financial → Prepare Attachments → Loop Over Documents ⇄ Extract Invoice Data (one document per pass)
    │     error output → Check Extractor Rate Limit → Route Extractor Rate Limit
    │        retry → Extract Invoice Data · stop → hold back · other → Fail With LLM Error
    │     done → Join Documents[0] + Look Up Contact (once)
    └─ not financial → Look Up Contact
    ↓
  Look Up Contact → Prepare Contact Input → Update Contact Record → If Contact Stopped (once)
    ├─ stopped (smart-table-fill hit its daily quota) → hold back
    └─ otherwise → Merge[0], Merge[1], Route by Email Category
    ↓
  Route by Email Category (Switch with fallbackOutput: "extra")
    ├─ documents extracted (Loop Over Documents ran) → [disabled] Filter by Sender Whitelist → Join Documents[1] → If Has Attachments
    │     ├─ Yes → Upload File to Drive → Add gdr Label → Prepare Ledger Row → Upsert Ledger Row in Sheets → Send Completion Message → Merge[2]
    │     └─ No  → Prepare Ledger Row → Upsert Ledger Row in Sheets → Send Completion Message → Merge[2]
    ├─ actionable + requires_action → Send Category Message (Telegram) → Merge[2]
    └─ fallback → Merge[2]
    ↓
  Merge All Branches (3 inputs) → Add n8n Label → Remove inProgress Label → Clear Stopped Row
```

### Hold back on a used-up daily quota
```
  If Attachments Stopped (any converter item has status `stopped`: vision)
  Route Classifier Rate Limit / Route Extractor Rate Limit (output stop)
  If Contact Stopped (true)
    → Read Stopped Emails → Prepare Stop Notice → Save Stopped Email (data table stopped_emails, upsert by message_id, stopped_by = the stage)
    → If First Stop Today → Send Stop Notice (Telegram: stage, model, limit, reset; one per model and quota day; Rerun button)
```
The email is not filed: no n8n label, `inProgress` stays, and nothing was written (every LLM call runs before the first
write). `/rerun_attachments` (or the button) runs it again through `workflows/subworkflows/stopped-emails.json`, 45 s
apart; a filed email takes its own row off the list in `Clear Stopped Row`.

### Contact-Centric Data Model

"Contact" = the other party (inbound: sender, outbound: recipient).

**Clean Email Body** computes `direction`, `owner_email`, `contact_email`, `contact_name` once.
**Build Email Context** references these via `{{ $json.* }}`.

### Lineage logging
```
START: When Email Received
  │
  ├→ Skip Promotions (filter)
  └→ Process Each Email (calls this workflow per email → When Called for Catch-up)

START (one email): When Called for Catch-up
  ├→ Set Run Config (email_ID, owner_name, company_name, label_ID, archive_when_filed)
  ├→ Add inProgress Label (add Gmail label)
  ├→ Get Email With Attachments (get full email + download attachments)
  ├→ Drop Inline Images (drops parts the HTML embeds: logos, signatures)
  └→ If No Attachments (check binary attachment count)
     │
     ├─ NO ATTACHMENTS:
     │  └→ Clean Email Body
     │     └→ Build Email Context *11
     │
     └─ HAS ATTACHMENTS:
        ├→ Split Attachments (split binaries)
        ├→ Convert Attachments to Text (subworkflow, runs per item)
        ├→ If Attachments Stopped (stopped → hold back, see above)
        ├→ Clean Email Body
        └→ Build Email Context
   *11    └→ Classify Email
              │  (error output: Check Classifier Rate Limit → Route Classifier Rate Limit; see CLAUDE.md LLM limits)
              │
              └→ If Financial Email
                    ├─ FINANCIAL: Prepare Attachments
                    │  └→ Loop Over Documents ⇄ Extract Invoice Data
                    │     (error output: Check Extractor Rate Limit → Route Extractor Rate Limit)
                    │     └─ done → Join Documents[0], Look Up Contact
                    └─ OTHER: Look Up Contact
                          └→ Prepare Contact Input
                             └→ Update Contact Record
                                └→ If Contact Stopped ──→ Merge[0], Merge[1]
                                   └→ Route by Email Category (Switch, fallbackOutput: "extra")
                    │
                    ├─ DOCUMENTS EXTRACTED (output 0):
                    │  └→ [disabled] Filter by Sender Whitelist
                    │     └→ Join Documents[1] (passes on the extracted documents)
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
                    ├─ ACTIONABLE + requires_action + inbound, not calendar (output 1):
                    │  └→ Send Category Message (Telegram) ──→ Merge[2]
                    │
                    └─ FALLBACK (output 2):
                       └→ Merge[2]

  ──→ Merge All Branches (3 inputs) → Add n8n Label → Remove inProgress Label (also removes INBOX when archive_when_filed is on and Add gdr Label ran) → Clear Stopped Row

ALTERNATIVE ENTRY: When Called for Catch-up → Set Run Config
```

## AI Models Nodes

Both AI nodes use an LLM with structured output support. Their sub-nodes: `Classifier LLM` + `Classifier Output Schema` (classifier), `Extractor LLM` + `Invoice Output Schema` (extractor).

### 1. Classification
- **Node**: Classify Email
- **Model**: LLM with structured output, temperature 0
- **Input**: Email text + attachment content + contact context from Build Email Context + `RECEIVED` (the email's own date from `Get Email With Attachments`, in the instance's time zone, `unknown` when missing), so deadlines are read against the arrival day
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
  - `status`: `ok` | `unsupported` | `stopped` (vision daily quota used up: the email is held back) (a step that fails inside the converter fails this workflow, so 007 records it)
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
- **Note**: One LLM call per schema batch, one batch per pass. A 429 asks `llm-rate-limit`: per minute waits and sends the batch again; per day returns `{status: 'stopped', rate_limit}` before any write, and `If Contact Stopped` holds the email back

### 5. llm-rate-limit
- **Called by**: Check Classifier Rate Limit, Check Extractor Rate Limit (and smart-table-fill's Check Fill Rate Limit)
- **Location**: `../shared/llm-rate-limit.json`
- **Input**: `error`, `model`, `attempt` (`$runIndex`), `item` (what the LLM read)
- **Output**: the item plus `rate_limit: {action: retry | stop | other, limit, wait_s, quota_limit, resets_at, message, model}`

**Design Principle:** Gmail, Drive and Sheets share one Google OAuth credential. The only other credentials are the LLM API key and the optional Telegram bot.

Each Execute Workflow node lists the inputs it passes in its Notes (the restore reference if n8n clears `workflowInputs`).


## Notes
- Google Sheets provides a queryable database of all processed invoices
- The folder structure makes manual file browsing intuitive
- **Three Gmail labels**: `inProgress` is a temporary canary applied at start and removed on success (emails still carrying it indicate failed processing). `n8n` is a permanent success marker applied once after the Merge convergence. `gdr` marks emails whose attachments were saved to Google Drive (attachment branch only).
- **Merge convergence**: `If Contact Stopped` feeds inputs 1 and 2 of the 3-input `Merge All Branches` node, the routed branch (notify, financial, fallback) input 3. It passes on input 2 only, so `Add n8n Label` and `Remove inProgress Label` execute exactly once. A held-back email reaches none of its inputs, so it is never labelled done.
- **Action alert**: an `actionable` email with `requires_action` leaves `Route by Email Category` on output 1 and goes straight to Telegram (`Send Category Message`, then Merge[2]). A financial email with `requires_action` (failed payment, reminder, debt collection) starts its report with `⚡ ACTION: money`. Outbound mail (the owner wrote it, including the owner's own alerts) and calendar notifications (`calendar-notification@google.com`: the calendar already reminds the owner) never count: both checks are `requires_action && direction !== 'outbound' && contact_email !== 'calendar-notification@google.com'`, so neither ever pings. Fallback is output 2.
- Financial documents without attachments still get logged via the "No" branch (LLM extracts data from email body)
- Filter by Sender Whitelist is disabled by default; before enabling it, edit its sender array (a red warning sticky marks it), or every financial email is dropped. It sits after extraction, so a dropped email's documents were still extracted, and it is still labelled `n8n`
