# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Read This First

**ALWAYS read `mainflow.md` BEFORE looking at the workflow JSON files.** The mainflow.md is the authoritative representation of the workflow structure and logic. The JSON files are machine-readable exports that are difficult to understand without the context from mainflow.md. Do NOT attempt to reverse-engineer the JSON - read the documentation first.

## What This Is

n8n workflow that auto-files email attachments to Google Drive using AI classification. Author's priority: single Google OAuth (vs typical 3-5 platform auths) + two-stage AI to cut costs (cheap classifier → expensive extractor only for financial docs).

## Working with n8n Workflows

n8n workflows are JSON-based node configurations best edited in the n8n UI for logic changes (visualizes data flow) then exported as JSON for version control. Use the built-in execution logs and debug mode to trace data transformations between nodes - each node execution shows input/output. When testing changes, replace triggers (like Gmail Trigger) with Manual Trigger nodes to avoid waiting for polling intervals. For large dataset processing, use Split In Batches nodes to prevent memory issues and timeouts.

## Where Information Lives

### Documentation
- `mainflow.md` - Complete 37-node breakdown by phases (1-5: trigger & labeling, 6-10: attachments, 11-18: classification & routing, 19-30: extraction & storage, Merge convergence), data flow diagrams, AI node purposes, and subworkflow call points. Read this before reverse-engineering JSON.
- `docs/setup-guide.md` - Billing_Ledger sheet schema (15 columns), PathToIDLookup schema (4 columns), folder structure template, credential setup sequence
- `main-sticky-note.md` - Author's setup checklist showing deployment priorities and post-activation tasks

### Workflows
- `workflows/inbox-attachment-organizer.json` - Main workflow (37 nodes) orchestrating the full pipeline
- Calls `03_any-file2json-converter` subworkflow - Converts PDFs/images/DOCX to text (called per attachment). Returns `data.text`, `data.content_class`, `data.class_confidence`. Classification via LLM for images; PDF/text paths return `UNK`. See `../03_any-file2json-converter/CLAUDE.md` for details.
- `workflows/subworkflows/gdrive-recursion.json` - Looks up Drive folder IDs via PathToIDLookup Google Sheet (n8n requires IDs, not paths). Self-recursive; auto-creates missing folders, caches results, uses batch OR query
- `workflows/subworkflows/gmail-processor-datesize.json` - Standalone batch processor for existing inbox emails

## Non-Obvious Architecture

**Two AI stages (both require structured output)**: subject-classifier-LM classifies everything → Accountant-concierge-LM only processes "financial" types. Whitelist check (disabled by default) sits between stages.

**Three Gmail labels**: `inProgress` is a temporary canary applied at start (Tag inProgress) and removed on success (Remove inProgress) — emails still carrying it indicate failed runs. `n8n` (Tag n8n) is a permanent success marker applied once after the Merge convergence node. `gdr` (Tag gdr) marks emails whose attachments were saved to Google Drive (attachment branch only). All three routing branches (ContactManager, notify, financial/fallback) converge at a 3-input Merge → Tag n8n → Remove inProgress.

**Financial docs without attachments**: The If node after Accountant-concierge-LM checks for attachments. Financial emails without attachments skip the Drive upload but still get logged to Sheets and notified via Telegram.

**gmail-processor-datesize**: Separate workflow for batch processing existing inbox. Gmail Trigger only catches new emails.

**Folder structure**: Files organize as `/{RootFolder}/{Year}/{MM_Month}/{Category}/` - example: `/Accounting/2025/05_May/Expense/`. The MM_Month format (01_January, 02_February...) ensures proper sorted display in Drive. Category is determined by Accountant-concierge-LM extraction (Revenue vs Expense for financial docs).

## Workflow Phases (from mainflow.md)

Nodes 1-5: Email Trigger & Labeling (Gmail Trigger polls every 1 min, filters promotions, sets metadata incl. label_ID, tags with 'inProgress' label, downloads attachments)
Nodes 6-10: Attachment Processing (splits attachments, calls any-file2json-converter per item, Clean Email object sanitizes body + builds attachment map, email-info-hub aggregates contact/direction data)
Nodes 11-18: Classification & Routing (subject-classifier-LM classifies, financial doc router, sender_whitelist disabled, notify the category disabled)
Nodes 19-30+: Deep Invoice Extraction & Storage (Prepare Attachments, Accountant-concierge-LM extracts fields, If checks attachments, gdrive-recursion call, upload to Drive, Tag gdr, log to Billing_Ledger sheet, craft report, Telegram notification → Merge convergence → Tag n8n → Remove inProgress)
ContactManager (disabled): record-search → Prepare Contact Input → smart-table-fill
Alternative Entry: When Executed by Another Workflow

## More Details

See `mainflow.md` for complete node-by-node lineage and subworkflow integration points. See `main-sticky-note.md` for deployment checklist.
