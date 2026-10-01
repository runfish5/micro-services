# 07 - Local Outbox

**A one-way channel from the lab to a machine the lab cannot reach.** n8n runs remotely and can
never write to a workstation. It writes what it *would* write into a store both sides can reach;
the local session pulls, applies, and acknowledges; a reaper archives the acknowledged rows.

**Status: nothing is built. This file is the specification and the defect list that produced it.**
Written 2026-08-28 after an audit of the live instance and the committed workflows.

> ⚠️ **Public repo.** No employer names, no message bodies, no personal addresses appear here
> or in anything this project produces. The operational data lives in Sheets and in a private
> local repository; this file describes only the mechanism.

> **Why the name and the number changed.** This began as `17_job-search-ops`, which was wrong
> twice over. The project is the **channel**, not the thing sent through it: application tracking
> is its first consumer, and a second one will want the same outbox. And once the record of truth
> moved into the store (§ *Where the memory actually lives*), naming the project after the local
> repository that merely *renders* it named the wrong end of the pipe. Every other project here is
> named for its mechanism: `error-handler`, `db-janitor`, `commitments-ledger`. This one now is
> too.
>
> **The number follows the dependency rule, not importance.** `general-registry.md` § *Project
> dependency order*: a higher number may use a lower one, never the reverse. The producer side of
> this channel lives in `04`, so `04` calls this project. At `17` that is an upward edge needing
> an announced exception; at `07` it is `04 → 07`, downward, and needs nothing. The reading-order
> test also passes: this project can be understood knowing only `00`–`06`.
>
> ⚠️ **It is not registered in `general-registry.md` yet, and must not be until a workflow
> exists.** Listing an unbuilt project in the registry is defect D1 repeated.

---

## The question this answers

> *"Where is the augmenting memory for my job search? The n8n should read my emails and submit
> to the CRM, so I could just say 'check my database' instead of telling the session who
> replied. I actually don't know whether we have built that."*

**It was not built.** A design for it exists in exactly one place, and that place is not tracked
by git. Everything below is the evidence, then the spec.

---

## What exists today, verified 2026-08-28

| Piece | State |
|---|---|
| **Email ingestion** | live. `04_inbox-attachment-organizer` polls, labels, classifies, files. |
| **A CRM** | live. `smart-CRM-fill` writes an `Entries` sheet. |
| **The CRM branch being reached** | live. `subject-classifier-LM` to `record-search` to `Prepare Contact Input` to `smart-CRM-fill` to `Merge`. |
| **Any record of an application** | ❌ **does not exist.** |
| **Any record of an outcome** | ❌ **does not exist.** |
| **Any path from the lab back to the workstation** | ❌ **does not exist.** |

**So the pipeline runs, and it stores the wrong noun.** It records *people who wrote*, not
*applications that were sent*. Those are different tables, and only one of them was built.

---

## Defects

### D1 - The design exists only in an untracked file

`.claude/centerpiece.md` diagrams the intended flow: a `FilingProjects` registry, a
`filing-clerk` LLM that picks a project, and a handler that appends a **JobHunt CRM record**.

**None of `JobHunt`, `FilingProjects` or `filing-clerk` appears anywhere else in this
repository** - no workflow, no doc, no test. And `git ls-files .claude` does not list
`centerpiece.md`: it is untracked, so the only copy of the design is one file on one machine.

**Consequence:** the idea reads as implemented to anyone who opens that diagram, and would be
lost entirely with the working copy.

### D2 - The live CRM is person-grained. An application is not a person

`Entries` carries contact fields: `email`, `first_name`, `surname`, `status`, `last_topic`,
`last_contacted`, `association`, `groups`, `works_at`, `notes`, and a dozen more of the same
kind. Every column describes a human being.

An application is an **employer + role + channel + date + outcome**. None of that fits a contact
row, so today a decision letter lands as a contact record whose `last_topic` is a sentence.

**Consequence, measured this week:** several employer decisions arrived, were correctly ingested
and labelled by the pipeline, and left no trace that any process could query. The local dossier
repository still listed those applications as awaiting an answer, and two follow-up messages
were drafted for channels that had already closed. **The lab had the data and no way to hand it
over.**

### D3 - The CRM branch is unconditional

`Call 'record-search'` hangs off `subject-classifier-LM` main output 0 with **no filter in front
of it**. Every classified email pays for two subworkflow calls, whether it is a job reply, a
newsletter, or an invoice that the financial branch is already handling in parallel.

**Consequence:** cost and row noise scale with the whole inbox, and there is no predicate to
reuse when a job-search route is finally added. The predicate is the thing worth building first;
the route is easy once something can say *this one*.

