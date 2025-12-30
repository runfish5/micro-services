# Bulk Data Processing Workflow

Process hundreds of rows automatically instead of manual repetition. Eliminates copy-pasting data rows for analysis one by one.

**Video Tutorial:** [Watch](https://www.youtube.com/watch?v=qR_nJLv_Z9g) ![views](https://img.shields.io/youtube/views/qR_nJLv_Z9g?style=flat&label=)

<p align="center">
  <a href="https://www.youtube.com/watch?v=qR_nJLv_Z9g">
    <img src="https://img.youtube.com/vi/qR_nJLv_Z9g/maxresdefault.jpg" alt="Watch the tutorial" width="400">
  </a>
</p>

🔄 Batch process rows
📂 Categorize content
🔍 Extract data

---

## 🌟 Use Cases

**Out-of-the-box:** Pulling out key info from care facility emails (costs, services, red flags, suitability scores)

**Alternatives:** Product descriptions, review sentiment, lead qualification, content tagging

## What it does

**📥 Load** → Pull rows from Google Sheets, CSV, or any data source
**🧠 Process** → LLM analyzes each row with your prompt
**📤 Output** → Structured results back to your spreadsheet

## Who it's for

Anyone doing repetitive data tasks: content managers, analysts, marketers processing large datasets for categorization, extraction, or analysis.

## Workflow Preview

<p align="center">
  <img src="assets/cover.png" alt="Workflow Preview" width="500">
</p>

## Structured Output

See `.st.json` files for JSON Schema examples.

## ⚡ Quick Start
- [setup-guide.md](docs/setup-guide.md)
- [credentials-guide.md](../credentials-guide.md)

## 📦 Requirements

- n8n ([cloud](https://n8n.cloud) or [self-hosted](https://youtu.be/kq5bmrjPPAY))
- Google Sheet with your data in a column (one item per row)
- Chat model (Groq, Gemini — both free)

## 🔗 Links

- [Video Tutorial](https://www.youtube.com/watch?v=qR_nJLv_Z9g)