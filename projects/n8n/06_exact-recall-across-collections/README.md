# 13 - Exact Recall Across Collections

> Self-hosted vector search for sources too big to paste. Drop in books, transcripts, whole projects; ask a question; get the passage and where it came from.

**Status: initial commit.** Workflow imported and scrubbed. Docs, setup guide and node breakdown still to write.

## Why this exists

Beyond Ctrl-F.

A model does not go blank on a book you have read. It gives you four of the five rules, confidently, well written, and nobody notices the fifth is missing. There is no error message for an omitted detail. **It knows roughly. You need exactly.**

Most of the time plain prompting is fine. This is for when the source is far too large to hand over: a 400-page book, hours of transcript, ten unrelated project trees. You cannot paste them, so instead of feeding the whole thing you feed the three paragraphs that matter, and the quality of the answer becomes the quality of the retrieval.

That is a trade of a context-window limit for a retrieval problem, and it is the only trade available at this size.

## What it does

```
Google Drive folder ──▶ 03_any-file2json-converter ──┬─▶ prose  ─▶ chunk ─▶ embed ─▶ documents        (pgvector)
                                                     └─▶ tables ─▶ rows          ─▶ document_rows     (jsonb)
                                                                                    document_metadata

Question ──▶ retrieval ──┬─▶ SQL         aggregate questions over tabular rows
                         └─▶ similarity  "which source said this", with the passage returned
```

Extraction is not reimplemented here. The workflow calls **`03_any-file2json-converter`** (`GtcLjBMusAUB0h30`), which already forces PDFs, DOCX and images into one text shape. When 03 gains transcription, audio and video arrive here for free and nothing in this project changes.

Re-ingestion is idempotent: rows for a `file_id` are deleted before the file is embedded again.

## Requirements

| | |
|---|---|
| Database | PostgreSQL with the `vector` extension (pgvector) |
| Embeddings | Google Gemini, 768 dimensions |
| Models | Groq and OpenAI chat models |
| Source | Google Drive folder |
| Extraction | `03_any-file2json-converter` |

The workflow creates three tables on first run: `documents` (content, metadata, `vector(768)`), `document_metadata` (id, title, url, schema) and `document_rows` (tabular data as JSONB, so it stays SQL-queryable instead of being embedded). It also creates `match_documents(query_embedding, match_count, filter)`, which is cosine similarity with a metadata filter, so retrieval can be narrowed to one source or one kind of source.

Change the embedding model and the `vector(768)` dimension must change with it.

## Post-import setup

Replace the placeholders after importing:

| Placeholder | What to set |
|---|---|
| `CREDENTIAL_ID_POSTGRES` | Postgres credential |
| `CREDENTIAL_ID_SUPABASE`, `CREDENTIAL_ID_SUPABASE_ALT` | Supabase credentials, if you keep those nodes |
| `CREDENTIAL_ID_GEMINI` | Google Gemini API |
| `CREDENTIAL_ID_GROQ` | Groq API |
| `CREDENTIAL_ID_OPENAI` | OpenAI API |
| `CREDENTIAL_ID_GOOGLE_DRIVE`, `CREDENTIAL_ID_GOOGLE_SHEETS` | Google OAuth |
| `YOUR_SOURCE_FOLDER_ID` | Drive folder to ingest |
| `YOUR_EVAL_SHEET_ID` | Sheet holding the evaluation set |

## Origin

Built for **n8n's first Agentic Arena community contest**, September 2025 ($10,000 prize pool, 200 prizes). The contest supplied the task and a template workflow, and required that the evaluation nodes be kept unchanged, since submissions were scored on those numbers. Entrants were free to choose models and retrieval approach.

Starting point was **Cole Medin's agentic RAG template**. Reworked over roughly two months since.

**What came from the contest, not from this repo:** the task specification, the base template, and the LLM-as-judge evaluation harness (`Eval Set`, `Run Evaluation`, `Save Eval`, `LLM as a Judge`).

## Still to do

- [ ] Delete the Supabase path. Postgres does the whole job, and a second service is the main setup barrier.
- [ ] `mainflow.md` node breakdown, matching `04` and `12`.
- [ ] Setup guide, including the pgvector install step.
- [ ] Rename the nodes carried over from the template (`Edit Fields7`, `SO1`, `Work your Magic here`).
- [ ] Register in `../general-registry.md` once the workflow ID on the instance is known.