### D4 - Documentation and workflow disagree on whether the CRM writes at all

`04_inbox-attachment-organizer/CLAUDE.md` states: *"ContactManager (disabled): record-search →
Prepare Contact Input → smart-table-fill"*. In the committed workflow JSON **none of those three
nodes carries a `disabled` flag** - only `sender_whitelist`, `notify the category` and one
sticky note do.

**Consequence:** the file a maintainer is told to read first is wrong about a branch that runs on
every email. Either the doc is stale or the export is; both readings are expensive, and the repo
currently supports neither over the other.

### D5 - The silent-failure canary is firing and nobody reads it

`04`'s own design is explicit: `inProgress` is applied at entry and removed on success, so
**emails still carrying it are the failed runs**. The mechanism is deliberate and it works.

**At least one message from 09.08.2026 still carried `inProgress` on 28.08.2026.** Nineteen
days. Nothing surfaces the count anywhere - not in the 7 AM briefing, not in the ops center, not
in a Telegram command.

**Consequence:** the repo describes this as monitoring. It is only monitoring if something reads
it. Today it is a label.

### D6 - There is no outcome vocabulary

`subject-classifier-LM` sorts on `type_of_document` with a `financial` branch and a fallback. A
rejection, an acknowledgement, an interview invitation and a recruiter's redirect are all the
same thing to it: not financial.

**Consequence:** even with the right table, nothing upstream can fill a `status` column, because
no node in the lab has ever been asked to name what a message *did*.

### D7 - Nothing watches a posting for expiry

Two targets were lost in eleven days because the posting closed while a finished dossier sat
unsent. Both were verifiable by an unauthenticated HTTP call that takes under a second.

**Consequence:** the lab cannot warn about this, and could not be made to, because no table holds
a posting URL. This is the defect with the highest measured cost so far.

### D8 - n8n cannot write to the workstation, and no ticket channel exists

The dossiers live in a local git repository. n8n runs remotely. **There is no channel between
them in either direction.** The only path today is a human reading an inbox and re-typing what it
said into a session.

**Consequence:** this is the bottleneck the whole request is about. The spec below is the fix.

### D9 - Two ledgers, no reconciliation, and this one has only one book

`16_commitments-ledger` exists precisely because one record of a reality is not enough: what we
signed up for is kept independently from what was billed, and reconciling them finds what neither
shows alone.

The job search has the same shape - **what we sent** (the local repo) versus **what came back**
(the inbox) - and only the first book exists in writing. The second is in Gmail, unqueryable.

**Consequence:** every question about state is answered from memory. This week that produced a
status board that was wrong about three applications at once.

---

## Specification - the channel

### The parts

**This has a name, and every piece of it has a name.** Producer cannot write to the consumer's
storage, so it writes its *intent* to a store both can reach; the consumer polls, applies, and
acknowledges; a reaper archives what has been acknowledged. The standard term for the whole
shape is a **transactional outbox with a polling consumer**.

```
+------------------------------------------------------+------------------------+
|                      Your words                      |     Standard name      |
+------------------------------------------------------+------------------------+
| "it should submit a ticket, prepare what to write"   | transactional outbox   |
+------------------------------------------------------+------------------------+
| "intermediate store, for example Drive"              | message store / spool  |
+------------------------------------------------------+------------------------+
| "when I work in job-search, it should read and pull" | polling consumer       |
+------------------------------------------------------+------------------------+
| "at some point mark as done"                         | acknowledgement        |
+------------------------------------------------------+------------------------+
| payload too big for a cell                           | claim check            |
+------------------------------------------------------+------------------------+
| a patch that keeps failing                           | dead letter queue      |
+------------------------------------------------------+------------------------+
| "n8n can then delete after moving the log"           | reaper / retention job |
+------------------------------------------------------+------------------------+
```

**Two parts the sketch did not name, and they are the ones people skip:**

| Piece | Standard name | Why it is not optional |
|---|---|---|
| The same patch may arrive twice | **idempotent consumer** | delivery is at-least-once; see rule 2 |
| The consumer's own record of what it already applied | **inbox pattern** | without it, "did I already do this?" has no answer after a crash |

**Mapped onto this lab:**

| Piece | Here |
|---|---|
| Transactional outbox | n8n appends a `Patches` row instead of writing a file |
| Message store / spool | a Google Sheet tab, plus Drive for blobs |
| Polling consumer | the local session, at session start |
| Acknowledgement | stamps `state = applied`, `applied_at` |
| Claim check | Drive file id in `payload_ref`, never the bytes in a cell |
| Dead letter queue | `state = rejected`, with `reject_reason` |
| Reaper | `14_db-janitor`, which already exists for exactly this |
| Idempotent consumer | `patch_id` checked before applying |
| Inbox pattern | an `applied_patches` record in the private repo |

