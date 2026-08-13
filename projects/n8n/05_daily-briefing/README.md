# 05 - Daily Briefing

Morning briefing to Telegram on a 7 AM schedule.

## What It Does

Sends a Telegram message with:
- Today's Google Calendar events (time + title)
- Standing commitments and what is due (via the plugin seam — see below)
- Current prices for tracked products (via price-checker subworkflow)
- Who visited the website in the last 24 h, and who signed up (there has been exactly one signup so
  far, so that section has yet to render)
- Inline buttons for on-demand actions: Expenses, Learning Notes, Deal Finder, Help

Button taps route through the steward's menu-handler (project 10).

## The plugin seam

`Plugins` (a Code node registry) → `Run Plugin` (dynamic Execute Workflow) → `Format Message`.
Each registry line names a subworkflow that returns one section as **plain-text blocks**;
`Format Message` escapes and renders them generically, ordered by the registry's `order`.

Adding a morning section is one line in `Plugins` — no new nodes here. `order` puts actionable
sections first, because Telegram truncates at 4096 characters from the tail.

`Run Plugin` has `onError: continueRegularOutput`, which is the point of the whole arrangement:
a plugin that throws costs its own section (`⚠️ COMMITMENTS unavailable`) instead of the entire
morning message. Failures are named by matching registry keys against returned keys, so a
crashed plugin is still identifiable.

Currently installed: `commitments` (project 16). The site and waitlist sections below are still
hardcoded in `Format Message` and are staged to move onto the seam — see
[docs/briefing-plugin-spec.md](docs/briefing-plugin-spec.md).

## The site digest

Two Google Sheets reads sit between *Check Prices* and *Format Message* and feed the
last two sections of the message:

| Node | Reads | Renders |
|------|-------|---------|
| `Get Visits` | `Visits` tab — written by [15_site-visits](../15_site-visits/) | a summary: visitor/view/click totals, top pages, countries, and the 3 most engaged visitors |
| `Get Signups` | `Sheet1` — written by [shared/signup-intake](../shared/) (active; exactly one row so far) | one line per new signup: name and use case |

Both sections are filtered to the last 24 hours and **render nothing when empty**, so a
quiet day produces exactly the old calendar + price message.

**The digest leads with aggregates, not with rows.** An earlier version printed a line per
visitor starting with the raw IP; it was unreadable at any real traffic level — an IP is the
least meaningful thing on the line. Visitors are now described by city, only those who did
more than bounce (>1 view, or any click) are named, and the per-visitor detail lives in the
sheet. Click labels are rendered without their `→ href` suffix, which is kept in the sheet.

**Your own traffic is excluded.** `SELF_IPS` at the top of `Format Message` holds your public
IPs; matching rows are counted separately (`(you: N events, not counted)`) instead of ranking
as the site's most engaged visitor every day. Loopback and private ranges never reach the sheet
at all — the website's `/api/track` drops them, so local dev browsing is not telemetry.

⚠️ **`SELF_IPS` is empty in this committed file and populated only on the live instance.** A home
IP is personal data and this repo is public, so it is placeheld here exactly like the sheet IDs
and chat IDs. The mirror script refuses to write a workflow containing an IPv4 literal. Residential
addresses also rotate: if your own visits start appearing as a visitor again, find the address that
looks like you in the `Visits` sheet and add it in the n8n UI — not here.

Notes for anyone editing `Format Message`:

- It reads every upstream **by node name** (`$('Check Prices')`, `$('Get Visits')`, …),
  never `$input`. That is what lets nodes be inserted into the chain without breaking it.
- The Telegram node uses `parse_mode: HTML` and visitors control link labels, so every
  interpolated value is HTML-escaped. Dropping an `esc()` lets one `<` silently kill the
  whole message.
- Telegram rejects messages over 4096 characters. The tail cap cuts on a line boundary
  so a truncation can never split an HTML entity.
- Visitors are grouped by IP at read time — the sheet's grain is one row per event.
