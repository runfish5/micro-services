# Briefing Plugin Seam — spec

**Status: stages 1–2 live as of 2026-08-12. Stages 3–6 proposed.**

| | Live |
|---|---|
| Seam + commitments section | ✅ `daily-briefing` 16 nodes |
| Two-button actions, `tk\|` tap handling | ✅ `menu-handler` 28 nodes (unchanged), `commitments` 19 nodes |
| Reconciler audit of claimed-done (stage 4) | ✅ daily, in `commitments` |
| Agent dispatch on assign (stage 3) | ❌ |

**Since 2026-10-28 an action sends no message of its own** (see **Actions**): the per-action
messages are gone, and the row per task on the briefing's own keyboard waits on the bot token
being usable from an HTTP Request. Until then a task is ticked on 🗂 Kanban (`/board done <n>`).

A tap records `assigned` or `done` and redraws the message. **No agent acts on an assignment
yet** — that is stage 3, so a task sits at `⏳ assigned` until closed by hand. That is the honest
behaviour: it stays on the list because it is genuinely not done.

Stage 4 shipped ahead of stage 3 on purpose. It is what makes `done` trustworthy, and an agent
that can close its own tasks with nothing checking is the single failure mode this design exists
to prevent — so the check landed before the thing that needs checking.

## The plugin trigger accepts passthrough

A plugin's Execute Workflow Trigger uses `inputSource: passthrough`, and the registry item is
therefore the input — `Run Plugin` declares no `workflowInputs` at all.

This was forced by unification: the same trigger serves the digest and the task tap, and named
inputs (`date`, `tz`) would strip `taskVerb`, `taskId`, `messageId` and `callbackId` off every
tap. So `Plugins` emits `date` and `tz` on each registry row and they ride along with
`key`/`order`/`workflowId`. A plugin sees a few fields it does not care about, which costs
nothing; the alternative cost a whole second workflow.

One seam in `daily-briefing` where any project can install a morning section, so
`15_site-visits` and `16_commitments-ledger` plug into the same socket instead of each one
growing another hundred lines inside `Format Message`.

## The problem this fixes

`Format Message` is 179 lines. Roughly a hundred of them are the site digest — which belongs to
project 15. Three costs, in ascending order of how much they hurt:

1. **Ownership is inverted.** Project 15 owns the `Visits` sheet, the beacon, the retention job
   and the privacy position — but not the code that renders its own digest. `SELF_IPS`, a
   privacy-sensitive constant that is 100% a project-15 concern, lives in project 05.
2. **Every new section is surgery on a working node.** The briefing is the one workflow whose
   output a human reads every single morning; it is the worst place in the repo to be editing a
   long Code node in a hurry.
3. **There is no failure isolation.** One plugin's bad read, bad expression or missing sheet
   throws, and the *entire* 7 AM message never arrives — calendar, prices and all. Today a
   typo in the visits code costs you the day's briefing.

Point 3 is the real argument. The seam is not tidiness; it is the difference between one
section reading `⚠️ unavailable` and the whole morning going silent.

## Shape

```
Schedule 7 AM → Get Today's Events → Plugins (Config) → Loop Over Items
                                                            │
                                        ┌───────────────────┴──────────────┐
                                        │  Run Plugin (Execute Workflow,   │
                                        │  workflowId from registry,       │
                                        │  continueOnFail: true)           │
                                        └───────────────────┬──────────────┘
                                                            ▼
                                              Render Message → Send to Telegram
```

Config-driven dispatch over a dynamic `Execute Workflow` is already the house pattern —
`12_steward`'s menu-handler routes its agents exactly this way. Same registry idea, different
payload: sections instead of replies.

## The contract

**A plugin is a subworkflow that takes a date and returns one section.**

Input:

```json
{ "date": "2026-08-12", "tz": "Europe/Zurich", "window_hours": 24 }
```

Output — exactly one item, always, even with nothing to report:

```json
{
  "key": "commitments",
  "icon": "💳",
  "title": "COMMITMENTS",
  "summary": "CHF 22.75/mo · 1 commitment",
  "blocks": [
    { "level": "alert", "items": ["TalkTalk billed CHF 99.75, expected 22.75\n338% over · due in 4d · check the bill"] },
    { "heading": "To pay", "items": ["TalkTalk · CHF 22.75 · due in 19d"] },
    { "heading": "Leaving", "items": [] }
  ],
  "actions": [
    {
      "text": "TalkTalk · CHF 22.75 · due in 49d",
      "buttons": [
        { "label": "✅ Done",   "cb": "tk|d|talktalk::mobile@2026-09" },
        { "label": "🤖 Assign", "cb": "tk|a|talktalk::mobile@2026-09" }
      ]
    }
  ],
  "empty": "Nothing tracked"
}
```

