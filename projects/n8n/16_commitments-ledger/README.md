# 16 - Commitments Ledger

The second half of a pair. `04_inbox-attachment-organizer` writes the **Billing_Ledger** —
what counterparties *told us* they charged, extracted from documents they sent. This project
holds the **Commitments** ledger — what we *know we signed up for*, recorded by us, from our
side, without waiting for anyone to send anything.

Two independent records of the same reality. Reconciling them is the point: an invoice that
matches no commitment, a commitment that produced no invoice, and an amount that drifted are
all findable only when both books exist.

```
             we act                             they bill
                │                                   │
                ▼                                   ▼
        Commitments tab                       Billing_Ledger tab
     (this project, declarative)          (project 04, extracted)
                │                                   │
                └───────────────┬───────────────────┘
                                ▼
                         reconciliation
              missing charge · surprise charge · amount drift
```

## Grain

**One row per commitment version, keyed by `commitment_id`.**

The everyday reading is "one row per contract" — TalkTalk is one row, not one row per monthly
bill. Twelve identical rows for twelve identical months store nothing that `cadence` +
`amount_expected` does not already say, and a table that grows with time needs a generator
workflow to keep it fed.

The word *version* covers the one case where a contract legitimately becomes two rows: **the
terms change.** A price rise does not overwrite `amount_expected`, because that would
retroactively rewrite what we expected to pay last month and quietly break any reconciliation
of the past. Instead the current row gets a `valid_to`, and a new row opens with the new price
and a new `valid_from`. Same `commitment_id`, two versions, history intact.

| What happened | Rows |
|---|---|
| Signed one rolling monthly contract | **1** |
| That contract billed 14 times | **1** |
| Price rose in month 15 | **2** (first one closed with `valid_to`) |
| Cancelled it | **1** (`status: cancelled`, `valid_to` set) |
| Two contracts with the same vendor (mobile + fibre) | **2** |
| Same service, moved to a different vendor | **2** (one closed, one new) |

**Expected charges are never stored.** The charge due in any given month is computed from
`cadence`, `charge_day` and the row valid on that date. Storing them would mean a workflow
writing rows for a future that has not happened yet, and every one of those rows would be a
guess presented as a record.

**This table is never written by the reconciler.** It records intent; `Billing_Ledger` records
events. Letting a matching process write back into intent is how the two books stop being
independent — and the independence is the entire value of keeping two.

## No backfill

**Only commitments recorded from 2026-08-12 onward.** Older subscriptions are not reconstructed
from memory or from old invoices.

This is a deliberate limit, not laziness. A backfilled row is a guess wearing the same clothes
as a verified one, and the reconciler cannot tell them apart — it would report "no invoice for
July" for a contract whose July invoice simply predates the ledger.

The rule is enforced by the data, not by discipline: the reconciler never looks for charges
before a commitment's earliest `valid_from`, so a row added today can only ever be judged from
today forward. Backfilling later is possible by setting an earlier `valid_from` — but that is
then an explicit claim about the past, made on purpose.

## The store

A **`Commitments` tab in the same spreadsheet as `Billing_Ledger`** — same document, so
reconciliation reads both tabs through one credential and one Sheets node, and a spot-check by
hand is two clicks apart.

Paste into row 1:

```
commitment_id	vendor	service	category	amount_expected	currency	cadence	charge_day	due_day	payment_method	account_ref	match_hints	tolerance_pct	status	valid_from	valid_to	cancel_by	notes	verify_done
```

