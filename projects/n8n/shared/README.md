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

Generic signup / waitlist **intake door**. Two ways in (a webhook for senders
that have a site, and an n8n-hosted form for those that don't) → checks the CRM
(`Entries`) to see if the person is already known → logs them to a separate
`Signups` sheet (`Sheet1` tab) → Telegram notification with one-tap **Add to CRM**
/ **Dismiss**. After you tap, the message keeps the signup details, stamps your
decision, and the buttons are removed.

**Import note:** the committed JSON ships with placeholders. A gitignored
`signup-intake.local.n8n.json` sits alongside it with the real sheet IDs, chat ID
and bot credential already bound (and the live webhook path) — import that one to
skip the re-typing; bind the Google Sheets credential once after import.

**Sender:** `promptpotter-web` `/api/waitlist` posts here. It also fires a future
`signup-intake` path for an eventual rename cutover — see that repo.