**Layout fields** (the approved v5 layout, 2026-10-27):

- **`level`** on a block: `alert` | `main` (the default) | `detail`. `alert` items are lifted
  into the ⚠️ NEEDS ATTENTION block at the top of the message and are never collapsed; `main`
  is visible under the section; `detail` goes into one collapsed `<blockquote expandable>`.
  **Which line is an alert is the plugin's decision** — the owner knows its data. An alert is
  plain words, what happened and then what to do, and never an internal id.
- **`summary`**: the section's headline, the italic line under its header (or its part of a
  cluster's summary line). Optional; empty means nothing to headline.
- **`empty: ''`**: the section says nothing on a quiet day. With no `main` or `detail` blocks it
  renders no header at all, only its alerts (if any) at the top. `inbox` uses it: an alert while
  emails are held back, otherwise nothing. Any other `empty` is printed as the quiet-day line.
- **Item text**: a `\n` inside an item is the plugin's own layout — line one is the item, the
  rest its detail lines. A long one-line `·` item is split by the renderer, one fact per line;
  a fully parenthesised item renders as an italic footnote. A trailing `(…)` in a `heading`
  renders as an italic qualifier. The renderer puts every page path (a token starting with `/`)
  in `<code>`, so Telegram does not turn it into a bot command.

`actions` is optional. An action is **one row of the briefing's own inline keyboard**, never a
message of its own: the first button carries the glyph of its `label` plus the action's short
label (`✅ TalkTalk · CHF 22.75`), the others their glyph only (`🤖`). The short label is the
action's optional `label`, else the first `·`/`—` facts of its `text` that fit 26 characters.
`Format Message` builds the whole keyboard as Telegram's own `reply_markup` (task rows, then the
menu); an action whose `callback_data` is over 64 bytes is left out and named in NEEDS ATTENTION,
because Telegram rejects the *entire* keyboard for one bad button.

**What is live (2026-10-28): the menu only.** The Telegram node's keyboard is a static
`fixedCollection`, and n8n drops an expression put in its place (verified: exec 14896 sent the
briefing with no keyboard at all). A varying keyboard therefore needs a raw `sendMessage` through
an HTTP Request, and the existing Telegram credential cannot authenticate one: `telegramApi`
defines no `authenticate`, and the token sits in the URL path. Moving the send to HTTP needs the
bot token in a credential an HTTP Request can use: a new holder, so the operator's call. Until
then `reply_markup` is built and not sent, `Send to Telegram` carries the static menu, and a
task is ticked on 🗂 Kanban (`/board done <n>`), which moves the same `Tasks` rows.

A tap (on an older per-task message today, on a task row once the keyboard ships) goes through
`menu-handler` → `commitments`: the row is written, `Redraw Keyboard` rebuilds the message's HTML
from the callback's text and entities so the text stays exactly as sent, and works out the
keyboard minus the tapped row; `Answer Tap` shows `✅ marked done` / `🤖 assigned to an agent`.
`Tick Message` can only send no keyboard today, so the edit removes it.

Two verbs rather than one checkbox, because they are different claims: `d` (done) asserts the
money moved, `a` (assign) hands the task to an agent and leaves it open. Collapsing them would
make an assignment look like a payment.

Four rules, each of which exists because breaking it has a specific consequence:

1. **Plain text only. Never HTML.** The briefing escapes centrally, exactly as it does today.
   If plugins emitted markup, escaping would become five projects' shared responsibility and
   one forgotten `esc()` in any of them would kill the whole `sendMessage` — trading the
   failure isolation this seam is being built for.
2. **Always return an item.** A plugin with nothing to say returns empty `blocks`; the briefing
   prints `empty`. Returning zero items is indistinguishable from a crash.
3. **Never throw for "no data".** Throw only for genuinely broken — unreachable sheet, bad
   credential. That is the signal that earns the `⚠️` line.
4. **Own your own filtering.** The window, the sort, the self-exclusion are the plugin's
   business. The briefing does not know what a visitor or a commitment is.

## The registry

A `Plugins` Code node, single source of truth:

