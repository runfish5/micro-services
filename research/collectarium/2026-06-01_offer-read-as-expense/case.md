---
date: 2026-06-01
system: n8n inbox-organizer (04)
nodes: subject-classifier-LM → financial doc router → Accountant-concierge-LM
model: openai/gpt-oss-120b via Groq (both nodes)
pipeline_version: git 7f289ea, projects/n8n/04_inbox-attachment-organizer/workflows/inbox-attachment-organizer.json (last commit before the event; live may have differed)
tags: [keyword-hallucination]
found: 2026-10-16, as an unexplained "Olly 150" bar in the monthly expense chart
---

## Input

`input.md`: a founder newsletter offering the recipient $150 for a product walkthrough video.
No attachment, no invoice number, no payment details. The recipient never used the product.

## Output

`output.json`, the exact ledger row: Expense, counterparty `Olly`, 150 USD, invoice number
`N/A`, payment terms `upon receipt`.

Stage by stage:
1. Classifier: `type_of_document = financial`. The prompt rule at the time: *"ANY email involving
   money ... If money is mentioned, classify as financial."*
2. Router sent it to the extractor.
3. Extractor filled the invoice schema anyway, with the founder's first name as counterparty.

## Truth

Not a transaction, and the money would flow to the recipient. `informational`; no ledger row.

## Why a case

The amount is the keyword. The rule keys on a token instead of on what the document does, and
the extractor, once told "this is an invoice", fills every field rather than refusing. Two
probes for an optimizer: (a) direction, who pays whom; (b) an extractor that may answer "not an
invoice".
