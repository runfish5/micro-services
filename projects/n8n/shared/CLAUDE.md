# CLAUDE.md — `shared/` workflows

Architecture notes for the standalone workflows in `projects/n8n/shared/`. This is the
developer/agent-facing reference (durable design facts); `README.md` is the user-facing
description. Read this before editing the JSON. See the root `CLAUDE.md` for repo-wide conventions
(public-repo placeholder rules, sticky-note colors, expression-first editing).

---

## `signup-intake.n8n.json` — Signup Intake → CRM triage

A generic **intake door** for inbound people (waitlist / signups). Two ways in, one pipeline, a
human-in-the-loop promotion gate into a CRM, plus a branded confirmation email.

### Status — LIVE, and the committed path is not the live one (2026-08-13)

Live as `Signup Intake → CRM triage`, id `G766da6yCLuQS50T`, **active**, error-workflow bound.
It has been active all along.

⚠️ **The live webhook path is `promptpotter-waitlist`; this committed copy says `signup-intake`.**
That drift produced a wrong diagnosis on 2026-08-13: a probe of the committed path answered *"the
requested webhook is not registered"* and was read as "never activated". Both halves of the probe
were wrong — the wrong **path**, and a **GET** against a `POST`-only webhook, which returns that same
message even when the workflow is running. **Never conclude a webhook is dead from that string; read
`active` off the API.**

The drift is deliberate for now: the deployed marketing site still posts to the legacy path until the
parked build ships. Rename the live path *after* that deploy, not before.

Consequences of the corrected reading:

- The site's authoritative call (`N8N_WAITLIST_WEBHOOK_URL` → the legacy path) **always worked**. A
  capture failure would have returned a 502 to the submitter, not a silent drop.
- The site's *second* call, to `/webhook/signup-intake`, has **always 404'd** — that path exists in no
  workflow — and `waitlist.ts` swallowed it by design. It only ever duplicated the first call.
- **Executions prove less than they appear to.** One is retained (2026-05-29, status `waiting`) and
  n8n prunes the rest, so an empty list means an empty *window*, not an empty history. The `Signups`
  sheet's single row is the durable evidence that at most one submission ever landed.

**Door 1's sender is now the PromptPotter app**, not the website: on the first `/auth/me` of a new
account it POSTs `{email, name, use_case, signup_source: 'promptpotter-app'}` here, from
`presentation/admin_bot.py::forward_new_account_to_crm`, gated on `N8N_SIGNUP_WEBHOOK_URL` — which
must carry the **live** path. The app also sends its own Telegram notice on a separate outbound
channel, deliberately: that one fires even when this webhook is unset.

### The confirmation email is DISABLED on the live workflow (2026-08-13)

`Render Email` and `Send Confirmation Email` are both `disabled: true` on the instance. They stay
enabled in this committed template, which is generic and correct for an importer who has a real
confirmation renderer.

Two reasons, and the first answers "why did my test signup never get a mail":

1. `Render Email` pointed at `https://promptpotter.dev/api/waitlist-email` — a **dead host** (`.com`
   is canonical) on a route since renamed. It could never have rendered anything.
2. The endpoint that replaced it sends an **approval** notice ("your account is open"). Repointing
   the URL alone would mail that to every brand-new, unentitled signup.

**Reason 2 dissolved on 2026-08-14 and reason 1 has a live URL now.** Signing up grants access, so
"your account is open" is simply *true* for a brand-new signup — there is no unentitled state left for
it to lie about — and `.local` already points at `https://promptpotter.com/api/account-open-email`.
Re-enabling both nodes is now a one-line change rather than a renderer to write. It is left DISABLED
because turning it on starts mailing real people, which is the operator's call, not a cleanup.

### Every signup joins the CRM — the gate was removed on purpose (2026-08-13)

`Append to Signups` now fans out to **three** branches: `Add to CRM (Entries)`, `Notify (Telegram)`
and `Render Email`. The CRM row is written for everyone, automatically.

This **reverses** the "Signups is the unjudged inbox, Entries is the gated clean list — do not
collapse them" rule stated below, by operator decision: a contact record that exists only after
someone taps a button is a contact record that depends on somebody being at their phone, and an
untapped signup simply never existed. Curation moved *after* the write instead of gating it.