| Field | Description |
|-------|-------------|
| `commitment_id` | Dedup key. `<vendor-slug>::<service-slug>`, e.g. `talktalk::mobile` |
| `vendor` | Display name of the counterparty |
| `service` | What we get for the money — free text, for humans |
| `category` | `Expense` or `Revenue`. Mirrors `accounting_category` in Billing_Ledger |
| `amount_expected` | Recurring amount under *these* terms. Blank until the first real invoice teaches it |
| `currency` | CHF, EUR, USD |
| `cadence` | `monthly`, `quarterly`, `yearly`, `one-off` |
| `charge_day` | Day of month the **invoice is issued**. Blank until observed |
| `due_day` | Day of month the **money must be there**. `eom` for end-of-month. Blank = same as `charge_day` |
| `payment_method` | Controlled vocabulary — see below. Decides whether the briefing reminds |
| `account_ref` | The provider's identifier for us: customer number, phone number, account ID |
| `match_hints` | Pipe-separated strings that identify this vendor on an incoming invoice |
| `tolerance_pct` | Variance allowed before a matched charge is flagged as drift |
| `status` | `active`, `paused`, `cancelled` |
| `valid_from` | Date these terms took effect (YYYY-MM-DD) |
| `valid_to` | Blank while current. Set when terms change or the contract ends |
| `cancel_by` | Act-by date for a contract that auto-renews. Blank for rolling month-to-month |
| `notes` | Anything that does not fit above |
| `verify_done` | `yes` to let the audit reopen a `done` task with no invoice. Empty = off, the default |

### `charge_day` and `due_day` are two different days

The first real invoice made the case: issued the **5th**, payable by the **31st**. Twenty-six
days apart, and only one of them is a deadline.

The briefing shows every active commitment every morning, so this is not about *when* to speak
up — it is about what the countdown points at. Collapsing the two dates makes it point at the
wrong one: a bill issued on the 5th reads as overdue from the 6th while it is comfortably in
time until the 31st, and a line that cries wolf for twenty-five days a month stops being read.

`charge_day` is what the reconciler looks for in `Billing_Ledger`; `due_day` is what the
briefing counts down to. `eom` is stored rather than `31` because a literal 31 does not exist
in February.

### `payment_method` is a controlled vocabulary

| Value | Money moves | Briefing line reads |
|-------|-------------|---------------------|
| `qr-invoice` | we scan and pay it | **to pay** |
| `bank-transfer` | we initiate it | **to pay** |
| `twint` | we send it | **to pay** |
| `direct-debit` | they pull it | leaving |
| `card` | they charge it | leaving |

This is the one field that changes what the automation *does*, so it is a fixed vocabulary
rather than free text — unlike `payment_method` in `Billing_Ledger`, which is LLM-extracted
from whatever the document happened to say.

The split is between **money that leaves by itself** and **money that leaves only if we act**.
Both appear in the briefing every morning; only one of them is a task. A direct debit is
reported so the total is honest and a dead card is noticeable — forgetting it is impossible.
A QR invoice is a thing to *do*, and forgetting it is the entire failure mode. Rendering them
identically would bury the five minutes of actual work inside a list of things already handled.

### The first row, masked

```
commitment_id    talktalk::mobile
vendor           TalkTalk
service          Mobile subscription — phone + mobile internet
category         Expense
amount_expected  22.75
currency         CHF
cadence          monthly
charge_day       5                         ← invoice issued the 5th
due_day          eom                       ← payable by month end
payment_method   qr-invoice                ← manual, so the briefing reminds
account_ref      XXXXXXXXXX                ← customer number; real value in the sheet only
match_hints      talktalk|talk talk
tolerance_pct    10                        ← mobile bills move with roaming and overage
status           active
valid_from       2026-08-12
valid_to         (blank — current)
cancel_by        (blank — assumed rolling monthly)
```

Real values: `first-rows.local.tsv` in this folder, gitignored, tab-separated and paste-ready
into row 2.

**The August invoice is evidence, not a tracked charge.** It was issued 2026-08-05 — before
`valid_from` — so the reconciler will never look for it, exactly as the no-backfill rule
intends. It is used here only to learn the terms. The first period this ledger judges is
September: invoice expected around 05.09, due 30.09.

Set `valid_from` to `2026-08-05` instead if you would rather August count as the first
reconciled period. That is a legitimate move — but it is then an explicit claim that the
ledger covers August, not a silent side effect of having seen one email.

### Why `commitment_id` and not something we already have

There is no existing identifier to reuse. `Billing_Ledger` keys on `invoice_number` — that
identifies a *document*, and a contract is not a document. Every candidate borrowed from the
invoice side is either per-event (invoice number, payment reference) or unstable and
LLM-extracted (`counterparty_name` arrives as "TalkTalk", "Talk Talk AG", or "talktalk"
depending on the letterhead).

