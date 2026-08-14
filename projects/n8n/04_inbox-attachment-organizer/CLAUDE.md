# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Read This First

**ALWAYS read `mainflow.md` BEFORE looking at the workflow JSON files.** The mainflow.md is the authoritative representation of the workflow structure and logic. The JSON files are machine-readable exports that are difficult to understand without the context from mainflow.md. Do NOT attempt to reverse-engineer the JSON - read the documentation first.

## Ledger Grain — read before touching the ledger path

**One row per invoice, keyed by `invoice_number`.** Documents are evidence, rows are economic
events; the mapping is many-to-one. Invoice + receipt = 1 row. Two orders = 2 rows. Row count
follows `invoice_number`, never attachment or email count. Definition and case table:
`README.md` FAQ.

This ledger has a counterpart: `16_commitments-ledger` records what we signed up for, from our
side, and reconciles against these rows. Keep the two independent — nothing in the matching
process may write back into either book.

`Prepare Ledger Row` groups by `invoice_number`; `insert doc record` uses `appendOrUpdate` on
that column. Both were fixed 2026-07-20 (previously `.first()` and blind `append`, which lost
documents and duplicated rows while the run still reported success).

Three constraints on that node — all bite *any* many-to-one Code node here:

1. **`pairedItem` is mandatory.** Emitting fewer rows than consumed breaks n8n's item lineage
   and `craft report note` dies with "Paired item data ... is unavailable" — *after* the sheet
   write, so the ledger is correct while the execution reads as failed.
2. **Placeholder invoice numbers are not keys.** Extractors emit `-`, `N/A`, `UNKNOWN` and
   friends; upserting on those collapses every unkeyed row into one. Sentinels are detected and
   given an `AUTOKEY::<party>::<date>::<msg-id>` key — the message id is required, since one
   sender can send two unkeyed documents on the same day. `::` appears in no real invoice
   number, so "contains `::`" reliably finds project-assigned keys.
3. **Throughput caps documents per email — known, NOT fixed.** The extractor runs once per
   attachment (~2.4k tokens) against an 8k tokens/minute ceiling, so a 4-document email needs
   ~9.8k and fails on the last one. Measured 2026-07-20: execution 4909 wrote nothing; the same
   email with `any LM1` at `options.maxRetries: 8` recovered from 15 rate-limit errors and wrote
   both rows. Deliberately not applied — throughput is a separate concern from grain. Apply it
   to `any LM1` alone if multi-document emails start failing.

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
- `../shared/gdrive-recursion.json` - Looks up Drive folder IDs via PathToIDLookup Google Sheet (n8n requires IDs, not paths). Self-recursive; auto-creates missing folders, caches results, uses batch OR query. Live instance ID: `zBC03d42z8A_SjE0JSM5G` (single copy; both 04's call and the self-recursion point at it).
  - **Cache-key trap**: `PathToIDLookup` is keyed on `path` alone — `root_folder_id` is *not* part of the key. A test copy that passes a different `root_folder_id` but the same `target_path` gets a cache **hit** resolving to the real folder ID, and writes into the production `/Accounting` tree. Any test must change `root_path` **and** `root_folder_id` together so its paths cannot collide with cached real ones.
- `workflows/subworkflows/gmail-processor-datesize.json` - Standalone batch processor for existing inbox emails

## Non-Obvious Architecture

**Two AI stages (both require structured output)**: subject-classifier-LM classifies everything → Accountant-concierge-LM only processes "financial" types. Whitelist check (disabled by default) sits between stages.

⚠️ **A "validation error" on subject-classifier-LM has two possible authors, and they need different fixes.** The node compiles `output profile`'s schema with Ajv *before* it ever sees model output, so the schema itself can be the thing that fails — which is a hard failure on every execution, not a flaky one. Two defects were fixed there on 2026-08-14: `required` listed `type_of_document` **twice** (JSON Schema requires those items to be unique; Ajv strict mode rejects the duplicate), and the system message ended `## Output` / `A JSON object with the following keys:` with **no keys after it** — the parser already injects the format instruction, so that header was a promise with nothing behind it, inviting the model to invent a shape. The other author is `gpt-oss-120b` itself wrapping its JSON in reasoning prose; that one is intermittent and `retryOnFail`/`maxTries: 2` covers a single miss. **Read the execution before assuming which**: `GET /api/v1/executions/{id}?includeData=true` — a schema failure names the schema, a parse failure says the output does not fit the format.

**Three Gmail labels**: `inProgress` is a temporary canary applied at start (Tag inProgress) and removed on success (Remove inProgress) — emails still carrying it indicate failed runs. `n8n` (Tag n8n) is a permanent success marker applied once after the Merge convergence node. `gdr` (Tag gdr) marks emails whose attachments were saved to Google Drive (attachment branch only). All three routing branches (ContactManager, notify, financial/fallback) converge at a 3-input Merge → Tag n8n → Remove inProgress.

**Silent-failure detection (in-band status signalling)**: The label pair is a monitoring strategy, not just bookkeeping. The error workflow catches *loud* failures — something throws, the handler alerts. It cannot catch *quiet* ones: a run that hangs, times out at the task runner, or is simply wired wrong never errors, so no alert is ever sent. The `inProgress` canary covers that gap — applied at entry, removed only on completion, so leftover markers ARE the failed runs. The signal rides *in-band* (on the emails themselves) rather than out-of-band on a separate channel, so there is no dashboard to check: search `label:inProgress` and the evidence sits in the inbox the user already opens. The 3-input Merge is what makes this trustworthy — it guarantees the tags fire exactly once per email regardless of which branches ran. Caveat: this proves a run *completed*, not that it produced correct data.

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
