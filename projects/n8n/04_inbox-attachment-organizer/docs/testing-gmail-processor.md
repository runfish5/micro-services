# Testing the Gmail Batch Processor

Step-by-step checks for `gmail-processor-datesize`.

## 1. Dry run

Set `email_limit` to `0` in **Config** and run it. **Search Gmail Messages** lists the matches
(up to 500 per window), then **Stop If Dry Run** stops before any target runs. This confirms the
credential works and shows exactly what a real run would process.

## 2. Count before you process

Paste the `query` into the Gmail search bar. That number (capped by `email_limit` per window) is
how many times the target will run. For the default search:

```
{-label:n8n label:inProgress} -label:gdr -category:promotions -in:draft -{subject:"n8n workflow failure alert" subject:"n8n infra/runner failure"}
```

## 3. Smallest real run

Send yourself one email with a PDF attached, then in **Config**:

| Field | Test value |
|---|---|
| `query` | `from:me has:attachment newer_than:1d -label:gdr` |
| `email_limit` | `1` |
| `lookback_days` | `1` |

`-label:gdr` skips the email if the live trigger filed it first; otherwise the file would be saved
twice.

Run it, then inspect:

- **Build Date Windows**: one window (yesterday to tomorrow)
- **Search Gmail Messages**: one item with an `id`
- **Run Target per Email**: the organizer's output, or an `error` item
- **Summarize Run**: `found: 1, failed: 0`
- In Gmail, the email now carries `n8n` (and `gdr` if the attachment was filed), and not `inProgress`

## 4. Idempotency check

With the default Config, run it until **Summarize Run** shows `left_for_next_run: 0`, then once more.
That last run should find only the emails that failed before (`found` near zero). If the same
emails keep coming back, the organizer isn't reaching `Tag n8n` for them. Open one of their
executions.

## 5. Reset Config after testing

Put `query`, `email_limit: 500` and `lookback_days: 365` back (the defaults in
[gmail-processor-datesize.md](gmail-processor-datesize.md#configuration)).
