# Smart Table Fill: Text-to-Structured-Data Extraction

Extract structured data from unstructured text into any Google Sheets table — zero schema configuration required.

## Video Tutorial

[**Watch on YouTube**](https://www.youtube.com/watch?v=OqA7aKWQ1q8) ![views](https://img.shields.io/youtube/views/OqA7aKWQ1q8?style=flat&label=)

<p align="center">
  <a href="https://www.youtube.com/watch?v=OqA7aKWQ1q8">
    <img src="https://img.youtube.com/vi/OqA7aKWQ1q8/mqdefault.jpg" alt="Watch the tutorial" width="400">
  </a>
</p>

## Workflow Preview

<p align="center">
  <img src="assets/cover.png" alt="Workflow Preview">
</p>

## ⚡ Quick Start
- [setup-guide.md](docs/setup-guide.md)
- [parameters.md](docs/parameters.md) - LIST MODE parameters
- [credentials-guide.md](../credentials-guide.md)

---

## 🌟 Use Cases

**Out-of-the-box:** CRM entries from recurring client emails

**Alternatives:** Survey answers, contact form submissions, job applications, quote requests

```mermaid
flowchart LR
    A[📥 Text Input] --> B{Extraction rules ready?}
    B -->|No| C[🤖 Create column instructions]
    C --> D
    B -->|Yes| D[🤖 Extract to columns]
    D --> E[📊 Write to Sheet]
    E ~~~ F[ ]
    classDef hidden fill:none,stroke:none,color:none
    class F hidden
```

> ### Auto-Schema Discovery
>
> Point it at any table — the workflow reads your column headers and builds the extraction schema dynamically. No manual field mapping needed.

## What it does

**📝 Input** → Paste unstructured text (notes, emails, etc.)
**🔍 Discover** → Reads your table's column headers automatically
**🧠 Extract** → LLM structures data to match your schema
**📊 Store** → Updates the matching row in Google Sheets

## Who it's for

Anyone converting unstructured notes into structured data — sales teams logging calls, researchers organizing notes, anyone with a messy inbox.

> **Learning resource**: See [JSON Worksheet](docs/json-worksheet.md) for a printable introduction to JSON and structured data.

> **Want a full CRM?** Combine with [03_inbox-attachment-organizer](../03_inbox-attachment-organizer) for auto-capture of contacts from incoming emails, organized folders, and AI-maintained profiles. See [email-crm-guide.md](docs/email-crm-guide.md).

## 🔗 Links

- [Video Tutorial](https://www.youtube.com/watch?v=OqA7aKWQ1q8)
