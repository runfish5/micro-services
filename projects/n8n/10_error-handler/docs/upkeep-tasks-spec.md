# Upkeep Tasks — spec

**Status as of 2026-08-12 — every stage is built in the committed JSON. Nothing is on the live
instance.** Stage 4 was **dropped** rather than built; see *Stage 4 no longer exists*. Verified
by dry run against the live failure corpus (285 executions through the real classifier into the
real plugin), not by a live 7 AM send. *Beyond* remains a sketch, not a plan.

| | |
|---|---|
| `010-error-handler.json` | fingerprint + `error_signature`, and the classifier fix |
| `upkeep-digest.json` | **new** — 6 nodes, the UPKEEP plugin |
| `daily-briefing.json` | registry row, `order: 30` |
| `commitments.json` | the `m` verb, two expressions |
| `16/README.md` | `Tasks` grain restated one level up, `source` column |

**To deploy:** add `fingerprint` + `error_signature` headers to `FailedItems` and `source` to
`Tasks`; import `upkeep-digest` and **activate it**; put its real id in the briefing's `Plugins`
registry; re-import `010`, `commitments` and `daily-briefing`.

A recurring failure with an identical signature is not an incident, it is a **defect**. This spec
turns those into rows on the lab's task list, so they arrive in the 7 AM briefing next to the
bills — and stops the 8-hour resolver from retrying something retry cannot fix.

It then does the same for the obligations you write down by hand — the **Open thread** blocks in
the root `CLAUDE.md` — which are the same kind of thing arriving by a different route. Two
producers, one section, one distinction held visible throughout: **observed** things the lab
found by itself, and **declared** things only you know about.

The motivating case is documented in the root `CLAUDE.md`: `image/svg+xml` killed
`03_any-file2json-converter` **eight times over six weeks** and nothing ever said so. Not because
alerting was off, but because every mechanism in the lab measures *volume* and none measures
*recurrence*.

## Why nothing caught it

| Mechanism | Fires when | Why it missed |
|---|---|---|
| GitHub-Actions heartbeat | ≥3 errors **and** ≥60% of recent runs failing, 90-min window | 8 failures in 87 runs never approaches a majority. And its alert text hardcodes one hypothesis — "task runner is down, redeploy" — so even a lucky trip would have been the wrong diagnosis |
| `010-error-handler` | Every failure | Sent 8 alerts. Has no concept that they were the *same* alert |
| `11_8-hours-incident-resolver` | `status = pending_retry` | Would burn 3 retries per occurrence on a deterministically fatal input, then escalate. 24 doomed executions for one bug |

A failure that is **rare but always identical** is invisible to all three. That is the gap.

## Who this is for — and who should never see it

**This is a plugin. The lab works exactly the same without it** — one registry line, and
`enabled: false` switches it off with no nodes to unwire.

It is committed **on**, with `ACTION_MODE = 'fix'`, because this lab's reader is T3. That is a
choice about *this* operator, not a default: anyone importing the repo who does not edit these
workflows should set the mode to `off` (the red sticky on the plugin says so). Rule 3 of the tier
model — unset fails to the lowest tier — governs the *unset* case, and this one is set.

That framing matters because a defect is only worth *acting on* by someone who can act. This is
the first feature in the lab to need the tier vocabulary in the root `CLAUDE.md` § User tiers,
and it is the worked example that section points back at:

| Tier | A defect means | The action is |
|---|---|---|
| **T3 — maintainer** (`codes: true`) | go and fix it, or hand it to an assistant | `✅ Done` · `🤖 Assign` |
| **T2 — operator** | tell whoever maintains it | `📤 Report` — a GitHub issue, drafted for them |
| **T1 — recipient** | nothing they can do | text only — no buttons |

For T2, `✅ Done` is a button they could never honestly press. For T1 there is no honest button
at all. But note which half is constant: **all three see the defect.** Rule 1 of the tier model
is that the tier gates the action and never the information, and this is where that rule was
first paid for — a briefing that hides breakage from the people who cannot fix it is how the lab
stops being trustworthy to exactly the readers with the least other way to find out.

So this is not one section with three labels. **It is text-only until the reader picks a mode**,
and `off` is the default.

The report path is deliberately **not** in the stage list. It is sketched at the very bottom
under *Beyond*, because it depends on machinery that does not exist yet, and because putting the
most complicated idea in this document in front of the reader with the least reason to want it
is how a working lab starts feeling like homework.

## The framing: a commitment to the code

