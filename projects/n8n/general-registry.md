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
| `lRCrJIj1AEsuNxts` | inbox-attachment-organizer | `04_inbox-attachment-organizer/workflows/inbox-attachment-organizer.json` |
| - | expense-trend-report | `04_inbox-attachment-organizer/workflows/subworkflows/expense-trend-report.json` |
| - | daily-briefing | `05_daily-briefing/workflows/daily-briefing.json` (simplified steward; the full one is `12_steward`) |
| - | exact-recall-across-collections | `06_exact-recall-across-collections/workflows/exact-recall-across-collections.json` |
| - | menu-handler | `12_steward/workflows/menu-handler.json` (config-driven routing + conversation memory) |
| - | telegram-command-interface | `13_n8n-ops-center/telegram-command-interface.n8n.json` |
| - | db-janitor | `14_db-janitor/workflows/db-janitor.json` |
| - | signup-intake | `shared/signup-intake.n8n.json` (`signup-intake.local.n8n.json` is the local variant) |

### Subworkflows

| Workflow ID | Name | File Path | Called By |
|-------------|------|-----------|-----------|
| `GtcLjBMusAUB0h30` | any-file2json-converter | `03_any-file2json-converter/workflows/any-file2json-converter.json` | inbox-attachment-organizer, smart-folder2table, exact-recall-across-collections |
| `vFnk7s9sqVnrt4hC` | gdrive-recursion | `shared/gdrive-recursion.json` | inbox-attachment-organizer, self (recursive) |
| - | gmail-processor-datesize | `04_inbox-attachment-organizer/workflows/subworkflows/gmail-processor-datesize.json` | Manual batch runs |
| `ZPJYCwXcmisoSkuz` | record-search | `02_smart-table-fill/workflows/subworkflows/record-search.json` | inbox-attachment-organizer |
| `AP7QbVnt424dz8dD` | contact-memory-update | `02_smart-table-fill/workflows/subworkflows/contact-memory-update.json` | smart-table-fill |
| - | learning-notes | `12_steward/workflows/subworkflows/learning-notes.json` | menu-handler (via Config registry) |
| - | deal-finder | `12_steward/workflows/subworkflows/deal-finder.json` | menu-handler (via Config registry) |
| - | price-checker | `12_steward/workflows/subworkflows/price-checker.json` | deal-finder, daily-briefing |

### Support Workflows

| Workflow ID | Name | File Path |
|-------------|------|-----------|
| - | error-handler | `10_error-handler/workflows/010-error-handler.json` |
| - | 8-hour-incident-resolver | `11_8-hours-incident-resolver/workflows/011-8-hour-incident-resolver.json` |

## Notes

- Workflow IDs marked `-` are standalone (not called by Execute Workflow nodes)
- `cachedResultName` in Execute Workflow nodes should match the "Name" column
- When renaming workflows in n8n, update both the JSON file and this registry
- **Steward Config registry**: menu-handler uses a Config code node as agent registry. Subworkflows are dispatched via dynamic Execute Workflow (workflowId from registry). To add a new agent to the steward, update the Config node + Classifier Output Parser enum — see `12_steward/workflows/mainflow.md` for details
