# 18. Account Trail

What each account did in an app, printed in the morning briefing as the **APP** section.

```
When Trail Is Sent (POST /webhook/account-trail, header auth) → Keep Latest Trail

When Called for Briefing → Build Briefing Section
```

**The app tells; this workflow never asks.** The app sits behind an outbound-only tunnel and
has no door for a read across its accounts, so it POSTs the whole last day every half hour and
this workflow keeps the newest in its static data. Nothing is written to a sheet.

- Each send replaces the last, so a missed one costs freshness only.
- A trail older than two hours prints a `Stale` line with its time: an offline app must not read
  as a quiet day.
- The door listens only to a sender that holds the shared secret, sent as the `X-Trail-Secret`
  header. Anyone else gets `403`, and a body that is not a trail gets `500`.
- Successful executions are not saved: they carry addresses.

## Body

```json
{ "as_of": "2026-10-12T05:30:00Z",
  "accounts": [{ "who": "ada@example.com", "rows": ["2026-10-12 05:20:17 signed_in google"] }],
  "unreadable": [] }
```

A row is `YYYY-MM-DD HH:MM:SS what subject` in UTC. The section prints the time in the briefing's
zone, the newest six rows per account, and eight accounts.

## Files

| File | Purpose |
|------|---------|
| `workflows/account-trail.n8n.json` | Public copy, placeholders (`YOUR_*`, `CREDENTIAL_ID_*`) |
| `workflows/account-trail.local.n8n.json` | Gitignored import copy with the real bindings |

Setup steps are on the yellow sticky note in the workflow.
