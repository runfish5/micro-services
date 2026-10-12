# 15 - Site Visits

Intake door for website visit telemetry. The website beacon reports one event per
pageview and per click; this workflow keeps each one as a row of the `visits` table, which the
morning briefing digests.

## What It Does

```
Visit Webhook (POST /webhook/visit-log)
   ▼
Respond OK (204, responseNode — the site is never held open)
   ▼
Keep Visit (records store, keep)
```

**Grain:** one row per tracked event, keyed by `(ts, ip, event, path, target)`. A
pageview is one row; each click is its own row. It is *not* one row per visitor —
grouping by IP happens at read time, in the briefing.

## The store

The `visits` table of a records store ([`19_records-store`](../19_records-store/README.md)): a tab
of a spreadsheet or a file on your own server, by the store **Keep Visit** points at. Fields:

| Column | Source | Notes |
|--------|--------|-------|
| `ts` | server | ISO-8601, stamped by the website endpoint |
| `ip` | server | raw client IP — see Privacy below |
| `country`, `city` | server | coarse geo from the hosting edge headers |
| `event` | client | `pageview` or `click` — allowlisted, nothing else is accepted |
| `path` | client | the page the event happened on |
| `target` | client | for clicks: the link/button label and its href |
| `referrer` | client | pageviews only |
| `ua` | server | browser user-agent |
| `flag` | server | empty, or the site's word on a caller it took for a crawler: `bot-ua`, `stale-browser` |

The Google Sheets store writes every value **RAW**. That is deliberate and load-bearing: a
visitor can put anything in a link label, and under `USER_ENTERED` a `target` of `=1+1` would be
stored as a live formula. Why that store appends over raw HTTP is in its README.

The same store also holds `messages` and `subscribers`, written by
[`17_site-forms`](../17_site-forms/README.md). A visit row has no email and a form row has no IP,
so the two cannot be joined to a person; what links them is the `path` each form row records.

## Sender

The website's `/api/track` endpoint. The client beacon never talks to n8n directly —
the browser only knows about the site's own origin, so the webhook URL stays private
and the IP, geo and user-agent are stamped server-side where they cannot be spoofed
by the payload.

## What never reaches the store

Dropped by the website before a row is written, so every reader of this table sees the same
set rather than each one re-deriving it:

- **Loopback and private addresses** — local development.
- **The owner's own devices** — a browser that once opened the site with `?self=1` reports nothing
  from then on (`?self=0` undoes it). This is the only thing the site ever stores on a device, and
  only on one whose owner typed that parameter. It exists because the briefing's address list
  cannot recognise a phone: mobile carriers hand out a new address per session.

Rows written before 2026-10-11 predate the own-devices rule and carry no flag. Anything computed
over older rows has to filter them itself.

## What is flagged, not dropped

The website names a caller it takes for a crawler in `flag` and keeps the row. The briefing leaves
flagged rows out of its visitor counts; [`20_bot-detector`](../20_bot-detector/README.md) reads
the flag as one more feature.

- `bot-ua` — **anything naming itself a bot**: `bot`, `crawl`, `headless`, `curl` and the like in
  the user-agent.
- `stale-browser` — **browsers years out of date**: Chrome or Firefox below a floor version (130
  when written). The crawlers that do not name themselves wear an old desktop browser: in the
  first two months that was 64 of the 125 addresses that were not the owner, mostly from data
  centres, landing on the legal pages. The floor is a constant in the website's `/api/track`; it
  wants raising now and then, and a stale one only flags fewer.

Rows from 2026-10-11 until the flag shipped hold no such callers at all: they were dropped then.

## Reader

The `daily briefing` workflow reads this table at 7 AM, groups the last 24 hours by IP,
and renders a per-visitor digest into the Telegram message.

## Executions are not saved

Workflow settings set **Save successful production executions → none**. One execution
per pageview would otherwise bury the execution list and the ops-center's failure view
within a day. Failed executions are still saved, so the alerting safety net is intact.

## Retention — `visits-prune.n8n.json`

A second workflow in this project drops `visits` rows older than **90 days**, daily at 03:00.

```
Daily at 3 → Drop Old Visits
```

This is not housekeeping. The website's privacy policy *states* a 90-day window and the rows
hold raw IP addresses, so without this workflow that published claim is simply false. Treat it
like the alerting safety net: if you disable it, fix the policy the same day.

- **Drop Old Visits** hands the store a time. The store counts a row's age from when it was kept.
- With the HTTP store the drop is one request and **no Code node**, so a task-runner outage
  cannot silently stop retention from being enforced.
- A row whose time will not parse is **left alone** rather than guessed at — a malformed row is a
  bug to look at, not data to delete.

## Privacy

This log stores **raw IP addresses** alongside browsing behaviour, which is personal data.
Keeping the address un-truncated was a deliberate call (2026-08-09) — the whole point of
the feature is visitor-level detail — taken knowing it is the choice that carries the most
weight in an EU legitimate-interest assessment.

What holds that position up, and must stay true:

- The website's privacy policy discloses exactly what is collected, names **legitimate
  interest (GDPR Art. 6(1)(f))** as the basis, states the purpose as internal analysis only,
  and offers a route to object or request erasure.
- The **90-day window is enforced**, not just promised — see Retention above.
- Visitors sending **Do Not Track are never recorded**, and the beacon writes nothing to the
  visitor's device, which is what keeps this out of ePrivacy consent territory.
- Loopback and private ranges are dropped at `/api/track`, so dev browsing is not telemetry.

Residual risk worth re-reading before an EU push: the EDPB's guidance on the technical scope
of ePrivacy Art. 5(3) reads "gaining access to terminal equipment" broadly enough that
IP-collecting beacons *could* be argued into needing consent. Unsettled, not settled against.

To stop collecting raw IPs, truncate or hash in the website's `/api/track` route — it is the
single point where the address enters this pipeline, and it is one line.

## Import note

Both workflows ship as committed JSON with placeholders, each with a gitignored
`*.local.n8n.json` alongside carrying the real store workflow id — import those to skip the
re-typing. After activating `visit-log`, copy its
webhook **Production URL** into the website's `N8N_VISITS_WEBHOOK_URL` environment variable,
then redeploy the site: Vercel only picks up an env var on the next deployment.

With the Google Sheets store, the `visits` tab and its header row must exist before the first
row — nothing creates them. The header row is the column contract:

```
at | ts | ip | country | city | event | path | target | referrer | ua | flag
```