It needed no expression changes. `Add to CRM (Entries)` reads `$json.email / first_name / surname /
source / use_case`, which is exactly `Triage`'s output shape and therefore exactly what
`Append to Signups` emits — the node was already fed a compatible item from `Lookup Signup`.

⚠️ **It DID need a rewire, and the first attempt shipped broken — the lesson generalises.**
`Add to CRM (Entries)` was **shared** by both flows, so its downstream (`Flag Promoted` →
`Mark Promoted` → `Confirm Added`) belonged to the button path. Feeding it from Flow A made a fresh
signup fall through into that tail and die on `Flag Promoted`, which reads
`$('Parse Callback')` — a node only the Telegram callback executes. Execution 6354, `status=error`,
*after* the CRM row and the Telegram alert had already been written: **the visible half succeeded,
so nothing looked wrong from the outside.**

The fix removed work rather than adding a node: the CRM row now exists before any tap, so the tap no
longer needs to write it. `Lookup Signup` goes straight to `Flag Promoted`, and
`Add to CRM (Entries)` is **terminal** — it is Flow A's alone.

**Reusing a node across two flows silently reuses its downstream.** When wiring into an existing
node, look at what it feeds before assuming it is a leaf.

Two consequences to know:

- **`groups` and `last_topic` are no longer hardcoded to the waitlist.** They are `signup` and
  `={{ 'Signup · ' + $json.source }}`, so an app account is not filed as `website-waitlist`.
  `association` still carries the exact source.
- ⚠️ **Dismiss does not yet kick anyone out.** `Mark Dismissed` writes `status='dismissed'` to the
  Signups sheet only; the `Entries` row stays. Deliberately deferred — the buttons are now a triage
  *log*, not a CRM gate. If removing a contact needs to be real, that is a write to `Entries`, not a
  fourth meaning for the existing branch.

The JSON keeps its shape untouched — two doors, one pipeline, a human promotion gate — because that
is the reusable part. No node, connection or expression changed.

### It stopped being a waitlist (2026-08-14)

Signing up at the app now **grants access immediately**, bounded by a per-account lifetime spend
ceiling instead of by the operator's approval. So the vocabulary was renamed where a human reads it:
`Waitlist Webhook` → `Signup Webhook`, `formTitle: Join the waitlist` → `Get free access`. The earlier
note here argued the opposite — that renaming was a purely cosmetic diff not worth mirroring into
`.local` — and it was right while the thing WAS a waitlist. What changed is not the taste, it is the
referent: the name now describes a class of user that no longer exists.

**The waitlist is PARKED, not removed.** Both doors, the promotion buttons and the whole pipeline
stand exactly as they were; only copy moved. Reviving it is re-editing two strings, not rebuilding a
flow.

⚠️ **The live webhook PATH is untouched and must stay that way.** `.local` still reads
`promptpotter-waitlist`; the box's `N8N_SIGNUP_WEBHOOK_URL` carries it, and renaming the path 404s
every signup POST the moment it is imported. The node's *name* is cosmetic, its *path* is a binding.

**`account_count` rides the app's POST** — `Normalize (Web)` picks it off `$json.body`, `Normalize`
carries it through both doors (Door 2 has none, so `0`), and `Notify (Telegram)` renders it as
`*Free tier:* N accounts`. It is deliberately NOT assigned in `Triage`, so it never reaches
`Append to Signups` — that node is `autoMapInputData` and a new key there means a new Sheet column.

Two **sticky notes** were corrected in both copies, and the distinction is worth stating: node names
are cosmetics, stickies are documentation. They pointed at `…/api/waitlist-email` and told the
importer to paste the webhook URL into `N8N_WAITLIST_WEBHOOK_URL` — a route and a variable that no
longer exist anywhere. A parked workflow may keep its old vocabulary; it may not keep instructions
that send a reader somewhere gone.

**Flow C can now be revived as-is** — see the 2026-08-14 note above. The email it calls says "your
account is open", which stopped being a lie the moment signing up became the grant. It stays
`disabled: true` on the instance until the operator decides to start mailing people, not because the
copy is wrong.

