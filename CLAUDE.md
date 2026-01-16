# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Patterns

Collection of n8n automation workflows for document processing and AI-powered data extraction. Projects connect LLMs to real tasks: batch processing spreadsheets, organizing email attachments, extracting structured data from messy text. Runs on Groq and Gemini free tiers.

### Repository Structure

```
projects/n8n/
├── 00_telegram-invoice-ocr-to-excel/  - Photo → Telegram bot → Google Sheets
├── 01_LLM-bulk-responses/             - Batch process spreadsheet rows with AI
├── 02_smart-table-fill/               - Text in, structured data out
└── 03_inbox-attachment-organizer/     - Email attachments → AI → Google Drive
```

Projects 02 and 03 have their own `CLAUDE.md` files with detailed architecture documentation.

## n8n Workflows

n8n workflows are JSON-based node configurations. Key practices:

- **Always read `workflows/mainflow.md` first** before looking at workflow JSON files. The JSON is machine-readable but difficult to understand without the documentation context.
- **Edit in n8n UI** for logic changes (visualizes data flow), then export as JSON for version control.
- **Use execution logs and debug mode** to trace data transformations between nodes.
- **Replace triggers with Manual Trigger** when testing to avoid waiting for polling intervals.
- **Republish subworkflows** after changes - parent workflows call the published version, not your draft.

**`.st.json` files**: JSON Schema examples for LLM structured output (project 01).

### Common Troubleshooting

**Subworkflow changes not reflected**: You tested the subworkflow directly but forgot to republish. Fix: Republish the subworkflow. If publish fails with "1 node has issues", go to Executions → pick a successful run → Copy to Editor → Publish.

**LLM structured output errors**: Model failed to return valid JSON. Use a model with better structured output support (gpt-oss-120b recommended for open-source) or simplify the schema.

### Cross-Project Patterns

**Two-stage AI classification**: Cheap classifier LLM → expensive extractor LLM only for matching documents. Reduces costs.

**LLM confidence scores**: Structured outputs include `confidence` or `class_confidence` fields for observability. Thresholds: 0.9+ auto-process, 0.7-0.9 log for review, <0.7 flag for human verification.

**Google Apps Script integration**: n8n API writes don't trigger Sheets `onEdit`. Use Execution API to call Apps Script functions. Requires same GCP project for OAuth, local authorization first.

**Folder structure convention**: `/{RootFolder}/{Year}/{MM_Month}/{Category}/` with MM_Month format (01_January, 02_February) for sorted display.


### Key Documentation

- `projects/n8n/troubleshooting.md` - Common issues and fixes
- `projects/n8n/credentials-guide.md` - Setting up API credentials
- `projects/n8n/docs/observability-through-llm-confidence-estimate.md` - LLM confidence scoring pattern
