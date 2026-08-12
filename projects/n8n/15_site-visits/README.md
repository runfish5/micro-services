# 15 - Site Visits

Intake door for website visit telemetry. The website beacon reports one event per
pageview and per click; this workflow appends each one to a `Visits` sheet that the
morning briefing digests.

## What It Does

```
Visit Webhook (POST /webhook/visit-log)
   ▼
Respond OK (204, responseNode — the site is never held open)
   ▼
Append to Visits (Google Sheets, append, autoMapInputData, cellFormat RAW)
```

**Grain:** one row per tracked event, keyed by `(ts, ip, event, path, target)`. A
pageview is one row; each click is its own row. It is *not* one row per visitor —
grouping by IP happens at read time, in the briefing.

## The store

A `Visits` tab in the **same spreadsheet as `Signups`** (the site's inbox document).
Columns, in order:

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

`cellFormat` is **RAW** on the append node. That is deliberate and load-bearing: a
visitor can put anything in a link label, and under the default `USER_ENTERED` a
`target` of `=1+1` would be stored as a live formula. RAW makes every value text.

## Sender

The website's `/api/track` endpoint. The client beacon never talks to n8n directly —
the browser only knows about the site's own origin, so the webhook URL stays private
and the IP, geo and user-agent are stamped server-side where they cannot be spoofed
by the payload.

## Reader

The `daily briefing` workflow reads this tab at 7 AM, groups the last 24 hours by IP,
and renders a per-visitor digest into the Telegram message.

## Why the append is a raw HTTP call, not the Google Sheets node

**This is the load-bearing detail of the whole project. Do not "simplify" it back to the
Sheets node.**

Concurrent appends to a spreadsheet are only safe if Google is told to *insert* rows rather
than compute a free slot. That is the `insertDataOption=INSERT_ROWS` parameter on
`spreadsheets.values.append`. Google then serialises the inserts server-side and every writer
gets its own row.

**The n8n Google Sheets node never sends that parameter.** Its default path reads the sheet to
find the first empty row and then writes there, so two overlapping visits both target the same
row and one is silently overwritten — the API reports success for both. Its `useAppend` option
gets closer (it calls `values.append`) but still leaves `insertDataOption` at Google's default
of `OVERWRITE`, so it only narrows the window instead of closing it.

So `Append to Visits` is an **HTTP Request node** calling the API directly with the same
`googleSheetsOAuth2Api` credential:

```
POST https://sheets.googleapis.com/v4/spreadsheets/{id}/values/Visits:append
     ?valueInputOption=RAW&insertDataOption=INSERT_ROWS
body: { "values": [[ ts, ip, country, city, event, path, target, referrer, ua ]] }
```

Measured on this exact setup, firing truly parallel visits at the live webhook:

| Write path | Result |
|------------|--------|
| Sheets node, default | **2 of 8 landed** — 6 silently lost |
| Sheets node, `useAppend: true` | 7 of 8 landed — 1 silently lost |
| HTTP + `insertDataOption=INSERT_ROWS` | **16 of 16, 12 of 12, 10 of 10 — zero lost** |

`valueInputOption=RAW` is the second half of the contract: a visitor controls the link label, and
under `USER_ENTERED` a `target` of `=1+1` would be stored as a live formula.

Because the race is prevented rather than detected, this workflow needs **no lock, no retry, no
read-back verification, and no database**. An earlier revision carried a
`Verify Row Landed → Row Present? → Stop and Error` chain to catch losses; it was deleted once
`INSERT_ROWS` made losses impossible. Four nodes total, and one of them is a sticky note.

## Executions are not saved

Workflow settings set **Save successful production executions → none**. One execution
per pageview would otherwise bury the execution list and the ops-center's failure view
within a day. Failed executions are still saved, so the alerting safety net is intact.

## Retention — `visits-prune.n8n.json`

A second workflow in this project deletes `Visits` rows older than **90 days**, daily at 03:00.

```
Daily 03:00 → Read Timestamps → Anything To Prune? → Delete Old Rows
```

This is not housekeeping. The website's privacy policy *states* a 90-day window and the rows
hold raw IP addresses, so without this workflow that published claim is simply false. Treat it
like the alerting safety net: if you disable it, fix the policy the same day.

- **No Code node.** The row arithmetic lives in the delete node's body expression, so a
  task-runner outage cannot silently stop retention from being enforced.
- Rows are deleted **bottom-up** so earlier indices stay valid mid-batch.
- A row whose timestamp will not parse is **left alone** (`NaN` comparisons are false) rather
  than guessed at — a malformed row is a bug to look at, not data to delete.
- The `Anything To Prune?` gate keeps quiet days from firing an empty `batchUpdate`.

Verified by injecting a row dated 100 days back, running the workflow, and confirming exactly
that row was removed while the day's rows survived.

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
`*.local.n8n.json` alongside carrying the real spreadsheet ID, sheet gid and Sheets
credential — import those to skip the re-typing. After activating `visit-log`, copy its
webhook **Production URL** into the website's `N8N_VISITS_WEBHOOK_URL` environment variable,
then redeploy the site: Vercel only picks up an env var on the next deployment.

The `Visits` tab and its header row must exist before the first append — nothing creates
them. The header row is the column contract:

```
ts | ip | country | city | event | path | target | referrer | ua
```
