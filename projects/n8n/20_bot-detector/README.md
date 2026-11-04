# 20. Bot Detector

Bot, human or unsure, per website visitor per day. One side records what a visitor did; the
other side judges it.

```
Daily at 4 → Get Visits → Build Visitor Features → Predict Bot or Human → Keep Verdict → Drop Old Verdicts

When Called for Briefing → Get Verdicts → Build Briefing Section
```

- **Build Visitor Features** judges nothing. It turns yesterday's rows of the `visits` table
  ([`15_site-visits`](../15_site-visits/README.md)) into one row per visitor. A visitor the site
  flagged `self` is marked yours, and the engine writes `self` instead of judging it. The flag
  follows the browser, not the address, so a phone on mobile data is caught too: signing into the
  app as its admin leaves a `pp-self` cookie on the site's domain, and `?self=1` on any page marks
  a browser that never signs in (`?self=0` takes it off).
- **Predict Bot or Human** is the engine and the only node that judges: a list of rules, each
  moving a score from a start of 0.3 and naming itself. From 0.7 a visitor is a `bot`, to 0.3 a
  `human`, between them `unsure`.
- **Keep Verdict** keeps the row in the `verdicts` table, once. **Drop Old Verdicts** removes
  those older than 90 days, the window the visits themselves are kept for.
- The morning briefing's `SITE` section is rendered here, off the verdicts, so every number in
  it counts the same visitors. A visitor is one address on one UTC day, and every fact is said
  once: a count or a tally prints only where the visitor lines do not already show it.
  - the head line: the number of visitors. Split into people, unsure and bots, and the sign-in
    presses, only when some visitor is past the cut below;
  - one line per **place and reason**, led by 🙋 person, ❔ unsure or 🤖 bot, five of each, then
    `🙋 +N more people`. `×4` means four addresses. `same network` (the same /24 or /48) and
    `same browser` (the identical user agent) are said only when all four share it. The device
    follows the place, off `ua` by the rule in [`15_site-visits`](../15_site-visits/README.md#live-alerts):
    `Zurich, CH · phone · 2 views · …`, or `1 computer, 1 phone` when the addresses differ; then
    the pages and the source (`via search`; nothing when direct) when all of them share it. The
    view count is left out when it is one per page listed. A bot's line is its place and reason;
  - pages, countries, sources and devices, counted per visitor and leaving bots out, only when a
    person or unsure visitor is past the cut or on a line that leaves out their pages or source;
  - `(you: N events, not counted)` for your own rows.

## One row of `verdicts`

| Field | Meaning |
|-------|---------|
| `id` | `day|visitor` |
| `day`, `visitor`, `net` | UTC day, a short hash of the address, and its network (`203.0.113.x`) |
| `country`, `city`, `ua`, `agents` | where from, the browser, how many browsers the address showed |
| `flag` | the site's own word on the caller, set where the visit was recorded |
| `events`, `views`, `clicks`, `paths` | counts for the day; `paths` is distinct pages |
| `first_path`, `referrer` | where the visit began and what sent it |
| `pages` | the distinct pages viewed, in order (`/ → /benchmarks`) |
| `span_s`, `fastest_gap_s` | first to last event, and the shortest time between two pages |
| `sign_in` | pressed a sign-in link |
| `predicted`, `score`, `reason` | the engine's answer (`bot`, `human`, `unsure`, or `self` for your own rows), and every rule that fired |
| `actual` | optional, yours: `bot` or `human`. The briefing then counts how often the engine agreed |

A verdict never holds a full address, and leaves after 90 days.

## Another engine

Copy **Predict Bot or Human**, have the copy write `predicted_2`, `score_2` and `reason_2`, and
wire it between the engine and **Keep Verdict**. Both answers then sit beside `actual`.

## Files

| File | Purpose |
|------|---------|
| `workflows/bot-detector.n8n.json` | Public copy, placeholders (`YOUR_*`) |
| `workflows/bot-detector.local.n8n.json` | Gitignored import copy with the real bindings |

Setup steps are on the yellow sticky note in the workflow.
