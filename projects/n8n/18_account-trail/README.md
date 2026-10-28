# 18. Account Trail

Who signed in to an app and what each account did, printed in the morning briefing as the
**APP** section.

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
  "accounts": [{ "who": "ada@example.com", "lines": [
    { "at": "2026-10-12T05:20:17Z", "what": "signed_in", "subject": "google", "campaign": "", "dataset": "", "by": "", "device": "phone" },
    { "at": "2026-10-12T05:22:40Z", "what": "start-run", "subject": "justlogic__bc8c08/cycle_9f1e",
      "campaign": "justlogic__bc8c08", "dataset": "justlogic", "by": "" } ] }],
  "unreadable": [],
  "health": {
    "backend:termnorm": { "state": "held", "since": null, "fix": "start TermNorm on the box" },
    "signin:google": { "state": "broken", "since": "2026-10-28T06:12:00Z",
      "fix": "fix google.client_secret in identity/oidc.json, then restart" } } }
```

`health` is one entry per probe the box runs, named by the box (`backend:…`, `signin:…`).
`state` is `held` or `broken`, `since` when it broke (or `null`), `fix` what to do, in the box's
own words. Nothing here knows a probe by name. A trail without `health` reads as all held.

`at` is UTC. `campaign` and `dataset` are set on a command; `dataset` is blank once its campaign
is deleted. `by` names a delegate who acted in the account's workspace. `device` is `phone`,
`tablet` or `computer`, empty when the box could not tell; it is printed on a sign-in (and on
`new` when the account has none), and a line without it prints as before.

The section prints, for up to eight accounts:

```
🏺 APP · last 24h
  2 active · 2 signed in · 1 new
ada@example.com · new · signed in 12:45 google (phone)
  terms accepted 2026-10-11
  justlogic: resolve origin, start checkin, start run ×2
```

A head line counts accounts with any line, with a sign-in and with a new account. Each account's
heading carries its sign-ins in the briefing's zone; below it, one line per dataset in the order
first touched, the app's own words spaced, a repeat in a row as `×N`. An account that acted with
no sign-in in the window says `no sign-in, session still open`. In the briefing the section is
`🧪 App`, a member of the PromptPotter cluster.

**A run that stopped before it finished is an alert**: a `run_stopped` line (the box sends one
only for an abnormal stop, `subject` = `<campaign>/<cycle>: <stop reason>`) prints
`ada's run stopped: <reason> (<dataset>)`, for every account, not only the eight shown.

**Refused requests are grouped**, never printed one per line: a `request_refused` line's
`subject` reads `<METHOD> <path> -> <status> <code> [<request id>]: <message>`, and an
account's refusals print as one item per status class, `500 on /api/v1/machine-status ×18,
/api/v1/auth/quota-status ×6 (14:44–16:20)`; the request id is never shown. **A 5xx is an
alert**, since it is the app's fault and not the user's: `App: 24 requests of ada failed on a
server error`, the grouped line, then what to do; the account's own lines say
`24 requests failed on a server error (see attention)`. A 4xx stays under the account as
`refused 403 on …`. Free text from the box (subjects, reasons) is clipped to 80 characters and
a dataset line to 240, so one long line cannot push the briefing past its limit.

**A broken probe is an alert**: each `health` entry with `state: "broken"` prints
`<probe> broken since <HH:MM, DD.MM> — <fix>` (without `since …` when it is `null`), e.g.
`signin:google broken since 07:12, 28.10 — fix google.client_secret in identity/oidc.json, then
restart`. `held`, an empty `health` or none at all prints nothing.

**Watch the Box** (every 15 minutes) covers only what the box cannot report itself: the sends
stopping, and the app's public health URL failing. One Telegram line when either changes, never
a repeat. A probe's change is not sent from here: the box records it on its ledger and its admin
bot Telegrams it once, so this workflow only lists what is still broken, in the briefing.

**Unreadable accounts are an alert** (top of the briefing): `App: activity of N accounts
unreadable`, then who, then why. Each `unreadable` entry should be an object
`{ "workspace": "…", "email": "ada@example.com", "reason": "old campaign files after the deploy", "self": false }`:
the account prints by its email's name (`self: true` prints `you`) and `reason` is the why line.
A bare workspace-id string is still accepted and prints the id, the only name it carries.

## Files

| File | Purpose |
|------|---------|
| `workflows/account-trail.n8n.json` | Public copy, placeholders (`YOUR_*`, `CREDENTIAL_ID_*`) |
| `workflows/account-trail.local.n8n.json` | Gitignored import copy with the real bindings |

Setup steps are on the yellow sticky note in the workflow.