The obligation is real and it is ours: *keep the lab's workflows working*. That makes a bug the
same **kind** of thing as a bill — something we signed up for, from our side, that needs doing and
can be done or not done.

But it is not a row in `Commitments`. That table is hand-written, declarative, never touched by
automation, and every field that makes it work — `cadence`, `amount_expected`, `charge_day`,
`payment_method` — is one a bug cannot fill. A bug has no cadence; next month's cannot be
materialised from a rule.

What the framing actually establishes is that **`Tasks` was never the commitments project's
table.** Strip the denormalised financial columns and what remains is a generic
obligation-occurrence table: something to do, who has it, how it ended, what proves it.
Commitments is its first producer, observed defects the second, declared threads the third — and
the third is the one that proves the generalisation, because it shares no machinery with either
of the others. It is just a row someone typed.

### Restated grain

> **`Tasks`: one row per open obligation, keyed by `task_id`.**

`talktalk::mobile@2026-09` and `self::code-health@a3f9c1e2` are the same grain from different
producers. This passes the test that `16`'s README applied when it *refused* to put unmatched
invoices in `Tasks` — those failed because an unmatched invoice is a **finding** with no
obligation to hang on. A bug is an obligation. It passes where the invoice did not, for the
reason the README itself supplies.

`self::code-health` follows the existing convention that `::` marks a key this repo minted. It is
never entered in `Commitments`, which is what makes `16`'s audit skip these rows — the documented
behaviour for a task whose `commitment_id` is unknown. The financial reconciler and the bug
lifecycle stay mutually invisible with no code guarding the boundary.

## Architecture: events are counted, state is stored

**This is the load-bearing decision, and it reverses the obvious design.**

The obvious design has `010` upsert a `Bugs` row per failure, incrementing an `occurrences`
counter. That is wrong twice:

1. **It races.** The SVG evidence shows *bursts* — four failures in eleven minutes. Google Sheets
   read-then-write is not atomic; two concurrent error-handler runs both read `3` and both write
   `4`. The count silently drifts low, which is the direction that keeps a bug *below* threshold.
2. **It can undo a human decision.** An upsert that writes `status: open` resets a row you marked
   fixed yesterday. `16`'s README already names this as the one change that would quietly destroy
   its own feature.

So nothing counts. **`FailedItems` holds events; `Tasks` holds decisions; the digest joins them at
read time.**

```
010-error-handler ──appends── FailedItems  (+ fingerprint column, append-only, race-free)
                                    │
                                    │  count by fingerprint
                                    ▼
                            upkeep-digest plugin ──renders──▶ 7 AM briefing
                                    ▲
                                    │  look up status
                                    │
menu-handler tap ──appendOrUpdate── Tasks  (written only when a human taps)
```

Three consequences, all good:

- **`010` gains no new spreadsheet.** It adds one column to an append it already performs, plus
  one *read* of the sheet it already writes. Reads do not race. The error handler is the workflow
  that most needs to keep working when other things break; it does not take on the finance
  document. *(This corrects an earlier assumption that it would.)*
- **Reopen-on-recurrence needs no code.** The digest counts occurrences with
  `timestamp > closed_at`. Mark it fixed, it vanishes; ship a bad fix and it is back tomorrow.
  There is no reopen branch to get wrong, and no `verify_done` opt-in — unlike the commitments
  audit, the evidence here is produced by the same pipeline that raised the finding.
- **A fingerprint with no `Tasks` row is implicitly open.** Rows exist only where a decision was
  made, so the table stays small and every row in it means something.

### The threshold lives read-side

The digest filters `occurrences >= 3`. `010` never decides what counts as a bug — it only labels
and counts. Tuning the policy is a one-expression change in a plugin whose failure renders
`⚠️ UPKEEP unavailable`, rather than an edit to the error path.

The one exception is the retry gate, which genuinely needs the count at write time — see below.

## The fingerprint

```
fingerprint = hash32(workflowId + " " + failedNodeName + " " + normalize(message))
```

`workflowId` and node name are included so the same generic message in two workflows stays two
bugs. Rendered base36, ~7 characters.

### Normalisation

Applied to the error message before hashing:

| Rule | Example |
|---|---|
| Collapse temp/abs paths | `/tmp/gmR4kx9a` → `/tmp/*` |
| Strip UUIDs and hex runs ≥8 | `a3f9c1e2-…` → `*` |
| Strip standalone integers | `timeout after 60s` → `timeout after *s` |
| Strip quoted strings | `cannot read "invoice_3.pdf"` → `cannot read "*"` |
| Collapse whitespace, lowercase | |
| Truncate to 200 chars | stack tails are not signature |

