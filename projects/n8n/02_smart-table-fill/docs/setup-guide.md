## Quick Start

**Time:** <15 min | **Difficulty:** Easy | **Cost:** Free

Choose your setup:

| Setup | Description |
|-------|-------------|
| **A) Standalone** | Manual text input via String Input node |
| **B) Email-CRM** | Auto-process incoming emails |

---

## Setup A: Standalone

### 1. Import Workflow

Import [smart-table-fill.json](../workflows/smart-table-fill.json) into n8n.

**Important:** After importing, click **Publish** to save the workflow.

### 2. Setup Credentials

- Google Sheets OAuth
- Groq API key

### 3. Configure Target Sheet

Create a Google Sheet with your column headers. The workflow auto-discovers schema from headers.

### 4. Test

Modify the **String Input** node with your text, run manually.

---

## Setup B: Email-CRM

Copy the email pipeline from [inbox-attachment-organizer.json](../../03_inbox-attachment-organizer/workflows/inbox-attachment-organizer.json) — all nodes from **Gmail Trigger** through **subject-classifier-LM**.

Two integration modes:

| Mode | How |
|------|-----|
| **All-in-one** | Paste nodes directly into your workflow |
| **Subworkflow** | Call smart-table-fill via Execute Workflow trigger |

### Apps Script Integration (Advanced)

For automatic folder creation and contact management via Apps Script Execution API:

**[Apps Script Execution API Setup Guide](apps-script-execution-api-setup.md)**

This enables n8n to call Apps Script functions with secure OAuth authentication (no public endpoints, no tokens).

---

*Optional: LLM confidence scoring available — see [observability-through-llm-confidence-estimate.md](../../docs/observability-through-llm-confidence-estimate.md)*