### Two committed copies

| File | Purpose | IDs |
|------|---------|-----|
| `signup-intake.n8n.json` | Public, version-controlled | **Placeholders** (`YOUR_*`, `CREDENTIAL_ID_*`) |
| `signup-intake.local.n8n.json` | Gitignored import copy | Real sheet IDs, chat ID, webhook IDs, Telegram credential bound; Google Sheets + Gmail credentials are re-selected in the n8n UI on import |

**Both must be kept structurally identical.** When you change the workflow, apply the same change to
both: edit the placeholder file by hand, then mirror into `.local` while preserving its real
bindings (the safe way is a small script: take the placeholder file's `nodes`/`connections`, then
re-inject `credentials`, `webhookId`, `parameters.chatId`, `parameters.documentId`, `parameters.sendTo`
from the local file by node name — and keep the email nodes verbatim from local).

### Two data stores (separate Google Sheets documents)

| Store | Doc | Tab | Role | Columns |
|-------|-----|-----|------|---------|
| **Signups** | `YOUR_SIGNUPS_SPREADSHEET_ID` | `Sheet1` | Inbox / staging log — *everyone* lands here automatically | `email, first_name, surname, use_case, source, signup_timestamp, known_in_crm, status` |
| **CRM (Entries)** | `YOUR_ENTRIES_SPREADSHEET_ID` | `Entries` | Curated contact list — only written on a human tap | `email, first_name, surname, status, groups, association, last_topic, notes, contact_created_at, contact_updated_at` |

The CRM is **read** on every signup (to flag `known_in_crm`) and, since 2026-08-13, **written on every
signup too** — see § Every signup joins the CRM above, which supersedes the gated-write design this
paragraph used to describe. The two stores still differ in *grain*, and that part holds: Signups is the
append-only arrival log (one row per signup event, with a triage `status`), Entries is the contact list
(one row per person, upserted on email). Do not collapse those.

### Signups `status` lifecycle

`new` (on append) → `promoted` (tapped Add to CRM) **or** `dismissed` (tapped Dismiss). These are the
only states. (An earlier `re-engaged` / "Update CRM" state was prototyped and **deliberately removed**
— see "Removed / do not reintroduce".)

---

### Flow A — fresh signup (two trigger doors → one pipeline)

```
Signup Webhook (POST /webhook/signup-intake)     Hosted Signup Form (n8n-hosted page)
        │  → Respond OK ({ok:true}, async)               │
        ▼                                                 ▼
   Normalize (Web)                                  Normalize (Form)
        └───────────────┬─────────────────────────────────┘
                        ▼
                   Normalize (code) — canonical shape; splits name → first_name/surname; signup_timestamp
                        ▼
                   CRM Lookup (read Entries by email; alwaysOutputData) — empty item if not found
                        ▼
                   Triage (Set) — known_in_crm = $json.email ? 'yes':'no'; status='new'; carries signup fields from $('Normalize')
                        ▼
                   Append to Signups (appendOrUpdate Sheet1, autoMapInputData, match email)
                        ├──────────────► Notify (Telegram)   — operator alert + buttons (Flow B)
                        └──────────────► Compose Confirmation → Send Confirmation Email  (Flow C, parallel)
```

- **Door 1 — Signup Webhook**: for senders that have a site. Its original sender was `promptpotter-web`
  `/api/waitlist`, which POSTed `{ email, name, use_case, signup_source }` and set its own `source`.
  That route now sits in that repo's `internal/parked-waitlist/`, so **no site posts here today** —
  the PromptPotter app does, with an extra `account_count` (see below).
  `responseMode: responseNode` → `Respond OK` returns `{ok:true}` immediately, then the rest runs async.
- **Door 2 — Hosted Signup Form**: a `formTrigger`-hosted public page (no website needed). Form field
  labels (`Email`, `Name`, `Use case`) **must** match the keys read in `Normalize (Form)`.
- **`known_in_crm`** is derived in `Triage` purely from whether `CRM Lookup` returned a row. It is
  stored on the Signups row and drives the Telegram message.

