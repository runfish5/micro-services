# CLAUDE.md — 05 Daily Briefing

Guidance for Claude Code when editing the 7 AM briefing. Read `README.md` first for what the
message contains and why the site digest reads the way it does.

## What this workflow actually is

A **renderer with plugins**. It owns no data. Every section is somebody else's sheet or
subworkflow, read at 7 AM and turned into one Telegram message:

```
Schedule Trigger ┐
                 ├→ Get Today's Events → Check Prices → Get Signups → Get Visits → Format Message → Send to Telegram
Manual Trigger   ┘
```

| Section | Source | Owned by |
|---------|--------|----------|
| Calendar | Google Calendar | — |
| Prices | `price-checker` subworkflow | `12_steward` |
| Site | `Visits` tab | `15_site-visits` |
| Waitlist | `Sheet1` (Signups) | `shared/signup-intake` |

Keep it that way. **Logic that produces data belongs in the owning project; this workflow only
formats.** The moment the briefing starts computing something nobody else can see, that thing
becomes invisible to every other surface — the steward, the ops center, a future `/commitments`
command — and it can only ever be looked at once a day at 7 AM.

## The plugin contract

> **This describes how it works today: sections are hardcoded inside `Format Message`.**
> A proposed replacement — one registry-driven seam where projects install their own section
> subworkflows — is specced in `docs/briefing-plugin-spec.md`. Until that is built, the rules
> below are the contract, and rules 3–5 survive the migration unchanged.

Adding a section means one reader node plus one string. Both halves have rules.

**1. Insert the reader node into the chain, anywhere before `Format Message`.**

Safe because `Format Message` reads every upstream **by node name** — `$('Get Visits')`,
`$('Check Prices')` — and never `$input`. That is load-bearing, not stylistic: it is what lets
a node be spliced into the middle of the chain without renumbering anything downstream. A single
`$input.all()` in that code node silently rebinds to whichever node happens to sit immediately
above it, and the section it feeds starts rendering another plugin's data.

**2. Build the section as its own `const`, concatenated at the end.**

```js
let message = `☀️ Good morning! Your day:\n${calendarBlock}${priceSection}${siteSection}${signupSection}`;
```

Each section string starts with its own leading `\n\n` and is `''` when it has nothing to say.
No section reaches into another's variables.

**3. Escape everything interpolated.** The Telegram node uses `parse_mode: HTML`, and much of
what flows through here is written by strangers — link labels, use cases, product names. `esc()`
exists for this. A single unescaped `<` does not mangle one line; it fails the whole
`sendMessage` call and the morning message never arrives.

**4. Decide deliberately whether the section renders when empty**, and write the reason down.

The precedent is split, and both sides are correct:

- **SITE always renders**, even at zero visitors. A missing section is indistinguishable from a
  broken pipeline, and that ambiguity cost real confusion the first morning it shipped — no
  visitors looked like no feature.
- **WAITLIST renders only when non-empty.** It reports arrivals; silence is a normal day, not a
  claim about system health.

The test is what silence *means*. If the section answers a question you would otherwise go and
check ("did anything need paying?"), silence is an answer and must be printed — a one-liner is
enough. If it only announces events, silence is not worth a line.

**5. Respect the tail cap.** Telegram hard-rejects over 4096 characters. The truncation cuts on
a line boundary so it can never split an HTML entity. Sections added near the end of the
concatenation are the ones that get cut, so put anything actionable early in the message.

## Two different spreadsheets

`Get Signups` and `Get Visits` read the **same** document (the site's inbox). `Get Commitments`
reads the **Billing_Ledger** document. Two different `documentId` values live in this workflow —
check which one you are pointing at before copying a node.

## Never commit personal data in this file

`SELF_IPS` is empty in the committed copy and populated only on the live instance; a home IP is
personal data and this repo is public. The same rule extends to every plugin: customer numbers,
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

## Live vs committed — the seam is not deployed yet

`daily-briefing.json` in this repo **has** the plugin seam. The live workflow (11 nodes) does
**not** — it was left untouched on purpose while the seam was proven on a sandbox copy.

Promoting it means splicing `Plugins` + `Run Plugin` in and replacing `Format Message`, and the
one thing that must not be lost in the process is the live `SELF_IPS` value, which exists only
on the instance. The sandbox build handled this by taking the committed code and re-injecting
the live constant — do the same, in that direction, rather than hand-patching live code.

## Open thread — `/visits`

The site digest ends with "→ full detail in the Visits sheet" rather than "→ /visits" because
that command does not exist yet. Full context and the intended fix are in the root `CLAUDE.md`.
Swap the line in `Format Message` when the agent lands.