```js
return [
  { json: { key: 'commitments', order: 20, workflowId: 'ID_COMMITMENTS_DIGEST', enabled: true } },
  { json: { key: 'site',        order: 40, workflowId: 'ID_VISITS_DIGEST',      enabled: true } },
];
```

`order` is message position, and it is a real decision rather than cosmetics: Telegram hard-caps
at 4096 characters and the tail is what gets truncated. **Anything actionable sorts first.** A
commitments list that got cut because a busy traffic day pushed it past the limit is a missed
payment.

`enabled: false` is the kill switch — a misbehaving plugin gets switched off in one place
without unwiring nodes.

**`cluster`** (`{ key, icon, title }`) groups plugins into one section: a visible header, one
summary line joined from the members' `summary`, then ONE `<blockquote expandable>` holding
every member's sub-section (Telegram has no toggle inside a toggle). A member's alerts still go
to the top. The live order is NEEDS ATTENTION, COMMITMENTS (20), 🏺 PROMPTPOTTER (signups 34,
app 35, site inbox 36, site 38), 🔧 UPKEEP (60, all `detail`). Signups has no subworkflow: its
row and section are built inside `Format Message`, and it joins the `promptpotter` cluster there.

## What is left in the briefing

`Render Message` keeps only what is nobody's plugin: `esc()`, block rendering, ordering, the
4096-char limit, and the calendar — which stays inline because it is the message's subject, not
a section of it. Target is roughly 40 lines with no domain logic in them.

**The limit is measured as Telegram counts it**: the text after HTML parsing (tags stripped,
entities unescaped), not the raw HTML. Over it, nothing is dropped silently. First the collapsed
detail shrinks, step by step (8 items per list, then 5 with 3 detail lines, then 3 with 1, then
1 with none), each cut saying `… +N more`. Only if that is still too long does the rest go out as
a second message, `Morning briefing, continued`, cut at a section boundary; a single section
too long by itself is split on line boundaries, a collapsed box closed and reopened at the cut.
The keyboard stays on the first message.

## Actions — the checkbox, and what Telegram will actually do

**Telegram cannot make text tappable.** A `[ ]` written into the message body is three inert
characters; there is no way to attach a handler to a substring, and no native checkbox element.

What exists instead is the **inline keyboard**: buttons attached below the message, each
carrying up to 64 bytes of `callback_data`. Those buttons can hold the glyph — `☐ TalkTalk ·
22.75` — and after a tap the bot edits the message in place and redraws the same button as
`☑ TalkTalk · 22.75`, or drops it entirely. So the experience is exactly the one asked for; the
checkbox is a control one line below the text rather than a character inside it.

Verified structure (checked against the Telegram node source — each button is a **direct**
object; wrapping it in `{ "button": {…} }` silently drops `callback_data` and Telegram rejects
the keyboard):

```json
"replyMarkup": "inlineKeyboard",
"inlineKeyboard": { "rows": [ { "row": { "buttons": [
  { "text": "☐ TalkTalk · 22.75", "additionalFields": { "callback_data": "tk|talktalk::mobile@2026-09" } }
] } } ] }
```

The `sendAndWait` operation is not an alternative — its buttons are resume-webhook links that
open a browser. In-chat taps require `callback_data` plus a Telegram Trigger listening for
`callback_query`, which `menu-handler` already does.

### Only actionable rows get a button

`To pay` rows get one; `Leaving` rows (direct debit, card) do not. A keyboard with a button per
commitment plus the four standing menu buttons stops being scannable quickly, and a checkbox
next to money that moves by itself invites ticking something you did not do.

This is the second job the `payment_method` vocabulary does: it already decides how a row reads,
and it now decides whether the row is tappable.

### ⚠️ `::` collides with the existing callback parser

`menu-handler`'s `Normalize` extracts the action with `data.split(':')[1]`. Fed a
colon-delimited task callback, that yields a meaningless fragment rather than a task id —
`tk:a:talktalk::mobile@2026-09` gives `"a"`, and `tk:talktalk::mobile@2026-09` gives
`"talktalk"`. Neither matches a known action, so both fall through to the free-text branch and
get handed to the AI classifier. No error, no alert, a nonsense reply.

Two changes, both required:

1. Task callbacks use `|` as the outer delimiter: `tk|<task_id>`.
2. `Normalize` checks for the `tk|` prefix **before** the generic colon split, and routes it out
   as its own action.