So the key is minted here, following the convention already established in project 04: **`::`
marks a key this repo assigned, never one a supplier issued.** `talktalk::mobile` is stable
because we choose it, readable in a Telegram message, and safe to put in a public repo — which
`account_ref` is not.

Google Sheets `appendOrUpdate` on `commitment_id` then makes re-entering a commitment
idempotent. The one case it does not cover is the deliberate second version after a price
change, where two live rows share an id; version-aware writes must key on
`commitment_id` + `valid_from`.

### Why the sensitive identifier sits in `account_ref` and nowhere else

`account_ref` holds the number the provider knows us by — for a mobile contract, the phone
number itself. That is personal data and this repo is public, so it lives **only in the Google
Sheet**, and in a gitignored `*.local.tsv` alongside this README for convenient re-paste.
Committed files use masked placeholders.

Confining it to one named column is what makes that rule enforceable: there is exactly one
place to check before a commit, and nothing downstream — reconciler output, briefing digest,
Telegram message — needs to read it. Matching runs on `match_hints`.

## Filling a row when the details are not known yet

A commitment is worth recording the day it is entered into, which is usually before the first
invoice arrives — so `amount_expected`, `charge_day` and `payment_method` start blank and are
filled in from the first charge that actually lands.

That is a deliberate ordering: the row exists from day one so the commitment is not forgotten,
and the fields that only reality can supply stay honestly empty rather than being guessed. A
blank `amount_expected` reconciles as "expected a charge, cannot check the amount" — still
useful, and never a false alarm about drift.

## The `Tasks` tab

`Commitments` says what we agreed to. It cannot say whether September's bill has been dealt
with, because that is not a property of the agreement — it is a property of one occurrence, and
it changes.

So occurrences get their own tab, and `Commitments` stays declarative and hand-written. Three
tabs, three jobs:

| Tab | Holds | Written by |
|-----|-------|-----------|
| `Commitments` | what we agreed to | a human, by hand |
| `Tasks` | what needs doing, and how it went | `task-generator`, the upkeep producers, then agents |
| `Billing_Ledger` | what the counterparty actually billed | project 04 |

### `Tasks` is the lab's table, not this project's

**Grain: one row per open obligation, keyed by `task_id`.**

The everyday reading is still "one row per (`commitment_id`, `period`)" —
`talktalk::mobile@2026-09` — and that remains the only shape *this* project writes. But the table
grew a second and third producer, and the grain had to be stated one level up to stay true:

| `task_id` | Producer | Arrives from |
|---|---|---|
| `talktalk::mobile@2026-09` | `task-generator` (this project) | a cadence rule |
| `self::code-health@a3f9c1e2` | `10_error-handler` | a failure signature that recurred |
| `self::code-health@visits-command` | a human typing | an Open thread in the root `CLAUDE.md` |

`self::code-health` is never a row in `Commitments`, which is exactly what makes the audit skip
those rows — its documented behaviour for an unknown `commitment_id`. The financial reconciler
and the upkeep lifecycle stay mutually invisible with no code guarding the boundary.

**16 is the custodian of this tab, not its owner.** Stating that matters: the next person to add
a column here should not assume it is free to be finance-shaped. Design and reasoning for the
other two producers: `10_error-handler/docs/upkeep-tasks-spec.md`.

Paste into row 1 of a `Tasks` tab in the same spreadsheet:

```
task_id	commitment_id	vendor	period	charge_date	due_date	amount	currency	payment_method	action	status	assignee	assigned_at	closed_at	evidence	attempts	notes	source
```

`status`: `open` → `assigned` → `done` | `wont_fix` | `failed`.

`source`: blank for anything generated (a commitment task, or the state row written when an
observed defect is tapped); `declared` for a hand-typed upkeep thread. Only the upkeep digest
reads it, and it reads it to answer one question — *did the lab find this, or did you?* An
observed row can be reopened by evidence; a declared one can only be closed by you.

