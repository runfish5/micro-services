## Quick Start

**Time:** <15 min | **Difficulty:** Easy | **Cost:** Free

> **Docs**
> - [parameters.md](parameters.md) - LIST MODE parameters
> - [json-worksheet.md](json-worksheet.md) - JSON intro worksheet
> - [email-crm-guide.md](email-crm-guide.md) - Email-CRM integration

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

**Want a full CRM?** Combine with [04_inbox-attachment-organizer](../../04_inbox-attachment-organizer) for a full contact management system — auto-capture contacts from incoming emails, organized folders, and AI-maintained profiles.

**➡️ [Email-CRM Setup Guide](email-crm-guide.md)**

---

*Optional: LLM confidence scoring available — see [observability-through-llm-confidence-estimate.md](../../docs/observability-through-llm-confidence-estimate.md)*
