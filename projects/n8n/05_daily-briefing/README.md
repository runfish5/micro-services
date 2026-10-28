# 05 - Daily Briefing

Morning briefing to Telegram on a 7 AM schedule.

## What It Does

Sends a Telegram message with:
- Today's Google Calendar events (time + title)
- Standing commitments and what is due (via the plugin seam — see below)
- Current prices for tracked products (via price-checker subworkflow)
- Who visited the website yesterday, who signed in to the app and what they did, and who signed up
- Inline buttons for on-demand actions: Expenses, Learning Notes, Deal Finder, Kanban, Help.
  Tasks send no message of their own; they are ticked on Kanban until the keyboard carries a row
  per task (spec § Actions)

Button taps route through the steward's menu-handler (project 10).

## The plugin seam

`Plugins` (a Code node registry) → `Run Plugin` (dynamic Execute Workflow) → `Format Message`.
Each registry line names a subworkflow that returns one section as **plain-text blocks**;
`Format Message` escapes and renders them generically, ordered by the registry's `order`.

Adding a morning section is one line in `Plugins` — no new nodes here. `order` puts actionable
sections first: when the message is too long, what sorts last is what moves to a second message.

`Run Plugin` has `onError: continueRegularOutput`, which is the point of the whole arrangement:
a plugin that throws costs its own section (`⚠️ COMMITMENTS unavailable`) instead of the entire
morning message. Failures are named by matching registry keys against returned keys, so a
crashed plugin is still identifiable.

Currently installed: `commitments` (project 16), `upkeep` (project 10), `reach` (project 17:
yesterday's contact-form messages in full, and who asked for, confirmed or left the newsletter),
`app` (project 18: who signed in to the app and what each account did), `inbox` (project 04:
emails held back because an LLM daily quota ran out: an alert until they are rerun, nothing on a quiet day) and `site` (project 20:
yesterday's website visitors). The signups section is built inside `Format Message`.

Layout (v5): ⚠️ NEEDS ATTENTION (every plugin's `alert` lines), 💳 COMMITMENTS, 🏺 PROMPTPOTTER
(signups, app, site inbox and site as one cluster: a summary line and one collapsed box), 🔧 UPKEEP
(collapsed). Levels, summaries and clusters: [docs/briefing-plugin-spec.md](docs/briefing-plugin-spec.md).

## The site section

Rendered by the bot detector ([20_bot-detector](../20_bot-detector/)) from its own `verdicts`
table, so the visitors it counts are the visitors it judged. Its grain, its `×N` lines and how
your own traffic is kept out are that project's README.

## The signups section

`Get Signups` reads the `signups` table of the records store, written by
[shared/signup-intake](../shared/). It prints the free-tier total every day and one line per
signup in the last 24 hours: name and use case.

Notes for anyone editing `Format Message`:

- It reads every upstream **by node name** (`$('Check Prices')`, `$('Get Signups')`, …),
  never `$input`. That is what lets nodes be inserted into the chain without breaking it.
- The Telegram node uses `parse_mode: HTML` and strangers write what flows through it, so every
  interpolated value is HTML-escaped. Dropping an `esc()` lets one `<` silently kill the
  whole message.
- Telegram rejects messages over 4096 characters, counted after HTML parsing, and that is what
  is measured. Over it, the collapsed detail shrinks first (each cut says `… +N more`); only then
  does the rest go out as a second message, cut at a section boundary. Nothing is dropped silently.