**The filesystem-level version of the same idea is `Maildir`** (`tmp/`, `new/`, `cur/`): the
writer creates the file elsewhere and *renames* it into `new/` so a reader never sees a
half-written message, and the reader moves it to `cur/` to claim it. If the store becomes Drive
folders rather than a sheet, copy Maildir exactly rather than inventing a variant. The whole
value is in the atomic move.

### On the right to submit

There is **no authorization boundary here** and this project must not be read as creating one.
One operator, one instance, one set of credentials — `CLAUDE.md` § *User tiers* says a tier is a
capability model and never a control, and the same applies to this channel.

**What the shape does give, for free, is a structural guarantee rather than a policy one:** the
producer holds write access to the spool and **cannot reach the target at all**. A wrong
automated write into the consumer's repository is impossible by construction. The limitation
that motivated this project is also its safety property, and that is worth not engineering away
later in the name of convenience.

### The five rules that make it work

1. **The consumer never deletes. It acknowledges.** Deleting is the producer's job, or a
   janitor's, after the ack is visible. A consumer that deletes destroys the only evidence that
   the item existed if the apply turns out to be wrong — and there is then nothing to replay.
2. **Delivery is at-least-once. Exactly-once does not exist.** Any ack can be lost between the
   apply and the stamp, so the same patch will occasionally arrive twice. **This is not a bug to
   engineer away — it is handled on the consumer side by making apply idempotent**, which is why
   `patch_id` is a key and why the consumer keeps its own record of what it applied.
3. **The payload is the finished text, not a hint.** "Employer replied" is not a patch. The line
   the target file should contain, written out, is. A patch that still needs interpretation has
   moved the work, not removed it.
4. **n8n proposes, the local session applies.** Nothing auto-writes into the dossier repo. That
   repo is the record of what was actually sent to real people; a wrong automated edit there is
   worse than no automation. This is also `GOVERNANCE.md`: agents suggest, maintainer approves.
5. **A patch names its target; it does not compute it.** `target_repo` and `target_file` are
   written by the producer. A consumer that decides for itself where a patch belongs has become
   a second author of the record, and then two systems own the same file.

### Where the memory actually lives

**Not in the local repository. That is the correction this section exists for.**

| Layer | Owner | Holds |
|---|---|---|
| **`Applications` sheet** | n8n | **the memory.** Every application and its current status. Survives the workstation. |
| **`Patches` tab** | n8n writes, local session acks | the queue of unapplied changes |
| **Drive folder** | n8n | payload blobs too big for a cell (claim check) |
| **The private dossier repo** | the local session | the documents, and a *rendering* of status for reading offline |

The repo stops being the source of truth for status and becomes a **projection** of it. That is
the point: a projection can be rebuilt from the sheet, and being wrong about status stops being
possible in one direction only.

### `Patches` schema

| Column | Notes |
|---|---|
| `patch_id` | key. Stable, producer-generated; the same detected event must produce the same id |
| `created_at` | |
| `target_repo`, `target_file` | producer decides; see rule 5 |
| `kind` | `status_change`, `new_application`, `deadline_hit`, `posting_expired` |
| `payload` | the finished text (rule 3) |
| `payload_ref` | Drive file id, when the payload does not fit a cell (claim check) |
| `state` | `pending`, `applied`, `rejected` |
| `applied_at` | stamped by the consumer |
| `reject_reason` | required when `state = rejected`; this tab is also the dead-letter queue |

**No lease or visibility-timeout column, deliberately.** Those exist to stop two consumers
taking the same item; there is exactly one consumer here. Add it if that ever stops being true,
and not before.

### Retention

`state = applied` rows are moved to a `Patches_log` tab and deleted from `Patches` on a
schedule, so the live tab only ever holds work. **The move happens first and the delete second**,
never the reverse: a crash between the two must lose nothing, and duplicating a log row is
harmless where losing one is not.

**The reaper belongs to this project**, because retention is part of the channel's own lifecycle
and nothing outside it knows when a patch is spent. `14_db-janitor` does the same kind of work on
a schedule and could host it later as a matter of taste — but that would be an upward edge
(`07 → 14`) and would need announcing in `general-registry.md`. Keeping the reaper here costs
nothing and keeps the dependency order clean.

## First consumer: application tracking

The channel above is generic. This is the first thing sent through it, and the reason it exists.
A second consumer would reuse `Patches` unchanged and bring only its own table.

