# CLAUDE.md — `shared/` workflows

Architecture notes for the standalone workflows in `projects/n8n/shared/`. This is the
developer/agent-facing reference (durable design facts); `README.md` is the user-facing
description. Read this before editing the JSON. See the root `CLAUDE.md` for repo-wide conventions
(public-repo placeholder rules, sticky-note colors, expression-first editing).

---

## `signup-intake.n8n.json` — Signup Intake → CRM triage

A generic **intake door** for inbound people (waitlist / signups). Two ways in, one pipeline, a
human-in-the-loop promotion gate into a CRM, plus a branded confirmation email.

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

The CRM is **read** on every signup (to flag `known_in_crm`) and **written** only when you tap
**Add to CRM** in Telegram. This two-store split is the core design — Signups is the unjudged inbox,
Entries is the gated clean list. Do not collapse them.

### Signups `status` lifecycle

`new` (on append) → `promoted` (tapped Add to CRM) **or** `dismissed` (tapped Dismiss). These are the
only states. (An earlier `re-engaged` / "Update CRM" state was prototyped and **deliberately removed**
— see "Removed / do not reintroduce".)

---

### Flow A — fresh signup (two trigger doors → one pipeline)

```
Waitlist Webhook (POST /webhook/signup-intake)   Hosted Signup Form (n8n-hosted page)
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

- **Door 1 — Waitlist Webhook**: for senders that have a site (e.g. `promptpotter-web` `/api/waitlist`
  POSTs `{ email, name, use_case, signup_source }` and sets its own `source`). `responseMode: responseNode`
  → `Respond OK` returns `{ok:true}` immediately, then the rest runs async.
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
   ├─ addcrm ─► Lookup Signup (re-read Signups by email) ─► Add to CRM (Entries) ─► Flag Promoted ─► Mark Promoted (Signups status='promoted') ─► Confirm Added (editMessageText + "✅ ADDED TO CRM")
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
  - `promptpotter-web/src/lib/waitlist-email.ts` — `renderWaitlistEmail({firstName, useCase, year})`
    → `{ subject, html, text }`. All the logic (HTML-escaping `use_case`, the "there" greeting fallback,
    subject, plain-text alt, year) lives here.
  - `promptpotter-web/src/pages/api/waitlist-email.ts` — thin Astro/Vercel serverless route
    (`prerender = false`, GET + POST) that calls the lib and returns the JSON.
- `Render Email` POSTs `{ first_name, use_case }` (from `Triage`) to that endpoint and gets back
  `{ subject, html, text }`. `Send Confirmation Email` then uses `sendTo = {{ $('Triage').item.json.email }}`,
  `subject = {{ $json.subject }}`, `message = {{ $json.html }}`. **No brand HTML, copy, colors, image URLs,
  or `app.promptpotter.dev` references remain in the workflow** — the public template is fully generic.
- **Endpoint URL is a bound placeholder**, exactly like the sheet IDs: committed file =
  `YOUR_CONFIRMATION_EMAIL_ENDPOINT`; `.local` = `https://promptpotter.dev/api/waitlist-email`. The live
  workflow only works once `promptpotter-web` is deployed with the route.
- Requires the **Gmail OAuth** credential bound on import.

**Design facts (now maintained in `promptpotter-web/src/lib/waitlist-email.ts`, not here):** mobile-first;
bright warm paper `#F7F0DE` (matched to the hero image family; the site `--paper #F5F1EA` nudged warmer);
cobalt `#090C9B`; ember wordmark header banner; **no dark content card**; structure = wordmark → eyebrow +
heading + thank-you line → "thank you" hero image → two teaser cards whose images **alternate sides**
(`/solutions` "built like a template, model-agnostic, timeless"; `/docs` "open engine, hosted when you
want it") → optional `use_case` → closing line (account at **app.promptpotter.dev** when invites open
~**June**) → footer. Images served from `promptpotter-web/public/email/`: `wordmark.jpg` (cropped ~70px),
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
- After activating, copy the Webhook **Production URL** into the sender's `N8N_WAITLIST_WEBHOOK_URL`,
  and grab the **Form Trigger** URL to share/bookmark.

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