Both directions have a failure mode worth naming. **Too aggressive** and distinct bugs collapse
into one row that says nothing actionable. **Too loose** and one bug fragments across many
fingerprints, none of which ever reaches three — the bug stays invisible and the mechanism looks
like it is working. Fragmentation is the more dangerous failure because it is silent.

Verify against the real corpus before trusting it: the eight SVG rows must produce exactly one
fingerprint, and the two unrelated failures in the same window (task-runner timeout at
`Modify File & Input`, model `503` at `Image-to-text`) must produce two more.

### Do not use `crypto`

n8n Code nodes gate Node builtins behind `NODE_FUNCTION_ALLOW_BUILTIN`, which is not set on this
instance. `require('crypto')` will throw at runtime, not at edit time. Use a pure-JS FNV-1a:

```js
const h32 = s => { let h = 0x811c9dc5; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; } return h.toString(36); };
```

Collisions are irrelevant at this scale — a lab that accumulates a few dozen distinct fingerprints
has a birthday probability in the millionths, and a collision merges two bug rows rather than
losing one.

## Changes to `010-error-handler`

Per the repo's expression-first rule, this adds **no new nodes**. The fingerprint is computed in
the existing classification Code node.

| Change | Where | Note |
|---|---|---|
| Compute `fingerprint` + `error_signature` | existing classify Code node | FNV-1a, above. No new nodes |
| Write both columns | `Append to FailedItems` | `autoMapInputData`, so the sheet needs the headers |
| **Classify `timed out` / `service unavailable`** | the `network_error` branch | A pre-existing bug — see below |

### The classifier was missing its two most common inputs

Found by the corpus run, and it is the fix that mattered most in this whole document.

n8n's task-runner timeout reads **"task request timed out after 60 seconds"** — no `timeout`,
no status code. A provider 503 frequently arrives as **"service unavailable — try again later"**,
again with no number. Neither matched the `network_error` branch, so both fell through to
`unknown` / **not retryable**.

That is 104 of 285 failures on the instance, and it cost twice over:

- **The 8-hour resolver never retried them.** It filters `is_retryable === true`, so a whole
  class of genuinely transient failure was silently excluded from the thing built to handle it.
- **The upkeep digest would have reported them as defects** — 14 rows of infrastructure incident
  presented as code to fix.

One added condition on an existing `else if` fixes both. `is_retryable = false` drops from 217
to 113, and the section from 14 rows to 6.

### Stage 4 no longer exists

The planned retry gate was going to mark recurring failures non-retryable. It is **dropped**, for
two reasons that only became visible with the code and the corpus side by side:

1. **The resolver already gates on `is_retryable`** (`Prepare Items`: `status === 'pending_retry'
   && is_retryable === true`). Non-retryable items were never being retried. The problem was
   never a missing gate — it was that the classifier was labelling the wrong things.
2. **With *recurrence promotes, never demotes*, the gate is a tautology.** Recurrence may only
   elevate errors already marked non-retryable, and those are already skipped. There is nothing
   left for it to do.

Deleting a stage is the right outcome here. A gate that duplicates an existing filter is not
harmless — it is a second place to get the predicate wrong, in the workflow that most needs to
keep working.

### Recurrence promotes, it never demotes

**The predicate is `occurrences >= 3` AND the classifier already said not-retryable.** Recurrence
alone is not evidence of a defect, and the corpus below is unambiguous about why: the two largest
recurring signatures on the instance are rate limits (67 executions) and task-runner timeouts (93
executions). Both repeat byte-identically. Both are *exactly* what retry exists for.

A gate keyed on recurrence alone would have switched off the rate-limit auto-retry branch that
already works — the silent regression this stage was flagged for, except it is the majority case
rather than an edge one.

So recurrence is a **promoter**: it moves `unknown` / `parse_error` / `validation_error` from
"one-off worth ignoring" to "defect worth surfacing". It has no power to move `rate_limit` or
`network_error` the other way. The classifier keeps the veto.

This is also what keeps infrastructure incidents out of the list for free. The task-runner outage
produced the same message in six different (workflow, node) pairs, so the fingerprint splits it
into six rows — correct for defects, wrong for one incident. The retryable veto drops all six
before that matters, so no second mechanism is needed.

**The first two occurrences of a new bug are still retried.** That is deliberate: until a
signature has repeated, "transient" is the correct hypothesis, and a mechanism that gave up on
first sight would break every genuinely retryable failure. The cost is bounded at six doomed
retries per bug, against twenty-four today.

