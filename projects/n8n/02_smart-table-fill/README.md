# Smart Table Fill: Text-to-Structured-Data Extraction

Extract structured data from unstructured text into any Google Sheets table — zero schema configuration required.

## Workflow Preview

<p align="center">
  <img src="assets/cover.png" alt="Workflow Preview">
</p>

📝 Any text input
🔍 Auto-discovers table schema
📊 Fills structured rows

---

## 🌟 Use Cases

**Out-of-the-box:** CRM entries from recurring client emails

**Alternatives:** Survey answers, contact form submissions, job applications, quote requests

## What it does

**📝 Input** → Paste unstructured text (notes, emails, etc.)
**🔍 Discover** → Reads your table's column headers automatically
**🧠 Extract** → LLM structures data to match your schema
**📊 Store** → Updates the matching row in Google Sheets

## Who it's for

Anyone converting unstructured notes into structured data — sales teams logging calls, researchers organizing notes, anyone with a messy inbox.

## 🎯 Two Setup Modes

| Setup | Description |
|-------|-------------|
| **A) Standalone** | Manual text input via String Input node |
| **B) Email-CRM** | Auto-process incoming emails (uses nodes from [03_inbox-attachment-organizer](../03_inbox-attachment-organizer/)) |

> ### Auto-Schema Discovery
>
> Point it at any table — the workflow reads your column headers and builds the extraction schema dynamically. No manual field mapping needed.

## ⚡ Quick Start
- [setup-guide.md](docs/setup-guide.md)
- [credentials-guide.md](../credentials-guide.md)

## 📦 Requirements

- n8n ([cloud](https://n8n.cloud) or [self-hosted](https://youtu.be/kq5bmrjPPAY))
- Google Sheets
- Chat model (Groq — free)
