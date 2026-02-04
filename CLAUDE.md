# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## SECURITY - Public Repository

This repository is **PUBLIC**. Never commit:
- Telegram chat IDs or bot tokens
- n8n credential IDs (the `"id"` field inside `"credentials"` blocks)
- Google Sheet document IDs
- API keys, JWT tokens, or passwords
- The n8n instance URL

Use placeholder values (e.g., `CREDENTIAL_ID_TELEGRAM`, `YOUR_CHAT_ID_1`) in all committed files.
Actual values belong in `.env` files (already gitignored) or in the n8n instance directly.

## Home Lab Context

This repository supports a **home lab automation setup**. Key infrastructure:

- **n8n instance**: Hosted on Railway at `YOUR_N8N_INSTANCE.up.railway.app`
- **Claude's role**: Supervisor - monitors executions, debugs failures, retries workflows
- **API credentials**: Stored in `.claude/n8n-api.env`


### n8n Access Methods

Two ways to interact with n8n (see `.claude/skills/n8n-executions/skill.md` for details):

| Task | Use |
|------|-----|
| Search/view/execute workflows | **MCP tools** (built-in auth) |
| Fetch execution logs, debug, retry | **REST API** (requires API key) |

**Skill**: `/n8n-executions` - Fetch recent execution logs

## Code Patterns

Collection of n8n automation workflows for document processing and AI-powered data extraction. Projects connect LLMs to real tasks: batch processing spreadsheets, organizing email attachments, extracting structured data from messy text. Runs on Groq and Gemini free tiers.

### Repository Structure

```
projects/n8n/
├── 00_telegram-invoice-ocr-to-excel/  - Photo → Telegram bot → Google Sheets
├── 01_LLM-bulk-responses/             - Batch process spreadsheet rows with AI
├── 02_smart-table-fill/               - Text in, structured data out
├── 03_any-file2json-converter/        - File to JSON converter (subworkflow)
├── 04_inbox-attachment-organizer/     - Email attachments → AI → Google Drive
|   └── 04_expense-analytics/              - Monthly expense chart to Telegram
├── 10_steward/                        - Personal assistant: briefing, dispatch, subworkflows
└── 11_n8n-ops-center/                 - Workflow monitoring: /status, /failures, /retry
```

Projects 02, 03, and 04 have their own `CLAUDE.md` files with detailed architecture documentation.

## n8n Workflows

n8n workflows are JSON-based node configurations. Key practices:

- **Minimize node additions**: When modifying workflows, prefer expression changes in existing nodes over adding new nodes. Use n8n's expression language (ternaries, context variables like `$('NodeName').context['currentRunIndex']`) to add conditional logic without structural changes.
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

**Incident retry mechanism**: For workflows that retry failed executions, ALWAYS use the n8n API retry endpoint (`POST /api/v1/executions/{id}/retry`), NOT Execute Workflow nodes. API retry preserves original trigger data (Gmail messages, webhooks, etc.) while Execute Workflow starts fresh with no context. See `projects/n8n/04_inbox-attachment-organizer/config/8-hour-incident-resolver-docs.md` for rationale


### Key Documentation

- `projects/n8n/troubleshooting.md` - Common issues and fixes
- `projects/n8n/credentials-guide.md` - Setting up API credentials
- `projects/n8n/docs/observability-through-llm-confidence-estimate.md` - LLM confidence scoring pattern
- `.claude/skills/n8n-executions/skill.md` - When to use MCP vs REST API
- `projects/n8n/docs/row-index-pattern.md` - Batch table operations pattern
- `projects/n8n/docs/n8n-retry-api-reference.md` - n8n API retry endpoint behavior