The read is skipped on the **runner-proof branch**. That branch exists precisely because Code
nodes cannot be assumed to run during a task-runner outage, and it must keep its property of
alerting with expressions only. A runner outage produces no fingerprints — correct, since a
runner outage is not a code bug.

## The plugin: `upkeep-digest`

Lives in `10_error-handler/workflows/`, because the project that owns the failure log owns the
rendering of it. This is the ownership rule the seam exists to enforce.

Reads `FailedItems` (own document) and `Tasks` (Billing_Ledger document). **The plugin carries the
two-document dependency, not the error handler** — a plugin that cannot reach a sheet renders
`⚠️ UPKEEP unavailable` and the rest of the briefing arrives.

Selection — **observed** rows, in order:

1. Group `FailedItems` by `fingerprint`, over the retained window.
2. Keep groups with `count >= 3` **and** `is_retryable = false` — see *Recurrence promotes, it
   never demotes*. Without the second half the section is 18 rows on day one, two thirds of them
   things the lab is already correctly retrying.
3. Left-join `Tasks` on `task_id = self::code-health@<fingerprint>`.
4. Drop where `status = wont_fix`.
5. Drop where `status = done` **and** no occurrence has `timestamp > closed_at`.
6. Sort by most recent occurrence.

Then **declared** rows — see the next section — and the two render as separate headings in one
section. Output per the plugin contract: plain text only, always exactly one item, `empty` when
quiet.

```json
{
  "key": "upkeep",
  "icon": "🔧",
  "title": "UPKEEP",
  "blocks": [
    { "heading": "Observed", "items": [
      "03 converter · gm: no decode delegate · 8× since 27 Jul"
    ] },
    { "heading": "Declared", "items": [
      "/visits — briefing promises detail that has no command",
      "13 ops-center — committed, never imported; README advertises dead commands"
    ] }
  ],
  "empty": "Nothing outstanding"
}
```

`UPKEEP` rather than `BUGS` because the section outgrew defects the moment it acquired a second
producer, and because it is the reader's own phrase for what this is: *keeping the code up and
fresh.* The internal key stays `self::code-health`, so nothing about the `task_id` changes.

### It renders when empty

Silence here answers a question you would otherwise go and check — *is anything quietly broken?* —
so per rule 4 of the plugin contract it prints a one-liner rather than disappearing. The precedent
is `SITE`, and the reasoning is the same: a missing section is indistinguishable from a broken
pipeline.

### `order: 30`

Between commitments (20) and site (40). Money has a deadline and a bug does not, so bills sort
first; both sort above traffic. This matters because the 4096-character cap truncates the tail.

### Message text

`<project> · <short signature> · <n>× since <first seen>`. The signature is the normalised message
truncated to ~40 chars — enough to recognise the bug, not enough to be a stack trace. Escaping is
the briefing's job; the plugin emits plain text and never markup.

## The second producer — declared threads

Root `CLAUDE.md` carries **Open thread** blocks: the `/visits` command that the briefing promises
and does not have, `13_n8n-ops-center` committed but never imported, the SVG bug itself. They are
obligations to the code, written down and then visible **only inside a Claude session**. The SVG
one sat there for weeks precisely because nothing outside that session ever mentioned it.

They are the same commitment as a bug — `self::code-health` — arriving by a different route. So
they are rows in `Tasks`, in the same section, under a second heading.

### Observed vs declared is the distinction to keep visible

| | Observed | Declared |
|---|---|---|
| Where it comes from | `FailedItems`, by recurrence | a human typed it |
| Carries | a count and a first-seen date | neither |
| Closes when | tapped — and **reopens by itself** if the fingerprint fires again | tapped. That is all |
| If you are wrong about it being fixed | the pipeline contradicts you tomorrow | nothing does |

That last row is why they cannot be merged into one list. An observed row is backed by evidence
the lab produces on its own; a declared row is backed by your say-so. Rendering them identically
would lend the second the credibility of the first — and the whole reason the observed half is
trustworthy is that **nothing can quietly close it.**

### Rows get in by hand, and there is no parser

`CLAUDE.md` is prose written for an LLM to read. Parsing it into rows would make a file whose
only job is to be readable into a data format with a schema, and would put format constraints on
the one file loaded into every session. The block stays prose.

