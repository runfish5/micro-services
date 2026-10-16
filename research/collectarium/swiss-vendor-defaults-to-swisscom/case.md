---
date: unknown            # recalled by the operator 2026-10-16; the original run is not pinned yet
system: invoice extraction (n8n inbox-organizer and the swiss-invoices evals)
tags: [keyword-hallucination]
---

## Input

A Swiss document where the vendor is missing or unreadable, while "Switzerland" / "Schweiz" or
other Swiss context appears in the text.

## Output

The model fills the vendor with the largest Swiss company it associates with the context:
Swisscom.

## Truth

Vendor unknown. The correct output is empty or `unknown`, never the most famous candidate.

## Why a case

The country is the keyword, and the model resolves a missing field to the prior instead of to
"absent". Same failure the lab's rule "absence is not a diagnosis" forbids.

**Incomplete: output only, input missing.** `output.json` holds the three ledger rows that name
Swisscom; one carries the placeholder invoice number `2024-06-RC-12345678`. None records a source
mail (`email_id` empty), so they predate the email pipeline or came through the photo route
(`00_telegram-invoice-ocr-to-excel`). To finish the case: find the document behind one row, put
it in `input.*`, and confirm it named no Swisscom. Next occurrence: capture it the same day.
