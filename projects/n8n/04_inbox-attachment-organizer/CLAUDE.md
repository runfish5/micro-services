# CLAUDE.md — 04 inbox-attachment-organizer

n8n workflow that files email attachments to Google Drive using AI. Design priorities: one Google
OAuth for Gmail, Drive and Sheets, and two AI stages to cut cost (a cheap classifier for every
email, the extractor only for financial ones).

**Read `mainflow.md` before the workflow JSON.** It has the node-by-node flow and the sub-workflow
call points.

## Where things are

| File | What |
|---|---|
| `workflows/inbox-attachment-organizer.json` | main workflow (55 nodes) |
| `../shared/llm-rate-limit.json` | what a failed LLM call does next: wait out a per-minute 429, stop on a per-day one. Called by the classifier, the extractor and smart-table-fill. Live ID `ZApb5gbnxdZaUR5S` |
| `workflows/subworkflows/stopped-emails.json` | the held-back list: the briefing's `inbox` section and `/rerun_attachments` (menu-handler agent). Live ID `7A07MNHtaj2tnbbX` |
| `workflows/subworkflows/gmail-processor-datesize.json` | Gmail search → target workflow per email. Its Config defaults catch up the organizer. Live ID `eShHXaF_dgYe0K2lMb8AY`. Docs: `docs/gmail-processor-datesize.md` |
| `workflows/gmail-backup.json` | standalone backup, verify and restore of the mailbox. Live ID `13vNowtGuPAKnfhj`. Docs: `docs/gmail-backup.md` |
| `../03_any-file2json-converter` | converts each attachment to text. See its `CLAUDE.md` |
| `../shared/gdrive-recursion.json` | path → Drive folder ID through the `PathToIDLookup` sheet; creates missing folders. Live ID `zBC03d42z8A_SjE0JSM5G` |
| `../02_smart-table-fill` | the contact branch calls `record-search` and `smart-table-fill` (named `smart-CRM-fill` on the instance) |
| `docs/setup-guide.md` | setup steps, `Billing_Ledger` (16 columns) and `PathToIDLookup` schemas |
| `docs/template-listing.md` | the creator-portal fields as submitted. Rules: `../docs/template-submission.md`; the main sticky lives only in the JSON |

`gmail-processor-datesize` and `gmail-backup` are independent: neither calls the other.

## Ledger grain

**One row per invoice, keyed by `invoice_number`.** Invoice + receipt = 1 row. Two orders = 2
rows. Row count never follows attachment or email count. Case table: `README.md` FAQ.

`Prepare Ledger Row` groups by `invoice_number`; `Upsert Ledger Row in Sheets` uses `appendOrUpdate` on that
column. `16_commitments-ledger` reconciles against these rows; nothing in that matching may write
back into either book.

Rules for `Prepare Ledger Row`, and for any many-to-one Code node:

1. **`pairedItem` is mandatory.** Without it `Build Report Message` fails with "Paired item data ...
   is unavailable" *after* the sheet write: the ledger is correct while the run reads as failed.
2. **Placeholder invoice numbers are not keys.** `-`, `N/A`, `UNKNOWN` and the like get an
   `AUTOKEY::<party>::<date>::<msg-id>` key. The message id is required (one sender can send two
   unkeyed documents on one day). "Contains `::`" finds every project-assigned key.

## LLM limits

- One email costs about 5,000 tokens: classifier (about 1.9k), one extractor call per attachment
  (2.4k–3.8k), contact branch.
- **Every LLM call runs before the first write.** Classifier, then (financial only) the extractor
  one document per pass (`Loop Over Documents`), then the contact fill, then `Route by Email
  Category` and the writes: Drive, ledger, report. The documents rejoin the filing branch at
  `Join Documents`. So a stop on a daily quota leaves nothing written, and a rerun files the email
  once; no write needs a check-before-write. Keep it that way: a new LLM call goes before the router.