### The compact CRM preview (the one curated feature on the alert)

`Notify (Telegram)` always shows name / email / source / use case / `Already in CRM: YES/no`. **When
`known_in_crm === 'yes'`**, the message text appends a short preview of the existing contact:

```
📇 In CRM as <status> · <groups>
🗒 Last topic: <last_topic>
📅 Since: <contact_created_at trimmed to YYYY-MM-DD>
```

Design constraints (intentional — do not expand):
- Read **directly** from `$('CRM Lookup').first().json` inside the Notify text expression. It is *not*
  routed through `Triage`/`Append`, so the Signups sheet stays clean (8 columns) and `Triage` stays a
  plain Set node.
- Field selection is curated for "interesting at a glance": `status` (+ `groups`), `last_topic`, and
  the added-date. **`notes` is deliberately omitted** because it can be long.
- The whole block is a single gated ternary; a not-in-CRM signup renders none of it. Target size: a
  fresh signup fits ~half a small phone screen, an in-CRM one up to ~one screen — **never more**. If
  you change the field set, keep it short and keep `notes` out (or hard-truncate).

### Flow B — Telegram human-in-the-loop (separate trigger)

```
Telegram Trigger (callback_query)
   ▼
Parse Callback (code) — splits callback_data "action:email" → { action, email, message_id, chat_id, original_text }
   ▼
Action? (switch: addcrm | dismiss)
   ├─ addcrm ─► Lookup Signup (re-read Signups by email) ─► Flag Promoted ─► Mark Promoted (Signups status='promoted') ─► Confirm Added (editMessageText + "✅ ADDED TO CRM")
   └─ dismiss ─► Mark Dismissed (Signups status='dismissed') ─► Confirm Dismissed (editMessageText + "🗑 DISMISSED")
```

- **Buttons carry only `action:email`** (`callback_data: addcrm:{{email}}` / `dismiss:{{email}}`). The
  full signup record is **not** in the callback payload — `Lookup Signup` re-reads it from the Signups
  sheet by email. This is why the email is the matching key everywhere.
- **`Add to CRM (Entries)`** (appendOrUpdate, match `email`, `defineBelow`) writes a new contact as:
  `status='lead'`, `groups='website-waitlist'`, `association=source`, `last_topic='Waitlist signup'`,
  `notes=use_case`, `contact_created_at`/`contact_updated_at=now`. Upsert on email → no duplicates.
- The confirm nodes (`editMessageText`) re-stamp `original_text` with the decision. **They do not clear
  the inline keyboard** — current behavior leaves the buttons in place after a tap (a button-clearing
  variant was prototyped and reverted). If double-tap idempotency ever matters, that's the place.

### Flow C — confirmation email (parallel branch; template owned by the website)

`Append to Signups` fans out to `Render Email` (HTTP Request) → `Send Confirmation Email` (Gmail).
- Runs **in parallel** with the Telegram alert. `Render Email` uses `onError: continueErrorOutput`
  (its error output is intentionally unconnected → on failure nothing downstream runs, the run still
  succeeds) and `Send Confirmation Email` is `onError: continueRegularOutput` — so a render or bounce
  failure never blocks the operator notification.
- **The branded email is NOT in this repo.** Its HTML/copy/design tokens live in **`promptpotter-web`**
  (the website), the single source of truth, alongside the brand images:
  - `promptpotter-web/src/lib/account-open-email.ts` — `renderAccountOpenEmail({firstName, useCase, year})`
    → `{ subject, html, text }`. All the logic (HTML-escaping `use_case`, the "there" greeting fallback,
    subject, plain-text alt, year) lives here. **Renamed from `waitlist-email.ts` on 2026-08-13**, and
    its copy now announces an approved account rather than a place in a queue — see the ⚠️ above.
  - `promptpotter-web/src/pages/api/account-open-email.ts` — thin Astro/Vercel serverless route
    (`prerender = false`, GET + POST) that calls the lib and returns the JSON.
