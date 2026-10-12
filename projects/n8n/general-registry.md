# Home Lab General Registry

Canonical registry of infrastructure assets and workflows. Update when adding new resources.

## Infrastructure Assets

### Local Machine (UI/Development)

| Property | Value |
|----------|-------|
| Purpose | Claude Code host, development environment |
| OS | Windows |
| Role | Supervisor - monitors executions, debugs failures, retries workflows |

### n8n Server

| Property | Value |
|----------|-------|
| Host | Railway |
| URL | `YOUR_N8N_INSTANCE.up.railway.app` |
| Role | Workflow execution engine |
| API Credentials | `.claude/n8n-api.env` |

### Cloud APIs

| Service | Purpose | Auth Method |
|---------|---------|-------------|
| Groq | LLM inference (free tier) | API key |
| Google Gemini | LLM inference, OCR (free tier) | API key |
| Google Workspace | Sheets, Drive | OAuth |
| Telegram | Bot messaging | Bot token |

---

## Workflows

### Main Workflows

| Workflow ID | Name | File Path |
|-------------|------|-----------|
| - | telegram-invoice-ocr-to-excel | `00_telegram-invoice-ocr-to-excel/telegram-invoice-ocr-to-excel.n8n.json` |
| - | LLM-bulk-responses | `01_LLM-bulk-responses/1_LLM-bulk-responses.n8n.json` |
| `Lw53fM7EghZm7Qxy` | smart-table-fill | `02_smart-table-fill/workflows/smart-table-fill.n8n.json` |
| - | smart-folder2table | `02_smart-table-fill/workflows/smart-folder2table.json` (manual or as subworkflow) |
| `OxCveU5jAa3uk_3DhRMra` | inbox-attachment-organizer | `04_inbox-attachment-organizer/workflows/inbox-attachment-organizer.json` |
| - | expense-trend-report | `04_inbox-attachment-organizer/workflows/subworkflows/expense-trend-report.json` |
| - | daily-briefing | `05_daily-briefing/workflows/daily-briefing.json` (simplified steward; the full one is `12_steward`) |
| - | exact-recall-across-collections | `06_exact-recall-across-collections/workflows/exact-recall-across-collections.json` |
| - | menu-handler | `12_steward/workflows/menu-handler.json` (config-driven routing + conversation memory) |
| - | telegram-command-interface | `13_n8n-ops-center/telegram-command-interface.n8n.json` |
| - | ZZ_db-guard-test [sandbox] | `14_db-janitor/workflows/db-guard-sandbox-writer.json` (drill target; unpublished except during a drill) |
| `49JyBpZtRzBZyMmW` | commitments | `16_commitments-ledger/workflows/commitments.json` (one workflow: generate 06:30 + digest + tap) |
| `ykuOczmIegskR6jb` | Site Forms | `17_site-forms/workflows/site-forms.n8n.json` (`.local` variant alongside): **active**; webhook path `reach`, header auth. Sender = the website's `/api/reach` |
| `g7CQZpGssKXuJ8m0` | Account Trail | `18_account-trail/workflows/account-trail.n8n.json` (`.local` variant alongside): **active**; webhook path `account-trail`, header auth. Sender = the PromptPotter app's admin bot, every half hour |
| `E88YP0uFpCZIqykR` | Bot Detector | `20_bot-detector/workflows/bot-detector.n8n.json` (`.local` variant alongside): **active**; daily at 04:00 |
| `G766da6yCLuQS50T` | Signup Intake → CRM triage | `shared/signup-intake.n8n.json` (`.local` variant alongside) — **active**; live webhook path is `promptpotter-waitlist`, NOT the committed `signup-intake`. Sender = the PromptPotter app; auto-writes the CRM row; account email on |

### Subworkflows