- **Every 429 asks `llm-rate-limit`.** `Classify Email` and `Extract Invoice Data` (and
  smart-table-fill's batch extraction) leave on their error output to an Execute Workflow node. The
  sub-workflow repeats the call with one token to read the limit the LLM node drops. Per minute: it
  waits what the provider names and the caller sends the same item again, at most 6 times. Per
  day: the email is held back (below). Any other error: `Fail With LLM Error` fails the run with
  the LLM's message. Not covered: contact-memory-update's own LLM (called async by the fill, after
  every guarded call) and the fill's rare `Generate Schema with LLM`.
- A free tier with 200,000 tokens per day covers about 40 emails per day. A backlog needs a paid
  tier: about 20 s per email, no pause needed.
- **A MIME image is not an attachment.** `Drop Inline Images` drops every part whose bytes the HTML
  embeds (the mail parser turns each `cid:` part into a `data:` URI), so logos and signatures never
  reach the vision LLM, the extractor or Drive. The rest are renumbered from `attachment_0`.
- The vision LLM free tier allows 5 requests per minute and 20 per day. The converter sends one
  image at a time, 13 s apart **across all runs**: the next free slot is one row in the data table
  `vision_pacing`, taken by compare-and-swap, so overlapping organizer runs (a poll during a
  backfill) still queue. A per-minute 429 that gets through anyway waits and retries. The daily
  cap is not paced, so a backlog of real image attachments still needs a paid tier.
- **A used-up daily vision quota holds the email back, it does not file it.** The converter reads
  the 429 body (the LLM node drops it, so `Read Quota Error` repeats the call over HTTP) and only a
  per-DAY quota id blocks; the per-minute one waits and retries. The block is a row in the data
  table `vision_quota`; until it expires no image is sent. Each held-back email gets a row in
  `stopped_emails`, keeps `inProgress`, and the first one per model and quota day (same reset hour
  or same local day) sends one Telegram message with a Rerun button. The classifier, the extractor
  and the contact fill hold back the same way on their per-day limit: same list, `stopped_by` names
  the stage, the message names stage, model, limit and reset. The briefing shows an alert while
  rows remain.
  `/rerun_attachments` clears the block and runs every row again: use it after a key or model
  change, before the reset. The HTTP repeat costs one request when the window has just cleared.
- The classifier reads at most 12,000 characters of the body: a free-tier request above 8,000
  tokens is refused as too large ("your request is invalid").

## Non-obvious architecture

**One execution per email.** The trigger hands each email to `Process Each Email`, which runs this
workflow again from the catch-up entry. Everything after the entry reads one email (`first()`, one
cleaned body), so a poll that returned several emails used to file the first and leave the rest in
`inProgress` with no error. `Merge All Branches` passes on one item (choose branch, input 2):
labels set once. Inputs 1 and 2 both come from `If Contact Stopped`, after the last LLM call:
measured in a sandbox (executions 14699–14702), n8n runs a 3-input choose-branch Merge at the end
of a run when 2 of its 3 inputs have data, never with 1; a 2-input one never runs with 1.

**Backfill has one path: `gmail-processor-datesize` with its Config defaults.** Open it, click
**Execute workflow**, and click again until `Summarize Run` shows `left_for_next_run: 0`. From an
agent session, call it from a throwaway webhook workflow that passes nothing (at most
`max_emails`), then delete that workflow. It finds the emails the organizer missed and runs the
organizer's catch-up entry once per email, one after another, 45 s apart, so each passes the same
guards as live mail: inline images dropped, the shared vision slot, the per-minute waits, and the
stopped list when any daily quota runs out (one alert per model and day, the run goes on;
`/rerun_attachments` files them after the reset). A per-minute 429 that outlasts 6 waits fails
the target run: the processor stops there after one alert, and the next click continues. Never call the organizer directly in a loop, and never
start two backfills at once.

**Three Gmail labels.** `inProgress` is set at the start and removed at the end, so an email that
keeps it is a failed run, including runs that hung or were wired wrong and never raised an error.
`n8n` marks a finished run. `gdr` marks a saved attachment. The contact branch and the routed
branch (notify, financial, fallback) converge at `Merge All Branches` → `Add n8n Label` → `Remove inProgress Label`; the Merge is
what guarantees the tags fire exactly once. This proves a run completed, not that its data is right.

**Optional archiving.** `archive_when_filed` is a field in the node `Set Run Config` (default
`false`). When `true`, `Remove inProgress Label` also removes `INBOX` from an email whose document
was filed (`Add gdr Label` ran). It is a label change only and runs last, so a failed run never archives.

**A "validation error" on `Classify Email` has two possible causes.** The node compiles the
schema of `Classifier Output Schema` before it sees model output, so a schema defect (for example a
duplicate entry in `required`) fails every run. A model wrapping its JSON in prose fails only now
and then, and `maxTries: 2` covers it. Read the execution to tell which: a schema failure names
the schema, a parse failure says the output does not fit the format.

**Financial emails without attachments** skip the Drive upload but are still written to the ledger
and reported.

**The catch-up search excludes `label:gdr`** because `Upload File to Drive` is a plain upload: a
second run would store the file twice. It excludes `category:promotions` because the called path
enters at `Set Run Config` and skips `Skip Promotions`. Keep the processor rule-free: no whitelist,
no labels.

**`PathToIDLookup` is keyed on `path` alone.** A test copy with another `root_folder_id` but the
same `target_path` gets a cache hit and writes into the real `/Accounting` tree. A test must
change `root_path` and `root_folder_id` together.

**No successful-run history.** The organizer and the five workflows it calls run with
`saveDataSuccessExecution: none`. Failed runs are kept; the error handler needs them. To inspect a
successful run, switch the setting on for that one workflow, temporarily.

**`gmail-backup` stores nothing in n8n, on purpose.** Keep `saveDataSuccessExecution: none` and
`saveDataErrorExecution: none`, and keep `Save Email to Drive` as one HTTP request: a Convert to
File + Drive node pair would write every email into n8n's own database.