This is not duplication, for the same reason `Commitments` and `Tasks` are not duplication: **the
block is the explanation, the row is the occurrence.** The block holds the diagnosis, the
evidence, the suggested fix and the callers to re-test. The row holds one line and a status. They
even cross-check each other weakly — close the row and leave the block, and the next session says
so; delete the block and leave the row, and tomorrow's briefing does.

Hand entry is also the honest tool at this volume, exactly as `16` says of `Commitments`. Two
threads do not justify a sync mechanism, and a `/thread` command built before the shape has
settled would just be a faster way to enter the wrong thing.

### One narrative, two obligations

The `/visits` open thread is a single prose block that contains **two** separate things to do:
build the `/visits` agent, and resolve the ops-center that advertises commands it never
installed. That is two rows.

Worth stating because it is the root `CLAUDE.md` grain rule applied to itself — *source documents
are evidence, not rows; one can describe several.* A row per open-thread heading would be one row
per document, and would quietly lose an obligation.

### Known pressure — declared rows never expire

An observed row leaves when the bug stops recurring or you fix it. A declared row can sit there
for months, correctly, because it is genuinely still open. **The risk is not the clutter — it is
that a section you learn to skip stops working for the observed half too**, and that half is the
one with actual urgency.

Not solved, and deliberately not pre-solved: two threads is not a problem, and a `review_on`
column added now would be a mechanism built for a pressure that does not exist yet. The fix is
identified if it does — a date that means *quiet until then*, blank meaning daily, which is an
explicit dated deferral rather than the silent disappearance the vanishing rule exists to
prevent. Watch for the declared list passing about five rows.

### Ownership — the uncomfortable part, named

`10_error-handler` owns failures. It does not own the repo's open threads, and rendering them
from its plugin is a stretch of the ownership rule the seam exists to enforce.

It is still the right call today: the section is one section, the rendering is shared, and a
seventeenth project to hold two hand-typed rows would be worse than the stretch. The trigger for
revisiting is **producer logic, not row count** — if declared threads ever get a parser, a GitHub
sync or any code of their own, they have earned their own plugin and should take the heading with
them.

## Buttons — and the verb problem

Two verbs, and neither is the commitments pair:

**Every shown row is its own item with its own two buttons** — each is a separate thing you either
finished or handed off, and a shared control would be a lie about which one you meant.

| Button | Callback | Writes |
|---|---|---|
| `✅ Done` | `tk\|d\|self::code-health@a3f9c1e2` | `status: done`, `closed_at: now` |
| `🤖 Assign` | `tk\|a\|self::code-health@a3f9c1e2` | `status: assigned`, `assignee: agent:unassigned` |

The **same pair the commitments plugin already uses**, which is why `16`'s tap branch handles
upkeep rows with no change at all — same `task_id` key, same `appendOrUpdate`, same redraw.

They are different claims, and that is the point of having two. `d` asserts the work is finished.
`a` hands it to an assistant and leaves the row **open**, so it keeps appearing at `⏳ assigned`
until it is genuinely closed. Nothing acts on an assignment yet — that is the briefing seam's own
stage 3 — and the honest consequence is that the row does not go away. Presence is the default;
absence is the achievement.

### `wont_fix` still exists, without a button

The digest drops `status = wont_fix`, and `16`'s tap can write it from a `tk|m|` callback — but
**no button emits `m`**, because the keyboard is a static `fixedCollection` capped at two and
both slots are spoken for. Dismissing a row is therefore a sheet edit today.

That is a deliberate trade rather than an oversight: dismissal is rare, assignment is not, and
the verb is already wired if the cap ever frees up.

### `upkeep_action_mode` — one setting, two audiences

Which pair renders is a single value in the plugin's Config node. A controlled vocabulary in the
same spirit as `payment_method` in `16` — the one field that changes what the automation *does*,
so it is fixed rather than free text:

| Value | Buttons | Tier |
|---|---|---|
| `off` *(default)* | none — text only | T1, and everyone until they choose otherwise |
| `fix` | `✅ Done` · `🤖 Assign` | T3 |
| `report` | `📤 Report` · `🔕 Won't fix` | T2 — see *Beyond*, not built |

`off` is the default because **unset fails to the lowest tier** (tier rule 3). Stage 3 ships
`off` only. A reader who never touches this setting gets a section that names what is broken and
asks nothing of them — the honest offer while the lab cannot yet help them act on it.

Note what this is *not*: a permission check. Setting `fix` on a box whose owner does not code
grants nothing and prevents nothing — it just puts a useless button on a message. The tier model
is about what is worth offering, and the root `CLAUDE.md` says so explicitly, because a
capability vocabulary that starts getting read as a security control is the failure mode
PromptPotter's access model exists to prevent.