| Workflow ID | Name | File Path | Called By |
|-------------|------|-----------|-----------|
| `GtcLjBMusAUB0h30` | any-file2json-converter | `03_any-file2json-converter/workflows/any-file2json-converter.json` | inbox-attachment-organizer, smart-folder2table, exact-recall-across-collections |
| `vFnk7s9sqVnrt4hC` | gdrive-recursion | `shared/gdrive-recursion.json` | inbox-attachment-organizer, self (recursive) |
| `13vNowtGuPAKnfhj` | gmail-backup | `04_inbox-attachment-organizer/workflows/gmail-backup.json` | Manual runs, its own restore form, itself (email backup chunks; must stay published) |
| `6V3qbVqk2Wp81WU0DeVjR` | smart-CRM-fill (= smart-table-fill in CRM mode) | `02_smart-table-fill/workflows/smart-table-fill.n8n.json` | inbox-attachment-organizer |
| `eShHXaF_dgYe0K2lMb8AY` | gmail-processor-datesize | `04_inbox-attachment-organizer/workflows/subworkflows/gmail-processor-datesize.json` | Manual runs (generic: Gmail search → target per email) |
| `ZPJYCwXcmisoSkuz` | record-search | `02_smart-table-fill/workflows/subworkflows/record-search.json` | inbox-attachment-organizer |
| `AP7QbVnt424dz8dD` | contact-memory-update | `02_smart-table-fill/workflows/subworkflows/contact-memory-update.json` | smart-table-fill |
| - | learning-notes | `12_steward/workflows/subworkflows/learning-notes.json` | menu-handler (via Config registry) |
| - | deal-finder | `12_steward/workflows/subworkflows/deal-finder.json` | menu-handler (via Config registry) |
| - | price-checker | `12_steward/workflows/subworkflows/price-checker.json` | deal-finder, daily-briefing |
| `49JyBpZtRzBZyMmW` | commitments | `16_commitments-ledger/workflows/commitments.json` | daily-briefing (Plugins registry) and menu-handler (Config `task`) — **must stay active** or both callers fail |
| `ykuOczmIegskR6jb` | Site Forms (its `When Called for Briefing` trigger) | `17_site-forms/workflows/site-forms.n8n.json` | daily-briefing (Plugins registry, key `reach`): the `SITE INBOX` section. **Must stay active** or the section fails |
| `g7CQZpGssKXuJ8m0` | Account Trail (its `When Called for Briefing` trigger) | `18_account-trail/workflows/account-trail.n8n.json` | daily-briefing (Plugins registry, key `app`): the `APP` section. **Must stay active** or the section fails |
| `E88YP0uFpCZIqykR` | Bot Detector (its `When Called for Briefing` trigger) | `20_bot-detector/workflows/bot-detector.n8n.json` | daily-briefing (Plugins registry, key `bots`): the `BOTS` section. **Must stay active** or the section fails |
| `V6hII7rSZbceuOiv` | Records Store (HTTP) | `19_records-store/workflows/records-store-http.n8n.json` (`.local` variant alongside) | visit-log, visits-prune, daily-briefing, Site Forms, Signup Intake, Bot Detector: every read and write of `visits`, `messages`, `subscribers`, `signups`, `verdicts`. **Must stay active** or all six fail |

### Support Workflows

| Workflow ID | Name | File Path |
|-------------|------|-----------|
| - | error-handler | `10_error-handler/workflows/010-error-handler.json` |
| - | 8-hour-incident-resolver | `11_8-hours-incident-resolver/workflows/011-8-hour-incident-resolver.json` |

## Project dependency order

Projects depend **downward**: a higher number may use a lower one, never the reverse. So far
that holds as `00 < 01 < 02 < 03 < 04 < 05`, and it is what lets the numbering double as a
reading order — a project can be understood knowing only what came before it.

Prefer **one workflow per project**. Split only when a branch needs genuinely different
paste-time configuration (a different spreadsheet, a different credential set). Splitting
branches that share the same knobs just multiplies the setup a reader has to repeat, with
nothing separated in return.

### Announced exceptions

Two edges currently point upward. Both are **configuration, not code** — the lower-numbered
workflow holds a workflow id in a registry node and knows nothing else about the target:

| Edge | Why it is allowed |
|------|-------------------|
| `05_daily-briefing` → `16` | The briefing is a renderer with a `Plugins` registry. It has no knowledge of commitments; swapping the id swaps the plugin. Removing the registry line removes the dependency. |
| `05_daily-briefing` → `17` | The same registry, one more line (`reach`). Site Forms owns the `messages` and `subscribers` tables and renders its own section; the briefing only prints what comes back. |
| `05_daily-briefing` → `18` | The same registry, one more line (`app`). Account Trail keeps what the app last told it and renders its own section. |
| `05_daily-briefing` → `20` | The same registry, one more line (`bots`). Bot Detector owns the `verdicts` table and renders its own section. |
| `15`, `17`, `20`, `05`, `shared/signup-intake` → `19` | One store node per read or write. Which records store that node selects decides where every row lives. |
| `12_steward` → `16` | menu-handler dispatches every agent by id from its `Config` registry. The `task` entry is one more row in a list that already points at 12's own subworkflows. |

The test for a future exception is the same: if the dependency is a **line in a registry**, the
reading order survives, because a reader can skip the target and still understand the workflow.
If it is a node, an expression, or a schema that must be understood to follow the flow, the
ordering is genuinely broken and the projects should be renumbered or merged instead.

`16` → `04` (reading the Billing_Ledger spreadsheet) points downward and needs no exception.

## Notes

- Workflow IDs marked `-` are standalone (not called by Execute Workflow nodes)
- `cachedResultName` in Execute Workflow nodes should match the "Name" column
- When renaming workflows in n8n, update both the JSON file and this registry
- **Briefing plugin registry**: `daily-briefing` has a `Plugins` Code node listing morning
  sections (key, order, workflowId, enabled). `Run Plugin` dispatches dynamically, so adding a
  section is one registry line. Contract: `05_daily-briefing/docs/briefing-plugin-spec.md`
- **Steward Config registry**: menu-handler uses a Config code node as agent registry. Subworkflows are dispatched via dynamic Execute Workflow (workflowId from registry). To add a new agent to the steward, update the Config node + Classifier Output Parser enum — see `12_steward/workflows/mainflow.md` for details
