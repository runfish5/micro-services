# Shared n8n Workflows

Workflows that aren't tied to a single numbered project — reusable subworkflows
called by several projects, plus standalone utilities that live here on their own.

## gdrive-recursion.json

Resolves folder paths to Google Drive IDs. n8n requires IDs, not paths.

**Features:**
- Self-recursive folder creation
- Caches results in PathToIDLookup sheet
- Batch or query mode

**Called by:**
- `04_inbox-attachment-organizer`

## signup-intake.n8n.json

> **Live, and now fed by the app rather than the website.** ⚠️ Its **live webhook path is
> `promptpotter-waitlist`**, not the `signup-intake` this committed copy declares — check
> [`CLAUDE.md`](CLAUDE.md) before probing it, because the obvious probe reports a false "not
> registered". The marketing site's waitlist form is parked (signing in *is* signing up); **Door 1's
> sender is now the PromptPotter app**, which POSTs every new account here on first `/auth/me`.
> **Every signup now gets a CRM row automatically** — the old "tap to add" gate is gone. The
> confirmation-email branch is **disabled on the instance**; that, and the auto-CRM change, are
> explained in [`CLAUDE.md`](CLAUDE.md).

Generic signup / waitlist **intake door**. Two ways in (a webhook for senders
that have a site, and an n8n-hosted form for those that don't) → checks the CRM
(`Entries`) to see if the person is already known → logs them to a separate
`Signups` sheet (`Sheet1` tab) → Telegram notification with one-tap **Add to CRM**
/ **Dismiss**. After you tap, the message keeps the signup details, stamps your
decision, and the buttons are removed.

**Already-in-CRM preview.** When the signer is already in `Entries`, the Telegram
message appends a compact preview of their existing record — `status` (with
`groups`), `last_topic`, and the date they were added — so you have context at a
glance without scrolling. It's deliberately short (a few lines) and skips long
fields like `notes`; a fresh signup stays within half-to-one small phone screen.

**Confirmation email.** Every signup also receives a branded confirmation email
(*Render Email* → *Send Confirmation Email*, Gmail), on a **parallel branch** to
the Telegram alert and fail-isolated so a render/bounce issue never blocks the
operator notification. The branded HTML is **not** in this repo — it's a brand
asset rendered by the website: *Render Email* (HTTP Request) POSTs `first_name` +
`use_case` to a confirmation-email endpoint and gets back `{ subject, html, text }`,
which Gmail sends to the signup's address. This keeps the intake door generic; the
email's design, copy and images all live in `promptpotter-web` (single source of
truth — `src/lib/account-open-email.ts` + `src/pages/api/account-open-email.ts`).
Set *Render Email*'s URL (`YOUR_CONFIRMATION_EMAIL_ENDPOINT`) and bind the
**Gmail OAuth** credential on import.

⚠️ That endpoint was renamed from `waitlist-email` and now sends an **approval**
notice — "your account is open" — so re-enabling this branch as-is would tell a
brand-new, not-yet-approved signup that they are in. See `CLAUDE.md` § Flow C.

**Import note:** the committed JSON ships with placeholders. A gitignored
`signup-intake.local.n8n.json` sits alongside it with the real sheet IDs, chat ID
and bot credential already bound (and the live webhook path) — import that one to
skip the re-typing; bind the Google Sheets credential once after import.

**Sender:** the PromptPotter app, on the first `/auth/me` of a new account
(`N8N_SIGNUP_WEBHOOK_URL`). The old sender, `promptpotter-web` `/api/waitlist`,
now sits in that repo's `internal/parked-waitlist/`.