`vendor`, `amount`, `currency` and `payment_method` are **denormalised** from the commitment at
generation time. That is deliberate twice over: the digest then reads one tab instead of
joining two, and the row preserves the terms as they stood when the task was created — so a
price rise in November does not silently rewrite what October's task was for.

### The generator appends, and must never upsert

`task-generator` runs daily, reads both tabs, and writes only `task_id`s that do not exist yet.

Switching that to `appendOrUpdate` looks equivalent and is the one change that would quietly
destroy the feature: every morning it would reset `status` and `assignee` to `open`, undoing
the previous day's taps and every agent result. The whole reason `Tasks` exists is to hold
state that cannot be recomputed, and an upsert recomputes it.

Running daily rather than monthly is what makes a commitment added today produce a task
tomorrow with nobody remembering to trigger anything. The diff is what makes running it 30
times a month harmless.

### No backfill is enforced on the charge date

A period is skipped when its **invoice date** falls before `valid_from` — not its due date.

The distinction is the difference between working and nagging: TalkTalk's August invoice was
issued on the 5th and is already paid, but it was not *due* until the 31st. Gating on the
deadline would have generated an August task and reminded about a settled bill for three
weeks. Verified: with `valid_from = 2026-08-12` the generator produces exactly one row,
`talktalk::mobile@2026-09`.

## The audit — what it can and cannot prove

Runs daily right after the generator. It reads `Billing_Ledger`, compares it to `Tasks`, and
writes findings back onto the task rows as `status` + `notes`. It never writes to
`Commitments`, and the briefing renders the findings without reading the ledger at all.

**`Billing_Ledger` holds invoices, not payments.** It can confirm a bill existed and what it
said. It cannot confirm money moved, unless a receipt happens to arrive and fill `date_paid`.
That single fact decides the whole design:

| Case | What happens | Why |
|------|--------------|-----|
| `done`, matching invoice found | left alone | No evidence source would justify second-guessing the claim |
| `done`, no invoice, **`verify_done` off** | left alone | The default — see below |
| `done`, no invoice, `verify_done` on, charge date past + grace | **reopened**, reason written to `notes` | That claim is about a bill that never existed |
| Invoice found, amount outside `tolerance_pct` | flagged in `notes` | Real drift, not rounding |
| Invoice within tolerance | silent | |
| Task whose `commitment_id` is unknown | skipped | |

### `verify_done` is opt-in, and off by default

Reopening is the only thing here that **overturns** a human decision rather than annotating it,
so it has to be asked for per commitment. Leave the column empty and a tick stays a tick.

It is also only meaningful where an absent document means something. TalkTalk bills by email but
never confirms payment — a QR invoice paid at the bank produces no receipt — so the audit has
nothing to find, and reopening on that silence would undo a tick every week for no reason. Set
`verify_done` to `yes` on commitments where a missing document really is evidence of a problem.

Drift detection is **not** gated: it only writes a note and never changes `status`, so it cannot
undo anything.

### Two timing rules the reopen obeys

- **An invoice cannot be missing before it was due to exist.** The check waits for
  `charge_date` + 7 days — the charge date has to have passed *and* `Billing_Ledger` needs time
  to receive it, since project 04 fills it from email rather than instantly.
- **An unparseable `charge_date` never reopens.** Missing data is a reason to leave a claim
  alone, not to overturn it.

Matching runs on `match_hints` against `counterparty_name` **and** `email_id`. The name is
LLM-extracted from whatever the letterhead said — "TalkTalk", "Talk Talk AG", "talktalk" — which
is exactly why `match_hints` exists; the address is the more reliable half.

**Findings are written only on change.** An unconditional upsert would rewrite every row every
morning, and a findings column that churns daily is one nobody reads. A finding that resolves
clears itself.

**`notes` on `Tasks` is machine-owned.** The audit overwrites it. Put human commentary in the
`Commitments` row instead.

### Not covered yet

An invoice matching **no commitment at all** — the forgotten subscription — is not reported.
It is the most valuable finding of the three, and the one with nowhere to go: the `Tasks` grain
is one row per (commitment, period), and an unrecognised charge has no commitment to hang on.
It needs its own surface rather than a row that lies about the grain.

