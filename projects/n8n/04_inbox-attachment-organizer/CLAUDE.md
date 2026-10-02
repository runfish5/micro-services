# CLAUDE.md — 04 inbox-attachment-organizer

n8n workflow that files email attachments to Google Drive using AI. Design priorities: one Google
OAuth for Gmail, Drive and Sheets, and two AI stages to cut cost (a cheap classifier for every
email, the extractor only for financial ones).

**Read `mainflow.md` before the workflow JSON.** It has the node-by-node flow and the sub-workflow
call points.

## Where things are

| File | What |
|---|---|
| `workflows/inbox-attachment-organizer.json` | main workflow (37 nodes) |
| `workflows/subworkflows/gmail-processor-datesize.json` | Gmail search → target workflow per email. Its Config defaults catch up the organizer. Live ID `eShHXaF_dgYe0K2lMb8AY`. Docs: `docs/gmail-processor-datesize.md` |
| `workflows/gmail-backup.json` | standalone backup, verify and restore of the mailbox. Live ID `13vNowtGuPAKnfhj`. Docs: `docs/gmail-backup.md` |
| `../03_any-file2json-converter` | converts each attachment to text. See its `CLAUDE.md` |
| `../shared/gdrive-recursion.json` | path → Drive folder ID through the `PathToIDLookup` sheet; creates missing folders. Live ID `zBC03d42z8A_SjE0JSM5G` |
| `../02_smart-table-fill` | the contact branch calls `record-search` and `smart-table-fill` (named `smart-CRM-fill` on the instance) |
| `docs/setup-guide.md` | setup steps, `Billing_Ledger` (16 columns) and `PathToIDLookup` schemas |
| `main-sticky-note.md` | source text of the yellow main sticky. Keep it identical to `Sticky Note13` in the JSON |

`gmail-processor-datesize` and `gmail-backup` are independent: neither calls the other.

## Ledger grain

**One row per invoice, keyed by `invoice_number`.** Invoice + receipt = 1 row. Two orders = 2
rows. Row count never follows attachment or email count. Case table: `README.md` FAQ.

`Prepare Ledger Row` groups by `invoice_number`; `insert doc record` uses `appendOrUpdate` on that
column. `16_commitments-ledger` reconciles against these rows; nothing in that matching may write
back into either book.

Rules for `Prepare Ledger Row`, and for any many-to-one Code node:

1. **`pairedItem` is mandatory.** Without it `craft report note` fails with "Paired item data ...
   is unavailable" *after* the sheet write: the ledger is correct while the run reads as failed.
2. **Placeholder invoice numbers are not keys.** `-`, `N/A`, `UNKNOWN` and the like get an
   `AUTOKEY::<party>::<date>::<msg-id>` key. The message id is required (one sender can send two
   unkeyed documents on one day). "Contains `::`" finds every project-assigned key.

## LLM limits

- One email costs about 5,000 tokens: classifier (about 1.9k), one extractor call per attachment
  (2.4k–3.8k), contact branch.
- **On a free tier with 8,000 tokens per minute, an email with three or more documents fails.**
  Not fixed. `batching.delayBetweenBatches` on `Accountant-concierge-LM` does nothing at
  `batchSize: 1`, and node retries wait at most 5 s. A real fix paces the attachments outside the
  node (a loop + wait in front of the extractor, as in `gmail-processor-datesize`); mind rule 1
  above when adding it.
- A free tier with 200,000 tokens per day covers about 40 emails per day. A backlog needs a paid
  tier: about 20 s per email, no pause needed.
- Every inline image is one vision request. A catch-up run needs a vision-capable LLM without a
  tight per-minute limit.

## Non-obvious architecture

**Three Gmail labels.** `inProgress` is set at the start and removed at the end, so an email that
keeps it is a failed run, including runs that hung or were wired wrong and never raised an error.
`n8n` marks a finished run. `gdr` marks a saved attachment. All three branches (contact, notify,
financial/fallback) converge at a 3-input Merge → `Tag n8n` → `Remove inProgress`; the Merge is
what guarantees the tags fire exactly once. This proves a run completed, not that its data is right.

**Optional archiving.** `archive_when_filed` is a field in the node `Set File ID` (default
`false`). When `true`, `Remove inProgress` also removes `INBOX` from an email whose document was
filed (`Tag gdr` ran). It is a label change only and runs last, so a failed run never archives.

**A "validation error" on `subject-classifier-LM` has two possible causes.** The node compiles the
schema of `output profile` before it sees model output, so a schema defect (for example a
duplicate entry in `required`) fails every run. A model wrapping its JSON in prose fails only now
and then, and `maxTries: 2` covers it. Read the execution to tell which: a schema failure names
the schema, a parse failure says the output does not fit the format.

**Financial emails without attachments** skip the Drive upload but are still written to the ledger
and reported.

**The catch-up search excludes `label:gdr`** because `save doc to folder` is a plain upload: a
second run would store the file twice. It excludes `category:promotions` because the called path
enters at `Set File ID` and skips `Stop promotions`. Keep the processor rule-free: no whitelist,
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