**Budget the 64 bytes.** `tk|talktalk::mobile@2026-09` is 27, comfortable — but the limit is on
the encoded bytes and a long vendor slug plus a long service slug will reach it. Keep slugs
short, and if a `task_id` exceeds ~55 characters fall back to the sheet row index. Telegram
rejects the whole keyboard when one button is over, so the failure is the entire briefing losing
its buttons, not one row.

## Assignment — the network of agents

A tap is not "mark it done". It is **hand this task to whoever can do it**, which is why the
button is worth more than a checkbox.

The dispatch machinery already exists. `menu-handler` has a Config registry of agents, an AI
classifier that routes free text to one of them, and an `Agent Available?` guard for when none
fits. "Assign to a nonspecific agent" is that path, entered from a button instead of a typed
sentence: the task's text goes to the classifier, the classifier picks, the guard handles nobody
being able to take it.

Nothing new is needed to *choose* an agent. What is missing is somewhere to record that the
task exists and how it ended.

### The `Tasks` tab — and a revision to the ledger design

`16_commitments-ledger` says expected charges are never stored, because a materialised future
charge is a guess with no information the `cadence` + `amount_expected` rule does not already
carry.

**Assignment changes that input.** An occurrence now carries state — who took it, when, whether
it finished — and state cannot be derived from a rule. So the occurrence earns a row, in its own
tab, and the reasoning behind the original rule stays intact: `Commitments` remains purely
declarative and is still never written by any automation.

Three tabs, three jobs, and the separation is what keeps them honest:

| Tab | Holds | Written by |
|-----|-------|-----------|
| `Commitments` | what we agreed to | a human, by hand |
| `Tasks` | what needs doing this period, and how it went | the generator and the agents |
| `Billing_Ledger` | what the counterparty actually billed | project 04 |

**Grain: one row per (`commitment_id`, `period`)**, keyed by `task_id` = `talktalk::mobile@2026-09`.
`@` separates the period so the `::` slug stays intact and no delimiter is reused.

```
task_id | commitment_id | period | due_date | amount | currency | action |
status | assignee | assigned_at | closed_at | evidence | attempts | notes
```

`status`: `open` → `assigned` → `done` | `failed`.

A generator materialises the next period's rows from `Commitments` with `appendOrUpdate` on
`task_id`. That makes it **idempotent**, so it can run daily rather than monthly — a commitment
added today gets its task tomorrow morning without anyone remembering to trigger anything, and a
re-run never duplicates.

### The vanishing rule

Gone tomorrow means it worked. Still there means it did not. That is the whole status display,
and it is worth noticing *why* it is robust: **presence is the default and absence is the
achievement.** A task that fails, half-finishes, or is never picked up requires no error
handling to stay visible — it simply does not get removed. There is no path where a broken agent
results in a silently empty list.

`failed` rows come back with a `⚠️` and the reason, because "tried and could not" is worth
distinguishing from "nobody has started".

### Claimed done is not verified done

The dangerous case is an agent reporting success it did not achieve. The task vanishes, and
nothing ever contradicts it.

So the two are separated. A tap or an agent sets `done` — **claimed** — and the row does drop off
the next morning's list, because a briefing that keeps nagging about handled things is a briefing
people stop reading. The monthly reconciler then independently checks each claimed-done task for
evidence in `Billing_Ledger`, and **resurrects** any that has none:

```
⚠️ TalkTalk 2026-09 — marked done, no payment evidence
```

Optimistic hide, periodic audit. The daily list stays short and the lie is still discoverable —
and because the check runs against project 04's independently-written ledger, no agent can clear
itself.

### An agent cannot pay a QR invoice

Worth stating before it is built, because the first task on the list is exactly this case: there
is no banking integration here, so nothing in this system can move money. For
`talktalk::mobile`, an agent can fetch the invoice from Gmail, pull the reference and amount,
check them against the commitment, and hand back a ready-to-scan payload — but the scan is
human.

That is not a hole in the design, as long as the last inch is *reported* rather than assumed.
The system does not need to know in advance which tasks agents can finish: it dispatches, the
agent returns `failed: needs human`, and the row stays on the list — which is correct, because
it does need you. The honest failure mode is the feature.

## Migration

Staged, so the seam is proven before anything working is moved onto it.

