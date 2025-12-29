# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Collection of n8n automation workflows for document processing and AI-powered data extraction. All projects are JSON-based n8n workflow exports.

## Repository Structure

```
projects/n8n/
├── 0_telegram-invoice-ocr-to-excel/  # Telegram bot → OCR → Google Sheets
├── 1_LLM-bulk-responses/             # Batch process data rows with LLM
├── 2_smart-table-fill/               # Text → structured data via dynamic schema
└── 3_inbox-attachment-organizer/     # Email attachments → AI classification → Google Drive
```

## Project-Specific Documentation

Projects 2 and 3 have their own CLAUDE.md files with detailed workflow documentation:
- `projects/n8n/2_smart-table-fill/CLAUDE.md`
- `projects/n8n/3_inbox-attachment-organizer/CLAUDE.md`

## Common Patterns Across Projects

**mainflow.md Convention:** Always read `docs/mainflow.md` before examining workflow JSON files. Keep it updated when workflows change. If you discover discrepancies between mainflow.md and the actual JSON, notify the user.

Structure: 🔄 **Main Flow** title (with node count) → 📋 **Overview** one-liner → 🎯 **Flow Summary** (phases, data flow diagram, lineage tree) → 🦜 **AI Model Nodes** (input/output/purpose per LLM) → 🔗 **External Workflows** (if applicable) → 📝 **Notes**.

**LLM Integration:** Most workflows use Groq (free) or Gemini for AI processing. LLM nodes are documented in mainflow.md under 🦜 **AI Model Nodes**.

**Structured Output:** `.st.json` files contain JSON Schema examples for LLM structured output (see project 1). These schemas define the extraction format for AI responses.
