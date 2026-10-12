# 20. Bot Detector

Bot or human, per website visitor per day. One side records what a visitor did; the other side
judges it; a third column is yours to fill in by hand, so the engine can be scored.

```
Daily at 4 → Get Visits → Build Visitor Features → Predict Bot or Human → Keep Verdict

When Called for Briefing → Get Verdicts → Build Briefing Section
```

- **Build Visitor Features** judges nothing. It turns the last two days of the `visits` table
  ([`15_site-visits`](../15_site-visits/README.md)) into one row per visitor per day.
- **Predict Bot or Human** is the engine and the only node that judges: a list of rules, each
  moving a score from a start of 0.3 and naming itself. From 0.7 a visitor is a `bot`, to 0.3 a
  `human`, between them `unsure`.
- **Keep Verdict** keeps the row in the `verdicts` table, keyed on `id`. A later run updates the
  row and keeps what you wrote in `actual`.
- The morning briefing prints a `BOTS` section: yesterday's counts, the bots and the unsure ones,
  and how many hand-checked rows the engine got right.

## One row of `verdicts`

| Field | Meaning |
|-------|---------|
| `id` | `day|visitor`, the key |
| `day`, `visitor`, `net` | UTC day, a short hash of the address, and its network (`203.0.113.x`) |
| `country`, `city`, `ua`, `agents` | where from, the browser, how many browsers the address showed |
| `flag` | the site's own word on the caller, set where the visit was recorded |
| `events`, `views`, `clicks`, `paths` | counts for the day; `paths` is distinct pages |
| `first_path`, `referrer` | where the visit began and what sent it |
| `span_s`, `fastest_gap_s` | first to last event, and the shortest time between two pages |
| `sign_in` | pressed a sign-in link |
| `predicted`, `score`, `reason` | the engine's answer, and every rule that fired |
| `actual` | yours: `bot` or `human` |

A verdict outlives the visit rows it was built from, so it never holds a full address.

## Another engine

Copy **Predict Bot or Human**, have the copy write `predicted_2`, `score_2` and `reason_2`, and
wire it between the engine and **Keep Verdict**. Both answers then sit beside `actual`.

## Files

| File | Purpose |
|------|---------|
| `workflows/bot-detector.n8n.json` | Public copy, placeholders (`YOUR_*`) |
| `workflows/bot-detector.local.n8n.json` | Gitignored import copy with the real bindings |

Setup steps are on the yellow sticky note in the workflow.
