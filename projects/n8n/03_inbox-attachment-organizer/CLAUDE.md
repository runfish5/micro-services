# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ IMPORTANT: Read This First

**ALWAYS read `docs/mainflow.md` BEFORE looking at the workflow JSON files.** The mainflow.md is the authoritative representation of the workflow structure and logic. The JSON files are machine-readable exports that are difficult to understand without the context from mainflow.md. Do NOT attempt to reverse-engineer the JSON - read the documentation first.

## What This Is

n8n workflow that auto-files email attachments to Google Drive using AI classification. Author's priority: single Google OAuth (vs typical 3-5 platform auths) + two-stage AI to cut costs (cheap classifier → expensive extractor only for financial docs).

## Working with n8n Workflows

n8n workflows are JSON-based node configurations best edited in the n8n UI for logic changes (visualizes data flow) then exported as JSON for version control. Use the built-in execution logs and debug mode to trace data transformations between nodes - each node execution shows input/output. When testing changes, replace triggers (like Gmail Trigger) with Manual Trigger nodes to avoid waiting for polling intervals. For large dataset processing, use Split In Batches nodes to prevent memory issues and timeouts.

## Where Information Lives

### Documentation
- `docs/mainflow.md` - Complete 30-node breakdown by phases (1-5: trigger, 6-10: attachments, 11-18: classification & routing, 19-30: extraction & storage), data flow diagrams, AI node purposes, and subworkflow call points. Read this before reverse-engineering JSON.
- `docs/setup-guide.md` - 2505_Invoices sheet schema (28 columns tab-separated), PathToIDLookup schema (4 columns), folder structure template, credential setup sequence
- `main-sticky-note.md` - Author's setup checklist showing deployment priorities and post-activation tasks

### Workflows
- `workflows/inbox-attachment-organizer.json` - Main workflow (30 nodes) orchestrating the full pipeline
- `workflows/subworkflows/any-file2json-converter.json` - Converts PDFs/images/DOCX to text (called per attachment)
- `workflows/subworkflows/google-drive-folder-id-lookup.json` - Looks up Drive folder IDs via PathToIDLookup Google Sheet (n8n requires IDs, not paths). Self-recursive; creates missing folders, caches results, uses batch OR query
- `workflows/subworkflows/gmail-systematic-processor.json` - Standalone batch processor for existing inbox emails

## Non-Obvious Architecture

**Two AI stages**: subject-classifier-LM classifies everything → Accountant-concierge-LM only processes "financial" types. Whitelist check happens between stages.

**gmail-systematic-processor**: Separate workflow for batch processing existing inbox. Gmail Trigger only catches new emails.

**Folder structure**: Files organize as `/{RootFolder}/{Year}/{MM_Month}/{Category}/` - example: `/Accounting/2025/05_May/Expense/`. The MM_Month format (01_January, 02_February...) ensures proper sorted display in Drive. Category is determined by Accountant-concierge-LM extraction (Revenue vs Expense for financial docs).

## Workflow Phases (from mainflow.md)

Nodes 1-5: Email Trigger (Gmail Trigger polls every 1 min, filters promotions, downloads attachments)
Nodes 6-10: Attachment Processing (splits attachments, calls any-file2json-converter per item, Clean Email object aggregates text)
Nodes 11-18: Classification & Routing (subject-classifier-LM, financial doc router, whitelist validator, appointment router)
Nodes 19-30: Deep Invoice Extraction & Storage (Prepare Attachments, Accountant-concierge-LM extracts fields, google-drive-folder-id-lookup call, upload to Drive, log to 2505_Invoices sheet, Telegram notification, Mark as Processed)
Alternative Entry: When Executed by Another Workflow

## More Details

See `docs/mainflow.md` for complete node-by-node lineage and subworkflow integration points. See `main-sticky-note.md` for deployment checklist.
