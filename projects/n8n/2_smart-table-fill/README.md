# Smart Table Fill: Text-to-Structured-Data Extraction

Extract structured data from unstructured text into any Google Sheets table — zero schema configuration required.

**Perfect for:** Converting notes, emails, or any text into structured table rows automatically.

---

## ⚡ Quick Start
- [setup-guide.md](docs/setup-guide.md)

## 📦 Requirements

- Google Sheets OAuth
- LLM: Groq (free)

## 🎯 Two Setup Modes

| Setup | Description |
|-------|-------------|
| **A) Standalone** | Manual text input via String Input node |
| **B) Email-CRM** | Auto-process incoming emails (uses nodes from [3_inbox-attachment-organizer](../3_inbox-attachment-organizer/)) |

> ### Auto-Schema Discovery
>
> Point it at any table — the workflow reads your column headers and builds the extraction schema dynamically. No manual field mapping needed.
