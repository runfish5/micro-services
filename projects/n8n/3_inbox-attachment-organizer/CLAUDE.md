# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

n8n workflow that auto-files email attachments to Google Drive using AI classification. Author's priority: single Google OAuth (vs typical 3-5 platform auths) + two-stage AI to cut costs (cheap classifier → expensive extractor only for financial docs).

## Working with n8n Workflows

n8n workflows are JSON-based node configurations best edited in the n8n UI for logic changes (visualizes data flow) then exported as JSON for version control. Use the built-in execution logs and debug mode to trace data transformations between nodes - each node execution shows input/output. When testing changes, replace triggers (like Gmail Trigger) with Manual Trigger nodes to avoid waiting for polling intervals. For large dataset processing, use Split In Batches nodes to prevent memory issues and timeouts.

## Where Information Lives

### Documentation
- `docs/mainflow.md` - Complete 39-node breakdown by phases (1-5: monitoring, 6-15: attachments, 16-18: classification, etc.), data flow diagrams, AI node purposes, and subworkflow call points. Read this before reverse-engineering JSON.
- `docs/setup-guide.md` - 2505_Invoices sheet schema (28 columns tab-separated), PathToIDLookup schema (4 columns), folder structure template, credential setup sequence
- `main-sticky-note.md` - Author's setup checklist showing deployment priorities and post-activation tasks

### Workflows
- `workflows/inbox-attachment-organizer.json` - Main workflow (39 nodes) orchestrating the full pipeline
- `workflows/subworkflows/any-file2json-converter.json` - Converts PDFs/images/DOCX to text (called per attachment in loop)
- `workflows/subworkflows/google-drive-folder-id-lookup.json` - Finds or creates Drive folders using PathToIDLookup cache
- `workflows/subworkflows/google-drive-folder-id-recursion.json` - Recursive folder creation helper (called by lookup when folders missing)
- `workflows/subworkflows/gmail-systematic-processor.json` - Standalone batch processor for existing inbox emails

## Non-Obvious Architecture

**PathToIDLookup sheet**: Workaround because n8n Google Drive nodes only accept folder IDs, not path-based API access. The sheet maps paths to IDs so you can request "/Accounting/2025/05_May/Expense/" instead of cryptic Drive IDs. Secondary benefit: caches results so repeated lookups are instant sheet reads vs slow API traversal. Schema in setup-guide.md.

**Subworkflow calls**: Main workflow calls any-file2json-converter (per attachment) and google-drive-folder-id-lookup (per file). The lookup calls google-drive-folder-id-recursion when folders don't exist.

**Two AI stages**: subject-classifier-LM classifies everything → Accountant-concierge-LM only processes "financial" types. Whitelist check happens between stages.

**gmail-systematic-processor**: Separate workflow for batch processing existing inbox. Gmail Trigger only catches new emails.

**Folder structure**: Files organize as `/{RootFolder}/{Year}/{MM_Month}/{Category}/` - example: `/Accounting/2025/05_May/Expense/`. The MM_Month format (01_January, 02_February...) ensures proper sorted display in Drive. Category is determined by Accountant-concierge-LM extraction (Revenue vs Expense for financial docs).

## Workflow Phases (from mainflow.md)

Nodes 1-5: Email Monitoring (Gmail Trigger polls every 1 min, filters promotions)
Nodes 6-15: Attachment Processing (splits attachments, loops to call any-file2json-converter per file, aggregates text)
Nodes 16-18: AI Classification First Pass (subject-classifier-LM outputs: confirmation, financial, newsletter, appointment, marketing, operational, other)
Nodes 19-23: Routing & Filtering (Switch on type, Accounting-email-List whitelist check)
Nodes 24-28: Deep Invoice Extraction (Accountant-concierge-LM extracts 28 fields: Revenue/Expense, Invoice/Receipt, dates, amounts, parties)
Nodes 31-35: Storage & Logging (google-drive-folder-id-lookup call, upload to Drive, log to 2505_Invoices sheet)
Nodes 36-38: Notifications (Telegram - note: configuration not yet implemented per mainflow.md)
Node 39: Alternative Entry

## More Details

See `docs/mainflow.md` for complete node-by-node lineage and subworkflow integration points. See `main-sticky-note.md` for deployment checklist.
