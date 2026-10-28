# CLAUDE.md — 05 Daily Briefing

Guidance for Claude Code when editing the 7 AM briefing. Read `README.md` first for what the
message contains.

## What this workflow actually is

A **renderer with plugins**. It owns no data. Every section is somebody else's sheet or
subworkflow, read at 7 AM and turned into one Telegram message:

```
Schedule Trigger ┐
                 ├→ Get Today's Events → Check Prices → Get Signups → Plugins → Run Plugin → Format Message → Send to Telegram
Manual Trigger   ┘
```

| Section | Source | Owned by |
|---------|--------|----------|
| Calendar | Google Calendar | — |
| Prices | `price-checker` subworkflow | `12_steward` |
| Site | `site` plugin, off its `verdicts` table | `20_bot-detector` (the visits are `15_site-visits`') |
| App | `app` plugin | `18_account-trail` |
| Signups | `signups` table (records store) | `shared/signup-intake` — active, but only 1 row has ever been written |

Keep it that way. **Logic that produces data belongs in the owning project; this workflow only
formats.** The moment the briefing starts computing something nobody else can see, that thing
becomes invisible to every other surface — the steward, the ops center, a future `/commitments`
command — and it can only ever be looked at once a day at 7 AM.

**The Signups section has never rendered, and that is data, not a defect (2026-08-13).**
`shared/signup-intake` writes `Sheet1` and has been **active** all along.

What changed is the sender: no longer the marketing site's waitlist form (parked) but the
**PromptPotter app**, which posts every new account to that workflow; signups now also land in the
CRM automatically. The section reports the running free-tier total on every run (rule 4 below), so
a silent one is now a broken one — which is the point of always printing it. If intake is ever
abandoned, delete `Get Signups` and `signupSection` together.

⚠️ **The total counts SHEET ROWS, and the app's account count is the real number.** They agree only
while every account has reached this workflow; accounts created before the app's CRM forward existed
are missing from the sheet and invisible here. The app carries its own `account_count` on each
signup POST — believe that one when they disagree.

## The plugin contract

Sections are plugins: a `Plugins` registry row names a subworkflow, `Run Plugin` runs it, and
`Format Message` renders what comes back by key. The full contract is
`docs/briefing-plugin-spec.md`; in short a plugin returns
`{key, icon, title, summary, blocks, actions, empty}`, plain text only, and:

- a block carries a `level`: `alert` (lifted into the top ⚠️ NEEDS ATTENTION block, never
  collapsed), `main` (visible, the default) or `detail` (collapsed). **The plugin that owns the
  data decides which line is an alert**; an alert says what happened and what to do, in plain
  words, with no internal ids;
- `summary` is the section's headline: the italic line under its header, or its part of a
  cluster's summary line;
- a registry row's `cluster` (`{key, icon, title}`) makes its members ONE section: a visible
  header and summary line, then one `<blockquote expandable>` with every member's sub-section.
  Signups is the one member with no subworkflow; it is built and slotted in inside `Format Message`.

**1. All markup lives in `Format Message`.** It reads every upstream **by node name** —
`$('Get Signups')`, `$('Check Prices')` — and never `$input`: a single `$input.all()` silently
rebinds to whichever node sits immediately above it.

**2. Order comes from the registry.** NEEDS ATTENTION, COMMITMENTS, 🏺 PROMPTPOTTER (signups, app,
site inbox, site), 🔧 UPKEEP. A cluster sits at its first member's `order`.

**3. Escape everything interpolated.** The Telegram node uses `parse_mode: HTML`, and much of
what flows through here is written by strangers — link labels, use cases, product names. `esc()`
exists for this. A single unescaped `<` does not mangle one line; it fails the whole
`sendMessage` call and the morning message never arrives.

**4. Decide deliberately whether the section renders when empty**, and write the reason down.

The precedent is split, and both sides are correct:

- **SITE always renders**, even at zero visitors (`No visitors`): a missing section is
  indistinguishable from a broken pipeline.
- **SIGNUPS always renders** — it did not always, and the flip is the clearest worked example of
  the test below. It used to only announce arrivals, so silence was a normal day. Then signing up
  started GRANTING access on the operator's shared provider key, and the section stopped answering
  "did anyone arrive?" and started answering "how many people can spend my money?" — a question you
  would otherwise go and check. Same section, same code, different meaning of silence.

The test is what silence *means*. If the section answers a question you would otherwise go and
check ("did anything need paying?"), silence is an answer and must be printed — a one-liner is
enough. If it only announces events, silence is not worth a line.

**5. Respect the tail cap.** Telegram hard-rejects over 4096 characters. The truncation cuts on
a line boundary outside any open blockquote, so it never splits an entity or leaves a tag
unclosed. The tail is what gets cut; alerts are always at the top, whatever their plugin's order.

## Two different spreadsheets

`Get Signups` calls the records store (`19_records-store`) and holds no `documentId`. `Get Commitments` reads the **Billing_Ledger** document.

## Never commit personal data in this file

A home address is personal data and this repo is public, so the own-network list (`SELF_NETS`,
in `20_bot-detector` and `15_site-visits`) is placeheld in committed copies and set only on the
live instance. The same rule extends to every plugin: customer numbers,
phone numbers and account references stay in the sheets, and the workflow reads them from there.
The mirror script refuses to write a workflow containing an IPv4 literal — treat that as the
floor, not the ceiling.

## Error workflow — bound 2026-08-12

The live briefing had **no `errorWorkflow`** until 2026-08-12; it was verified unbound against
the instance, not just missing from an old export. It is now bound to `007_error-handler.n8n`,
as are `commitments-digest` and `commitments-task-generator`.

It matters more here than almost anywhere else: the briefing is a **once-a-day scheduled trigger
with a human as its only consumer**. If it throws at 07:00, nothing retries and no alert fires —
the failure looks exactly like a quiet morning.

## Live vs committed

Promote committed code to live by taking the committed code and re-injecting any live constant,
never by hand-patching live code.

## Open thread — `/visits`

The SITE section prints five lines per verdict and then `+N more visitors`; there is no way to ask
for the rest from Telegram.

Intended fix: a `/visits` agent built as `12_steward/CLAUDE.md` § "Adding a New Agent" describes.
A subworkflow reads the `verdicts` table and returns `{chatId, response}`; add an entry in the
menu-handler **Config** registry and the key in the Classifier Output Parser `route_type` enum.

The only live Telegram command surface is `menu-handler` (`/help`, the agent registry, free-text
routing). `13_n8n-ops-center/telegram-command-interface.n8n.json` is committed but not imported:
`/status`, `/failures`, `/retry` and `/search` do not exist on the live bot.