| Stage | Work | Risk |
|-------|------|------|
| 1 | Seam + `commitments-digest`, **text only, no buttons** | None — new section, existing ones untouched |
| 2 | `Tasks` tab + generator; `actions` in the contract; `tk\|` route in `Normalize`; tap → `☑` | Low, but it edits `menu-handler` — the live command surface |
| 3 | Agent assignment: tap dispatches through the classifier, agent writes back `done`/`failed` | The interesting one |
| 4 | Reconciler audits claimed-done against `Billing_Ledger` | Low — read-only until it resurrects a row |
| 5 | Done differently: the site digest became `20_bot-detector`'s `site` section, rendered off its verdicts, and `SELF_NETS` moved there. It counts yesterday's visitors rather than the last 24 h, so the message changed on purpose | — |
| 6 | Signups and prices become plugins. Note the Signups section has never rendered (one signup, ever) — port it, but do not read its silence as proof the port worked | Low |

Stage 1 stands on its own even if nothing after it happens: it ships the nagging list, and it
proves the contract against a plugin with no legacy behaviour to preserve.

Stage 2 is where the checkbox appears, and it is the first stage that touches `menu-handler` —
the only live Telegram command surface in the lab. A broken `Normalize` there takes out `/help`
and every agent button, not just the new one.

Stage 4 is what makes stage 3 trustworthy rather than merely convenient. Do not ship agent
assignment and leave the audit for later; an agent that can close its own tasks with nothing
checking is the one failure mode this design exists to prevent.

Stage 5 pays off the ownership inversion, and can regress a feature you read daily. Do it
against a `Manual Trigger` run and compare output text literally.

## Caveats

- **Sub-executions multiply.** Five plugins is five extra executions a day, every day. Set
  `saveDataSuccessExecution: none` on the plugin subworkflows the way `15_site-visits` does for
  its webhook, or the execution list — and the ops-center failure view — fills with routine
  successes.
- **`continueOnFail` is mandatory on the Execute Workflow node**, with a guard so a null result
  renders as `⚠️ <key> unavailable`. Without both, the seam provides no isolation and the whole
  exercise is pointless.
- **Dynamic dispatch needs** `workflowId` set to `={{ $json.workflowId }}` with
  `__rl: true, mode: "id"`, plus a blue sticky note behind the node recording the parameters —
  the n8n UI silently clears `workflowInputs` when a subworkflow is re-selected.
- **Sequential loop**, so latency is the sum of the plugins. Irrelevant at 7 AM, worth knowing
  before anything real-time reuses this.
- **The registry holds live workflow IDs**, so the committed copy carries placeholders like
  every other ID in this repo.
- **A plugin subworkflow must be ACTIVE or it cannot be called.** Verified the hard way on
  2026-08-12: the first test briefing rendered `⚠️ COMMITMENTS unavailable` because
  `commitments-digest` existed but was not activated — `Run Plugin` returned
  `"Workflow is not active and cannot be executed."` Activating a subworkflow whose only trigger
  is an Execute Workflow Trigger is not obvious, and the symptom names no cause. Check this
  first when a section reads unavailable.
- **`answerCallbackQuery` looks unhandled today.** Telegram spins a loading indicator on a
  tapped button until the bot acknowledges it; `menu-handler` ends at a `sendMessage`. Verify on
  the live bot before adding buttons that are tapped far more often than the menu — an
  un-acknowledged tap reads as a hang, and the natural response to a hang is tapping again.
- **Taps land on old messages.** Yesterday's briefing keeps its buttons and its `callback_data`
  is still delivered, but editing a message that old can fail. Write the state first, then
  attempt the redraw, and treat a failed edit as cosmetic — never let it roll back a recorded
  assignment. `chat_id` and `message_id` both arrive on `callback_query.message`, so nothing
  needs storing to perform the edit.
- **Double taps are inevitable** on a message that sits in the chat all day. Keying `Tasks` on
  `task_id` with `appendOrUpdate` makes a repeat tap a no-op rather than a second assignment.

## First plugin: `commitments-digest`

Lives in `16_commitments-ledger/workflows/`. Reads the `Commitments` tab, keeps rows where
`status = active` and `valid_to` is empty, and returns **every one of them, every morning** —
sorted by days-to-due, `qr-invoice`/`bank-transfer`/`twint` under **To pay**, `direct-debit`/`card`
under **Leaving**, with the monthly total in the section's first line.

This is a standing list, not an alert. It does not wait for a due date to approach, because the
value is seeing the whole set of recurring obligations next to the calendar every single
morning — a bill that only appears once it is nearly late has already stopped being a dashboard.

`cadence: monthly` only in v1. Quarterly and yearly rows are skipped rather than shown with a
guessed date; their next occurrence has to be anchored to `valid_from`, which is worth doing
properly rather than approximately.
