# Smart Table Fill: Text-to-Structured-Data Extraction

Extract structured data from unstructured text into any Google Sheets table — zero schema configuration required.

<p align="center">
  <img src="assets/cover.png" alt="Workflow Preview">
</p>

## ⚡ Quick Start
- [Setup Guide](docs/setup-guide.md) — smart-table-fill
- [Setup Guide](docs/setup-guide-folder2table.md) — smart-folder2table
- [credentials-guide.md](../credentials-guide.md)
---


## What You'll Build

Give it any text and any table. The workflow reads your column headers, builds extraction rules on its own, and fills the table. Zero configuration.

**Two workflows, same idea:**

| | smart-table-fill | smart-folder2table |
|---|---|---|
| **Input** | Paste any text | Point at a Google Drive folder |
| **Output** | One structured row | One row per file in the folder |
| **Best for** | Emails, notes, scraped pages | Batch image/document processing |

---

## 📋 Features

| Feature | STF | F2T |
|---------|:---:|:---:|
| Auto-creates schema sheet on first run — no manual field mapping | ✅ | ✅ |
| Update existing rows or append-only (`match_same_row`) | ✅ | ✅ |
| Column batching — splits wide schemas across multiple LLM calls (`batch_size`) | ✅ | ✅ |
| Resumability — skips already-processed files on retry | ❌ | ✅ |
| File filtering — `file_include`, `file_exclude`, `file_limit` | ❌ | ✅ |
| Adaptive rate limiting — starts fast, error handler injects delay on 429 | ❌ | ✅ |

> **STF** = smart-table-fill · **F2T** = smart-folder2table

## Try It Yourself

> **`15 min` · Free tier · No coding required**
>
> Follow the step-by-step [Setup Guide](docs/setup-guide.md) to go from zero to your first extraction.

---

## Video Tutorials

### smart-table-fill

Paste any text, get a structured row in your spreadsheet.

[**Watch on YouTube**](https://www.youtube.com/watch?v=OqA7aKWQ1q8) ![views](https://img.shields.io/youtube/views/OqA7aKWQ1q8?style=flat&label=)

<p align="center">
  <a href="https://www.youtube.com/watch?v=OqA7aKWQ1q8">
    <img src="https://img.youtube.com/vi/OqA7aKWQ1q8/mqdefault.jpg" alt="Watch the tutorial" width="400">
  </a>
</p>

### smart-folder2table

Point at a Google Drive folder, get one row per file.

[**Watch on YouTube**](https://www.youtube.com/watch?v=iwbcNdQrwjU) ![views](https://img.shields.io/youtube/views/iwbcNdQrwjU?style=flat&label=)

<p align="center">
  <a href="https://www.youtube.com/watch?v=iwbcNdQrwjU">
    <img src="https://img.youtube.com/vi/iwbcNdQrwjU/mqdefault.jpg" alt="Watch the tutorial" width="400">
  </a>
</p>

---

## See It Work: Image Classification

> **6 images. 8 extraction fields. 4 mistakes.**
>
> Jensen Huang at a keynote, AI-generated cyberpunk art, a movie poster — can an LLM classify them all?

| Image | image_type | primary_subject | action_happening | person_count | source_hint |
|-------|------------|-----------------|------------------|--------------|-------------|
| Jensen Huang + robot | photograph | Jensen Huang with Disney robot | presenting robot at keynote | 1 | camera_photo |
| Neon cyberpunk | digital_art | computer monitor with neon lighting | displaying code with glitch effects | 0 | ai_generated |
| Movie poster | poster | three western characters | facing viewer in triptych | 3 | graphic_design |
| Fox character | illustration | anthropomorphic fox with device | holding glowing gadget | 0 | ai_generated |
| Logic puzzle | diagram | visual reasoning grids | presenting puzzle challenge | 0 | graphic_design |
| Spectacles | photograph | glasses and document | resting on surface | 0 | camera_photo |

<details>
<summary><b>Where did the LLM get it wrong?</b></summary>

1. **Neon cyberpunk** — "displaying code with glitch effects" is wrong; it's stylized text, not code
2. **Movie poster** — `source_hint` should be `ai_generated`, not `graphic_design`
3. **Spectacles** — `image_type` is not `photograph`; it's a graphic design piece
4. **Spectacles** — `source_hint` should be `ai_generated`, not `camera_photo`

</details>

<details>
<summary><b>Schema used (copy to your sheet)</b></summary>

Add to your `Description_hig7f6` sheet to replicate:

| ColumnName | Type | Description | Classes |
|------------|------|-------------|---------|
| image_type | class | Category of image content | photograph,screenshot,illustration,poster,diagram,digital_art,meme |
| primary_subject | str | Main subject or focus of the image | |
| action_happening | str | What activity or event is taking place | |
| key_objects | list | Notable items, objects, or features visible | |
| visual_complexity | class | How busy or dense the image is | minimal,moderate,busy |
| source_hint | class | Likely origin of the image | camera_photo,ai_generated,graphic_design,screen_capture,scan |
| person_count | int | Number of people visible in the image | |
| faces_visible | class | Whether human faces are clearly visible | none,partial,clear |

</details>

---

## Two Workflows

This project contains two complementary extraction workflows:

| Scenario | Workflow |
|----------|----------|
| Extract from email/text | **smart-table-fill** — text in, structured row out |
| Process folder of images | **smart-folder2table** — one LLM pass per file |
| Simple extraction | Either works |

---

## How It Works

> **Auto-Schema Discovery** — Point it at any table. The workflow reads your column headers and builds the extraction schema dynamically. No manual field mapping.

```mermaid
flowchart LR
    A[Text Input] --> B{Extraction rules ready?}
    B -->|No| C[Create column instructions]
    C --> D
    B -->|Yes| D[Extract to columns]
    D --> E[Write to Sheet]
    E ~~~ F[ ]
    classDef hidden fill:none,stroke:none,color:none
    class F hidden
```

1. **Input** — Paste unstructured text (notes, emails, etc.)
2. **Discover** — Reads your table's column headers automatically
3. **Extract** — LLM structures data to match your schema
4. **Store** — Updates the matching row in Google Sheets

---

## Rate Limit Handling

**Manual mode**: If you hit rate limits, increase `rate_limit_wait_seconds` in Config (try 60s, or more if needed). Restart - resumability skips already-processed files.

**Production mode**: When published and called via subworkflow trigger, the 007-error-handler handles it automatically - extracts retry timing from 429 errors and restarts with the correct delay.

---

## Go Further

- [Email-CRM Guide](docs/email-crm-guide.md) — Combine with inbox-attachment-organizer for auto-capture of contacts from incoming emails
- [JSON Worksheet](docs/json-worksheet.md) — Introduction to JSON and structured data


---

## Who It's For

Anyone converting unstructured notes into structured data — sales teams logging calls, researchers organizing notes, anyone with a messy inbox.

> **Want a full CRM?** Combine with [04_inbox-attachment-organizer](../04_inbox-attachment-organizer) for auto-capture of contacts from incoming emails, organized folders, and AI-maintained profiles. See [email-crm-guide.md](docs/email-crm-guide.md).