**Callback budget:** `tk|a|self::code-health@a3f9c1e2` is 30 bytes of the 64 available, and
fixed-length for an observed row — unlike the commitments ids, a fingerprint cannot grow. A
**declared** row's slug is hand-chosen, so it can: `@ops-center-import` reaches 40 bytes. Keep
them short, because Telegram rejects the *entire* keyboard when one button is over — the cost of
a long slug is every button in that message, not just its own.

**Both producers get the same two buttons**, and the asymmetry falls out of the selection rules
with no extra code. `done` on an observed row is provisional — the fingerprint can bring it back.
`done` on a declared row is permanent, because step 5 drops it and there are no occurrences to
resurrect it with. That is the correct difference: nothing but you ever knew the thread was open,
so nothing but you can reopen it.

### The third verb cost two expression edits in `16`

`commitments.json`'s tap branch treats the verb as binary — `taskVerb === 'd' ? … : …` — in two
places, and an unrecognised verb silently falls into the `assigned` branch:

| Node | Current | Needs |
|---|---|---|
| tap `appendOrUpdate` (`status`, `assignee`, `closed_at`) | `d ? 'done' : 'assigned'` | three-way |
| tap redraw `text` | `d ? '✅ done' : '🤖 assigned to an agent'` | three-way |

Both are single expressions in an existing node. **No new nodes and no new `Route` rules on
`menu-handler`** — the `tk|` prefix branch in `Normalize` already carries any verb through, and
the registry `task` entry already dispatches it. That is the payoff of putting bugs in `Tasks`
rather than a `Bugs` table of their own.

### The two-button cap has already bound

It is why `🔕 Won't fix` has no button. Worth noticing that it bound *earlier than predicted* —
this section assumed the squeeze would arrive with an agent, and it actually arrived from wanting
two perfectly ordinary verbs. The keyboard is a static `fixedCollection`; three is not available.

If a PR-drafting agent is ever built it does **not** need a third button. `🤖 Assign` is already
the door — what changes is who answers it, not the keyboard.

## Stages

Staged the way the seam itself was, so each step is provable before the next depends on it.

| Stage | Work | Reversible? | Risk |
|---|---|---|---|
| **1** | ✅ **Done.** `fingerprint` + `error_signature` computed in `010` | Drop the columns | None — nothing read them |
| **2** | ✅ **Done 2026-08-12.** Validate fingerprints against the real corpus | n/a | None — read-only. Changed stage 4; see *Corpus result* |
| **3** | ✅ **Done.** `upkeep-digest` (6 nodes) + registry row `order: 30` | `enabled: false` | Low. Isolated by `continueOnFail` |
| ~~4~~ | ~~Retry gate~~ — **dropped**, see above. Replaced by the one-line classifier fix | Revert one condition | The classifier fix is what this stage was actually for |
| **5** | ✅ **Done.** **Declared threads**: `source` column on `Tasks`, the `Declared` heading in the digest, the first rows typed by hand, grain restatement in `16`'s README | Delete the rows | Low — purely additive; the observed half is untouched |
| **6** | ✅ **Done.** Two buttons, `m` verb, the two ternaries in `16` | Drop `actions` from the plugin output | Touches the live command surface |

**Stage 1 stands alone.** It starts accumulating signatures immediately, so by the time stage 3 is
built there is real data to render and stage 2 has something to check against. Building the plugin
first means testing it against an empty sheet.

**Stage 4 is the one to be careful with**, and it is deliberately placed after the digest is
proven. It is the only stage that makes the lab do *less*, and its failure mode — a transient
failure misclassified as a bug and never retried — is silent. Do not ship it until stage 2 has
confirmed the fingerprints group the way they should.

**Stage 6 last**, because it edits `menu-handler`'s downstream tap path, and a broken verb ternary
there affects commitment taps too — the feature that currently works.

### What is *not* in this list

Stages 1–6 are the whole feature for someone who edits workflows. They stop at: the briefing
names a defect, and two buttons record what you decided about it.

Everything else — the report mode, agent dispatch, drafted issues, comparing two coding agents —
is nested under *Beyond* at the end of this document, unnumbered on purpose. It is not stage 7.
Giving it a number would imply it is queued, and it is not: it should not be started until
stage 6 has been live long enough to be boring, and possibly never, since a lab with one
maintainer who codes may simply never need it.

## n8n hazards

Collected because this lands across four workflows and two documents, and most of these have
already cost time once in this repo.