## Reconciliation — the original sketch

The table is the prerequisite; the matching workflow is the payoff, and it is deliberately not
written until there are enough rows for its output to mean anything.

What it will do, once per month:

1. Read `Commitments` where `status = active` and the row is valid for the period.
2. Read `Billing_Ledger` rows in the period.
3. Match on `match_hints` against `counterparty_name` and `email_id` — `email_id` is the more
   reliable of the two, being a real address rather than an LLM's reading of a letterhead.
4. Report three things, all of them a question rather than an action:
   - **Missing** — commitment active, charge_day passed, no invoice matched.
   - **Unexpected** — invoice in the ledger matching no active commitment.
   - **Drift** — matched, but outside `tolerance_pct`.
5. Alert on `cancel_by` dates coming up inside their notice window.

Nothing in that list writes back to `Commitments`. The report is for a human to read and then
decide whether the *intent* record needs correcting.

## Workflows

**One workflow, `workflows/commitments.json`**, with three branches:

| Branch | Entry | What it does |
|--------|-------|--------------|
| generate | `Daily 06:30` (+ Manual) | `Commitments` → `Tasks`, append-only |
| audit | fans out of generate | Checks `Tasks` against `Billing_Ledger`, writes findings back |
| digest | `Called` | Returns the morning section for the briefing plugin seam |
| tap | `Called` | A ✅/🤖 button press → writes the `Tasks` row, redraws the message |

The audit hangs off the generator's existing `Get Commitments` / `Get Existing Tasks` reads
rather than repeating them, so the whole thing costs **one** extra sheet read a day.

It is one workflow rather than three because all three branches need the *same*
paste-time configuration — one spreadsheet id, one Sheets credential — and splitting them
multiplies that setup without separating anything that actually varies.

Branches 2 and 3 share a single Execute Workflow Trigger because n8n permits only one per
workflow. `Tap or Digest?` splits them on whether a `taskId` arrived. That trigger is set to
**passthrough**, not named inputs: named inputs would strip every field except the ones listed,
and the tap path depends on `taskVerb` / `messageId` / `callbackId` surviving the call.

Both point at the **Billing_Ledger spreadsheet**, not the Signups one. Replace
`YOUR_BILLING_LEDGER_SPREADSHEET_ID` and create the `Commitments` and `Tasks` tabs with their
header rows before the first run — nothing creates them.

**`commitments-digest` must be activated.** A subworkflow whose only trigger is an Execute
Workflow Trigger still has to be active to be callable; an inactive one fails with *"Workflow is
not active and cannot be executed"* and the briefing renders `⚠️ COMMITMENTS unavailable`. That
was the first failure on the live instance, and the symptom names no cause.

The digest shows **one line per commitment**: the nearest outstanding period. The generator
keeps two months alive, but printing both would double the list every morning, so next month
surfaces only once this month is closed.

## The tap is a steward agent, not a special case

A button press reaches this workflow through the **existing** dispatch path in
`12_steward/menu-handler`: `Config` → `Normalize` → `Route` → `Run Skill`. The registry gained
one `task` entry and `Normalize` gained one branch. **No new nodes, no new Route rules** on the
lab's only live command surface.

Three properties of menu-handler made that possible, and all three are worth not breaking:

- `Run Skill` declares no `workflowInputs`, so the whole normalised item — including
  `taskVerb`, `taskId`, `messageId`, `callbackId` — arrives here intact.
- `Format Skill Response` forwards a reply **only** when the subworkflow returns a `response`
  field. The tap branch redraws the message itself and returns `{}`, so the hub stays quiet.
- The `agent` route is "anything that is not chat or help", so a registered `task` action is
  dispatched with no routing change at all.

The registry entry is marked `hidden: true` so `Build Help` leaves it out of `/help` — it is
reachable only by `callback_data` and was never a typed command.

## How rows get in

By hand, for now — open the sheet and type. At the current volume that is honestly the right
tool, and a `/commit` Telegram agent built before the schema has settled would just be a faster
way to enter the wrong columns.