### Grain

**One row per application, keyed by `application_id`.**

An application is *one employer, one role, one channel, one send*. A decision is an **update to
that row**, never a new one. A second application to the same employer for a different role is a
**second row**. A follow-up message is not a row.

Contacts are **not** duplicated here. `contact_email` references `Entries`; the person lives in
one book and the application in the other, the same separation `16` and `04` already use.

### Proposed `Applications` schema

| Column | Notes |
|---|---|
| `application_id` | key. `<rail>-<employer-slug>-<yymmdd>` |
| `rail` | which track this belongs to; the local repo already separates them |
| `employer`, `role`, `requisition` | identity of the target |
| `channel` | portal name, or `email` |
| `posting_url` | **required** - D7 cannot be fixed without it |
| `status` | controlled vocabulary, below |
| `status_changed_at`, `applied_at`, `deadline` | dates, ISO |
| `last_message_at` | most recent inbound, from the classifier |
| `contact_email` | foreign key into `Entries`, not a copy |
| `local_folder` | path in the private dossier repo, so a patch knows where to land |
| `outcome_reason` | free text, only when `status` is terminal |
| `notes` | |

**Status vocabulary - one definition, no synonyms:**
`draft`, `ready`, `applied`, `acknowledged`, `interview`, `offer`, `rejected`, `expired`,
`withdrawn`

`expired` is distinct from `rejected`, and it is the one a machine can detect on its own.

### The agent in the loop

The missing router is `filing-clerk` from D1: a classifier step that recognises *this message
concerns the job search* and routes here instead of to the contact CRM. It needs the
`FilingProjects` registry to exist as a real config node, not a diagram.

**Build the predicate before the route.** D3 is the same gap seen from the other side: there is
currently no expression anywhere in the lab that can say *this email is about an application*.

---

## To do - after the outstanding applications are sent

Ordered. Each line states what "done" looks like, so none of them can be half-finished quietly.

| # | Task | Done when |
|---|---|---|
| 1 | **Track `centerpiece.md`**, or delete it | the design is in git, or the misleading diagram is gone (D1) |
| 2 | **Reconcile `04/CLAUDE.md` with the workflow JSON** | doc and export agree on which nodes are disabled (D4) |
| 3 | **Surface the `inProgress` count** in the 7 AM briefing | a number appears daily; a stuck email is visible without a manual search (D5) |
| 4 | **Create the `Applications` sheet** with the schema above | headers exist, the grain line is copied to the top of the sheet, one row hand-entered as a shape test (D2) |
| 5 | **Backfill from the existing dossier repository** | every application already sent has a row, with `status` and `applied_at` correct (D9) |
| 6 | **Add `job_application` to the classifier's output vocabulary** | a decision letter classifies as such, with a confidence score (D6) |
| 7 | **Add the routing predicate, then the route** | the CRM branch stops running unconditionally, and a job reply reaches this project (D3) |
| 8 | **Create the `Patches` tab and the outbox writer** | a status change produces a `pending` row carrying finished text and a stable `patch_id` (D8) |
| 9 | **Teach the local session to read, apply and ack `Patches`** | a session starts by applying pending patches and stamping them, not by being told what happened. Applying the same `patch_id` twice changes nothing (D8) |
| 9a | **Add the reaper** (in this project) | acked rows move to `Patches_log`, then leave `Patches`; move before delete |
| 10 | **Add the posting-expiry watcher** | a daily request per open `posting_url`; a non-200, or a 200 landing on a different path, writes a `posting_expired` patch (D7) |

**Item 10 is the one with a measured price.** Everything above it is plumbing; that one is the
defect that has already cost two targets.

---

## Related

- `04_inbox-attachment-organizer` - the ingestion this depends on, and the source of D3 to D5
- `02_smart-table-fill` - the CRM engine; `docs/email-crm-guide.md` holds the `Entries` schema
- `16_commitments-ledger` - the two-book pattern this project copies
- `10_error-handler` - *"absence is not a diagnosis"*, which is why `expired` and `rejected` are
  separate values and why neither may be inferred from silence
- `14_db-janitor` - the same kind of scheduled cleanup, if the reaper is ever folded in there

**Pattern references, for the write-back channel:** transactional outbox, polling consumer,
idempotent consumer, inbox pattern, claim check and dead letter queue are all catalogued in
*Enterprise Integration Patterns* (Hohpe & Woolf) and in Microsoft's cloud design patterns.
`Maildir` (Bernstein) is the filesystem form of the same idea and the one to copy verbatim if
the store becomes Drive folders instead of a sheet.