- **The plugin must be ACTIVE.** A subworkflow whose only trigger is an Execute Workflow Trigger
  still has to be activated, and an inactive one fails with *"Workflow is not active and cannot be
  executed"* → `⚠️ UPKEEP unavailable`. This was the first live failure of the seam on 2026-08-12
  and the symptom names no cause. **Check this first.**
- **`crypto` is unavailable** in Code nodes here. See above.
- **`saveDataSuccessExecution: none`** on the plugin, or a daily sub-execution fills the execution
  list and the ops-center failure view with routine successes.
- **Bind the plugin's `errorWorkflow`** to `007_error-handler.n8n`, as `commitments-digest` and
  `commitments-task-generator` are. A plugin that fails silently at 07:00 looks like a quiet
  morning.
- **A blue sticky behind any Execute Workflow node**, because the n8n UI silently clears
  `workflowInputs` on re-selection.
- **The plugin trigger is `passthrough`**, not named inputs. Named inputs strip every field not
  listed, which is what the tap path depends on surviving.
- **Two documents in one workflow.** `upkeep-digest` reads `FailedItems` and `Tasks` from *different*
  spreadsheets. Check which `documentId` a node points at before copying it — `05`'s CLAUDE.md
  records this as an existing trap in the briefing.
- **`Tasks` writes must stay partial.** The tap sets four fields on `appendOrUpdate`; a node that
  writes the full row would blank the commitment denormalisations on a bug row and vice versa.
- **Retention interacts with the count.** `FailedItems` rows are archived and deleted by the
  8-hour resolver on *successful* retry. Bug rows never retry successfully, so they persist — but
  once stage 4 marks them `status: bug`, confirm nothing else prunes on status.
- **Republish after editing.** Parent workflows call the published version, not the draft.
- **Escaping stays central.** The plugin emits plain text; a single stray `<` from an error message
  would otherwise fail the entire `sendMessage` and take the whole briefing with it. Error text is
  exactly the kind of string that contains angle brackets, so this is not theoretical here.

## Testing

The bug this exists to catch happens roughly once a month, so waiting for a real one is not a test
plan.

1. **Seed.** Append three synthetic `FailedItems` rows sharing a fingerprint, with staggered
   timestamps. Run the plugin on a Manual Trigger and confirm one item, one block, one line.
2. **Threshold.** Delete one row → the item must disappear at `count = 2`.
3. **Fixed.** Add a `Tasks` row `self::code-health@<fp>` with `status: done`, `closed_at` after
   the last occurrence → item disappears.
4. **Recurrence.** Append a fourth `FailedItems` row timestamped after `closed_at` → item
   reappears. This is the property the whole design rests on; test it explicitly.
5. **Won't fix.** `status: wont_fix` → stays gone regardless of new occurrences.
6. **Empty.** No qualifying groups → exactly one item with empty `blocks`, so the briefing prints
   `No open bugs` rather than a missing section.
7. **Isolation.** Point the plugin at a nonexistent sheet → the briefing arrives with
   `⚠️ UPKEEP unavailable` and every other section intact. If this fails, the seam is providing no
   isolation and stage 3 should not ship.
8. **Corpus check** (stage 2, by hand): the eight SVG executions produce one fingerprint; the
   runner timeout and the model `503` produce two more.

## Corpus result — stage 2, run 2026-08-12

Run against the **live instance**, not the sheet: every failed execution in the retained window,
fingerprinted with the code lifted out of the committed `010` so it cannot drift from what runs.

```
284 failed executions   2026-06-17 .. 2026-08-12
 36 distinct signatures
 18 over threshold (count >= 3 alone)
  8 over threshold (count >= 3 AND not retryable)   ← the correct gate
```

The grouping is sound: the eight SVG executions collapse to one signature (`1jg24l7`), and the
34 non-elevating signatures are genuine one-offs, not fragments of a larger bug. No evidence of
the silent failure mode — over-loose normalisation splitting one defect across many hashes.

**What the section would show on day one:**

| Count | Workflow · node | Signature |
|---|---|---|
| **53×** | `expense-trend-report` · Read Invoices | resource could not be found — **failing since 17 Jun, 48 days** |
| **21×** | `007_error-handler` · 🚨 Runner-Proof Alert | bad request — **the safety net itself, during the outage** |
| 9× | `04` · Create Attachment Profile | error executing workflow with item at index |
| 8× | `any-file2json-converter` · conversion | the SVG bug — **ranked 12th before the gate** |
| 5× | `visit-log` · Lost To Concurrent Append | row lost to concurrent append |
| 4× | `04` · subject-classifier-LM | request invalid or could not be processed |
| 3× | `record-search` · Read All Contacts | service unavailable |
| 3× | `04` · Call 'record-search' | service unavailable |

