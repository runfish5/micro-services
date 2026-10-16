# Collectarium: real occurrences kept as dataset cases

One folder per occurrence, observed in our own systems, where an LLM did something wrong in a
way worth measuring. Collected as they happen, so a dataset can be built from the world and a
prompt optimized against it one day.

## A case is only useful with its real input and output

```
YYYY-MM-DD_<slug>/
  case.md       front matter (system, nodes, model, pipeline_version, tags) + Input / Output / Truth / Why a case
  input.*       the exact text the model saw: raw mail, attachment text, the rendered prompt if available
  output.*      the exact output: the model's JSON, the row it wrote, the message it sent
```

**Capture the raw input first, the day it is noticed.** It disappears: mail gets deleted, and the
n8n workflows keep no data for successful runs. Where to pull from:

| What | Where |
|---|---|
| Raw mail | Gmail (`get_message`), or the `.eml` in Drive `gmail-backup` (since 01.10.2026) |
| Failed run: full input and output per node | n8n REST `GET /api/v1/executions/{id}?includeData=true` |
| Successful run | not stored; read the row or message it produced, and note the gap |
| Prompt, schema, model | the workflow JSON at the commit live on that date (`git log --until`) |

If the raw input is gone, say so in `input.*` and keep the best reconstruction, marked as one.

**This repo is public.** Replace personal identifiers (the owner's name and address, account and
invoice numbers) with placeholders. Company senders and public content stay as they are.

## Tags

| Tag | Pattern |
|---|---|
| `keyword-hallucination` | A salient token decides the answer against the meaning of the text: an amount makes an offer an expense; "Switzerland" with a missing vendor makes the vendor Swisscom. |

Add a tag when a second case shares a pattern the first one did not name.