- `Render Email` POSTs `{ first_name, use_case }` (from `Triage`) to that endpoint and gets back
  `{ subject, html, text }`. `Send Confirmation Email` then uses `sendTo = {{ $('Triage').item.json.email }}`,
  `subject = {{ $json.subject }}`, `message = {{ $json.html }}`. **No brand HTML, copy, colors, image URLs,
  or `app.promptpotter.com` references remain in the workflow** — the public template is fully generic.
- **Endpoint URL is a bound placeholder**, exactly like the sheet IDs: committed file =
  `YOUR_CONFIRMATION_EMAIL_ENDPOINT`; `.local` = `https://promptpotter.com/api/account-open-email`.
  The live workflow only works once `promptpotter-web` is deployed with the route — and as of
  2026-08-14 it is **not**: the newest Vercel build predates the rename, so the apex still answers
  the retired `/api/waitlist-email` and 404s the new one. Deploy before enabling the two nodes.
  The `.local` copy previously named `promptpotter.dev/api/waitlist-email` and was wrong twice over
  — the route was renamed and `.com` is the canonical domain — so an import would have 404'd on both
  counts. **Apex, not `www`:** `promptpotter.com` serves the route directly and `www.` 307s to it,
  so naming `www` buys a redirect hop on every send for nothing.
- Requires the **Gmail OAuth** credential bound on import.

**Design facts (now maintained in `promptpotter-web/src/lib/account-open-email.ts`, not here):** mobile-first;
bright warm paper `#F7F0DE` (matched to the hero image family; the site `--paper #F5F1EA` nudged warmer);
cobalt `#090C9B`; ember wordmark header banner; **no dark content card**; structure = wordmark → eyebrow +
heading + thank-you line → "thank you" hero image → two teaser cards whose images **alternate sides**
(`/product` "built like a template, model-agnostic, timeless"; `/docs` "open engine, hosted when you
want it") → optional `use_case` → reply-to-a-human line → footer. Both domains come from
`src/data/instance.ts` (`site_url`, `app_url`) rather than being written into the template — the old
hardcoded "invites open ~**June**" promise is gone, and so is the `.dev` host. Images served from
`promptpotter-web/public/email/`: `wordmark.jpg` (cropped ~70px),
`thankyou.jpg` (heart-sign wizard), `card-solutions.png` (jar), `card-howitworks.png` (wizard). To change
copy/layout/images, edit the website lib + `public/email/` — never this repo.

---

### Node / credential map (for binding on import)

- **Google Sheets OAuth** → `CRM Lookup`, `Append to Signups`, `Lookup Signup`, `Add to CRM (Entries)`,
  `Mark Promoted`, `Mark Dismissed`. Entries-doc nodes: `CRM Lookup`, `Add to CRM (Entries)`. All others
  → Signups doc.
- **Telegram Bot** → `Notify (Telegram)`, `Telegram Trigger`, `Confirm Added`, `Confirm Dismissed`.
  Set `YOUR_CHAT_ID` on `Notify (Telegram)`.
- **Gmail OAuth** → `Send Confirmation Email`.
- After activating, copy the Webhook **Production URL** into the sender's own config, and grab the
  **Form Trigger** URL to share/bookmark. The variable this used to name, `N8N_WAITLIST_WEBHOOK_URL`,
  no longer exists — `promptpotter-web` dropped it from its `astro.config.mjs` env schema when the
  form was parked, so a revival introduces the variable rather than reusing one.

### Removed / do not reintroduce (unless explicitly asked)

A richer in-CRM-handling prototype was built and then reverted by decision. Do **not** re-add these
without the operator asking:
- A `Signup History` lookup node (prior-signup count / sources on the alert).
- A `🔁 Update CRM` button + `updatecrm` switch branch (`Lookup Signup (Update)` → `Update CRM (Entries)`
  → `Mark Re-engaged` → `Confirm Updated`) and the `re-engaged` status.
- Converting `Triage` to a Code node, switching `Append to Signups` to `defineBelow`, or clearing the
  inline keyboard in the confirm nodes.

The kept outcome from that round is **only** the compact CRM preview described above. The decision was:
keep the two-store model and the Add/Dismiss gate simple; surface *context* on the alert, not new
write-paths.