Eight rows is a lot for a first morning, but it is a **backlog, and it drains** — six of the eight
are one fix each. The list is stable at this size only if new defects arrive faster than they are
closed, which is the situation the section exists to make visible.

### Three things the corpus changed

1. **The retry gate got a second conjunct** — see above. This is the finding that mattered.
2. **Raising the threshold would have been the wrong fix.** At `>= 5` the SVG bug (8×) still
   ranks below four rate-limit signatures (27×, 26×, 11×) that do not belong on the list at all.
   The noise was never about volume; it was about kind.
3. **`error_signature` earned its column.** Reading 36 hashes tells you nothing; reading 36
   normalised messages is how the two conclusions above were reached in one pass.

### Two findings that are not about this feature

Reported because the corpus surfaced them and they are worse than the bug that started this:

- **`expense-trend-report` · Read Invoices has failed 53 times since 17 June** — *"the resource
  you are requesting could not be found"*, a missing document or sheet. Nearly two months of a
  scheduled report failing every run, and nothing ever said so. This is the strongest possible
  argument for the section, and it is not the bug anyone was looking for.
- **The runner-proof branch was itself broken during the outage it exists for.** `🚨 Runner-Proof
  Alert` failed 21 times on 8–9 Aug with *"bad request — please check your parameters"*, in the
  same window as the timeout burst. Separately, `Runner/Infra Down?` threw
  *"invalid regular expression: /(?i)(task request timed out…"* once — the exact inline-flag
  mistake `10`'s own CLAUDE.md warns about. The safety net has never been verified end to end
  under the condition it was built for.

## Beyond — the supervised report path

**Nothing here is scheduled, and none of it should appear until stage 6 is live and boring.** It
is written down so the stages above do not accidentally foreclose it — not because it is next.

The gap it fills: a reader who does not code still needs a defect to reach someone who can fix
it. The destination is a GitHub issue. The interesting part is everything between the tap and the
issue.

### The issue is drafted, never filed

A button that files directly is the wrong shape. Error text is raw instance data — paths,
filenames, sometimes the subject line of somebody's email — and this repo is **public**. An
auto-filed issue is an unreviewed publication, and the SVG bug is a perfect example: its message
was harmless, and the auth error two rows down would not have been.

So the tap **drafts** and the human sends. That is the same shape the existing verbs already
have: the row records that a report was started, and the vanishing rule does the rest — a draft
never sent leaves the task on the list, which is correct, because it does still need you.

### It routes through the general assistant, not a new integration

`12_steward/menu-handler` already has a Config registry of agents, an AI classifier that picks
one from free text, and an `Agent Available?` guard for when none fits. A defect report is that
existing path entered from a button rather than a typed sentence.

Nothing new is needed to *choose* who handles it. What is missing is one drafting skill and a
GitHub credential — which is the whole reason this is a sketch and not a rewrite.

**The agent inherits the reader's tier, never more** (root `CLAUDE.md` § User tiers,
delegation). A T2 reader's assistant drafts an issue; it does not edit a workflow, because its
delegator cannot either. That clamp has to be built *with* the dispatch, not after it — an agent
that can do more than the person who asked is the version of this idea that should never ship.

### Two coding agents, and a comparison

Further out: the assistant hands the defect to **two** coding agents and the candidates are
compared before either is trusted. Worth naming now for exactly one reason — it has a schema
implication. `Tasks` already carries `attempts` and `evidence`, so two candidate fixes fit
without a migration, provided nothing between here and there quietly redefines those columns as
single-valued.

The comparison stays a human decision. An agent that grades another agent's patch and applies the
winner is the failure mode `16`'s reconciler exists to prevent, one level up: a closed loop with
nothing outside it able to say no. What makes this path eventually safe is a property the design
already has and costs nothing — **a fix that did not work produces the same fingerprint again
tomorrow.** That is a stronger check than any review, because it is produced by the pipeline
rather than by anyone with an opinion.

### Why it is nested this far down

Look at the length of this document, then remember it describes **one plugin** in a lab that has
sixteen projects. Everything above is a column, a section, and two buttons. Everything here is a
distributed system with a review process.

Keeping the second out of the first reader's way is not tidiness. It is the difference between
*the briefing tells me what is broken* and *I need to understand agent dispatch before I can use
the briefing.*
