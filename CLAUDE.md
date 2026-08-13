# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## SECURITY - Public Repository

This repository is **PUBLIC**. Never commit:
- Telegram chat IDs or bot tokens
- n8n credential IDs (the `"id"` field inside `"credentials"` blocks)
- Google Sheet document IDs
- API keys, JWT tokens, or passwords
- The n8n instance URL

Use placeholder values (e.g., `CREDENTIAL_ID_TELEGRAM`, `YOUR_CHAT_ID_1`) in all committed files.
Actual values belong in `.env` files (already gitignored) or in the n8n instance directly.

## Home Lab Context

This repository supports a **home lab automation setup**. Key infrastructure:

- **n8n instance**: Hosted on Railway at `YOUR_N8N_INSTANCE.up.railway.app`
- **Claude's role**: Supervisor - monitors executions, debugs failures, retries workflows
- **API credentials**: Stored in `.claude/n8n-api.env`


### n8n Access Methods

Two ways to interact with n8n (see `.claude/skills/n8n-executions/skill.md` for details):

| Task | Use |
|------|-----|
| Search/view/execute workflows | **MCP tools** (built-in auth) |
| Fetch execution logs, debug, retry | **REST API** (requires API key) |

**Skill**: `/n8n-executions` - Fetch recent execution logs

## User tiers — who a feature is for

Borrowed in **shape** from PromptPotter's `docs/operations/access-model.md`, and deliberately
not in **kind**. That model names security boundaries enforced by code, each a different kind of
boundary, and its whole point is that conflating them makes the model illegible. So state this
one's kind plainly: **this is a capability and audience model.** It decides what the lab
*offers* a reader, never what it *permits*. There is no authorization boundary here — one
operator, one n8n instance, one set of credentials. **A tier is not a control. Never present it
as one.**

| Tier | Profile | Acts on | On a defect, they can |
|------|---------|---------|----------------------|
| **T3 — maintainer** | `codes: true` | workflow JSON, republish, the n8n API key | fix it |
| **T2 — operator** | `codes: false`, `configures: true` | Config nodes, sheets, credentials | report it, or change a setting |
| **T1 — recipient** | neither | the Telegram surface | read it, and tap what is offered |

**Current profile: T3 (`codes: true`)** — the only occupant. Every rule below is therefore
unexercised, and worth writing anyway: this repo is public, and T2 is who imports it.

Three rules, each with the consequence that earns it:

1. **A tier gates the ACTION, never the INFORMATION.** T1 still sees that something is broken —
   they get a different button, not a shorter briefing. Hiding the fact is how a lab becomes
   untrustworthy to exactly the people who cannot fix it themselves.
2. **Most of the lab is tierless and should stay that way.** The converter, the invoice OCR, the
   calendar digest serve everyone identically. Naming a tier is the exception and owes a reason
   in the project's own docs, or the annotation spreads until it means nothing.
3. **Unset fails to the lowest tier.** No profile → T1 → information, no actions. That is the
   honest offer while the lab does not yet know who is reading.

**One definition per feature.** Anything that varies by tier says so in exactly one place — a
Config-node value in a controlled vocabulary, the way `payment_method` (16, live) and
`upkeep_action_mode` (10, proposed) do. Never a condition scattered across nodes.

**Delegation is attenuation — roadmap, nothing implements it.** An assistant agent acting for a
reader would hold `grant ∩ that reader's tier`, never more: a T1 reader's agent may draft a
GitHub issue, but cannot push a workflow. One level, no re-delegation. Do not let a future
feature claim otherwise without building the clamp first.

Worked example: `projects/n8n/10_error-handler/docs/upkeep-tasks-spec.md` § Who this is for.

## Monitoring & Alerting (active)

A failure-alerting **safety net exists** (in-n8n runner-proof + email alerts, plus an external GitHub-Actions heartbeat) — treat it like SECURITY: preserve it when editing workflows. Details: **`projects/n8n/13_n8n-ops-center/docs/external-heartbeat.md`**.

**It is only partly working. Audited against the live instance 2026-08-12:**

| Finding | State |
|---|---|
| `Prepare & Classify Error` read `$json.error`; the Error Trigger nests it at `$json.execution.error` | **Fixed and deployed 2026-08-12.** Every failure was logged as `llm_schema_error`/retryable with a fabricated message — the whole taxonomy was dead and the resolver retried things retry cannot fix. Now also classifies on `httpCode` first, and an unreadable payload becomes `handler_blind`, never a guess |
| `🚨 Runner-Proof Alert` 400s on workflow names containing `_` (unterminated Markdown entity) | **Fixed and deployed 2026-08-12**, and extended to `CODE RED Alert`, `Send Auto-Retry Alert` and `Format Telegram Alert`, which had the same hole. This turned urgent the moment `error_message` began carrying real error text instead of one fixed, punctuation-free sentence |
| `expense-trend-report` pointed at a **stale 28-char `Billing_Ledger` twin** | **Fixed 2026-08-12** (operator, in the UI). Had 404'd daily since before the retained window — 53 failures on 49 of 56 days, every one reported as `llm_schema_error`. First green run due 13:00 UTC 13 Aug |
| `resolver` read a **stale 25-char `FailedItems` twin** — a different document from the one `007` writes to | **Fixed and deployed 2026-08-12.** Still `active: false`, so switching it on would previously have read a sheet nothing writes to |
| Only `007_error-handler.n8n` itself has no `errorWorkflow` bound | **Open, and correct as far as it goes** — self-binding would loop. But it failed 44× in the retained window and none of it was logged. If that matters, bind it to a second, minimal handler rather than to itself |

Binding is otherwise **closed**: 21 of 22 active workflows now carry an `errorWorkflow`. Worth
keeping that way — **an unbound workflow produces no `FailedItems` row**, so it is invisible to the
error handler, the 8-hour resolver and the UPKEEP briefing section alike. The historical coverage
figure (the handler saw 107 of 285 retained failures) reflects the *old* binding state, not today's.

## Open thread — `/visits` command (read before touching the daily briefing)

The 7 AM briefing's site digest deliberately ends with **"→ full detail in the Visits sheet"**
rather than "→ /visits". That wording is a placeholder for a command that does not exist yet.

**The gap:** the digest only names the 3 most engaged visitors; there is no way to ask for the
rest from Telegram. The intended fix is a `/visits` agent, built the documented way —
`12_steward/CLAUDE.md` § "Adding a New Agent": a subworkflow that reads the `Visits` tab and
returns `{chatId, response}`, an entry in the menu-handler **Config** registry, and the key
added to the Classifier Output Parser `route_type` enum. When it lands, swap that closing line
in `05_daily-briefing` → `Format Message`.

**Also worth knowing while you are in there:** `13_n8n-ops-center/telegram-command-interface.n8n.json`
is **committed but never imported** — `/status`, `/failures`, `/retry` and `/search` do *not*
exist on the live bot, despite what that project's README implies. The only live Telegram
command surface is `menu-handler` (`/help`, the agent registry, free-text AI routing). Either
import the ops-center or stop advertising its commands.

## Fixed — SVG in `03_any-file2json-converter` (2026-08-12, repo + live)

`image/svg+xml` killed the converter 8 times over six weeks: the Switch sent `image/*` to
`conversion` (GraphicsMagick), which has no SVG decode delegate. **Rule 0 now excludes `svg` and
rule 5 accepts it**, so an SVG lands in `Extract Document Text` → `Text-to-Structured` like any
other markup. No new outputs, so no connection moved and the `Return node` shape is unchanged —
`04_inbox-attachment-organizer`, `02_smart-table-fill/smart-folder2table` and
`06_exact-recall-across-collections` all still work against it. A green sticky on the Switch
records why the odd-looking condition is there; do not tidy it out.

**The lesson outlives the bug, and it is the reason this took six weeks to find: a MIME label is a
category, not a capability.** The graceful `unresolved` fallback never fired because
`image/svg+xml` is not an *unknown* type — it is perfectly known, matched `image/*`, and was routed
**confidently** into a decoder that could not read it. When adding a route, ask what the branch can
actually *do*, not what the label says the input *is*.

Commit `0478064`. Full history: `10_error-handler/docs/upkeep-tasks-spec.md` — this bug is what
that mechanism was built to catch, and it is now catchable if it ever regresses.

## Fixed — dead converter workflow ID (2026-08-12)

`GtcLjBMusAUB0h30` 404s on the live instance. It was referenced by **two** committed files, not
one as previously recorded here: `06_exact-recall-across-collections` *and*
`02_smart-table-fill/smart-folder2table`. Both now point at the live converter and no tracked JSON
references the dead id.

Nothing running was ever broken by it — the live `smart-folder2table` already pointed at the right
workflow, so only the committed copy had drifted. The remaining references are in the inactive
`My workflow 8 / 10 / 12` scratch copies.

**Unresolved convention question this exposed.** The repo is inconsistent about subworkflow ids:
`inbox-attachment-organizer` and `gdrive-recursion` commit **real** ids, while `daily-briefing` and
`deal-finder` use `YOUR_*_WORKFLOW_ID` placeholders. Workflow ids are not on the SECURITY list and
are not secrets, so both are defensible — but pick one. Real ids make a committed workflow
importable and verifiable against the instance; placeholders make it portable to someone else's.
These two were fixed to real ids, matching the file that already references this same converter.

**Also live: `anything converter`** — an active, uncalled, full 30-node duplicate of the real
converter. It carries the SVG fix too, but two active copies of one subworkflow is a trap worth
deleting.

## Code Patterns

Collection of n8n automation workflows for document processing and AI-powered data extraction. Projects connect LLMs to real tasks: batch processing spreadsheets, organizing email attachments, extracting structured data from messy text. Runs on free-tier LLM APIs, but optional capabities that cost are also present.

**LLM references in docs**: Never refer to models by provider or name (Groq, Gemini, gpt-oss-120b); describe by capability instead — "LLM", "vision-capable LLM", "TTS model" (not LLM), etc.

### Repository Structure

```
projects/n8n/
├── 00_telegram-invoice-ocr-to-excel/  - Photo → Telegram bot → Google Sheets
├── 01_LLM-bulk-responses/           - Batch process spreadsheet rows with AI
├── 02_smart-table-fill/             - Text in, structured data out
├── 03_any-file2json-converter/      - File to JSON converter (subworkflow)
├── 04_inbox-attachment-organizer/   - Email attachments → AI → Google Drive
|   └── 04_expense-analytics/        - Monthly expense chart to Telegram
├── 05_daily-briefing/               - Morning calendar briefing to Telegram
├── 10_error-handler/                - Global error handler, classification, alerts
├── 11_8-hours-incident-resolver/    - Works thorugh a google sheet
├── 12_steward/                      - Personal assistant: briefing, dispatch, subworkflows
├── 13_n8n-ops-center/               - Workflow monitoring: /status, /failures, /retry
├── 14_db-janitor/                   - Scheduled DB cleanup reporter (stub)
├── 15_site-visits/                  - Website visit telemetry intake (beacon → Visits sheet)
├── 16_commitments-ledger/           - Our own record of what we signed up for; reconciles against 04's Billing_Ledger
└── shared/                          - Cross-project workflows: gdrive-recursion (subworkflow), signup-intake (intake door — ACTIVE, live path is `promptpotter-waitlist`)
```

Projects 02, 03, and 04 have their own `CLAUDE.md` files with detailed architecture documentation.

## n8n Workflows

n8n workflows are JSON-based node configurations. Key practices:

- **Minimize node additions**: When modifying workflows, prefer expression changes in existing nodes over adding new nodes. Use n8n's expression language (ternaries, context variables like `$('NodeName').context['currentRunIndex']`) to add conditional logic without structural changes.
- **Always read `workflows/mainflow.md` first** before looking at workflow JSON files. The JSON is machine-readable but difficult to understand without the documentation context.
- **Edit in n8n UI** for logic changes (visualizes data flow), then export as JSON for version control.
- **Use execution logs and debug mode** to trace data transformations between nodes.
- **Replace triggers with Manual Trigger** when testing to avoid waiting for polling intervals.
- **Republish subworkflows** after changes - parent workflows call the published version, not your draft.
- **Expression-first, node-last**: Prefer n8n expressions and Code node logic over adding new nodes. Each node adds visual complexity and connection overhead. A ternary in an expression is better than an IF node for simple conditions.
- **Sticky note behind Execute Workflow nodes**: n8n's UI can silently clear `workflowInputs` when re-selecting a subworkflow. Always place a small sticky note (color 5, blue) directly behind each Execute Workflow node documenting the parameter values being passed (name: value, one per line). This serves as a quick-restore reference. When editing workflow JSON, verify these notes exist and are up to date.

### Authoring/refactoring workflows as code (`@n8n/workflow-sdk`)

The workflow JSON can be turned into typed TypeScript and back, using the official `@n8n/workflow-sdk` (installed at repo root — run `npm install` once). Reach for this when a hand-edit of raw JSON is error-prone: large structural refactors, bulk renames, or just reading a dense workflow's topology (the generated `.to()/.onTrue()/.onFalse()` chain mirrors the `mainflow.md` diagram).

Two commands (no CLI ships with the SDK; this repo wraps it in `scripts/n8n-sdk.js`):

```bash
npm run wf:to-ts   -- <workflow.json> sdk-scratch/x.workflow.ts   # JSON → TypeScript
npm run wf:from-ts -- sdk-scratch/x.workflow.ts <workflow.json>   # TypeScript → JSON
```

- **The `.ts` is throwaway — n8n UI/JSON stays the source of truth.** Do NOT commit generated `.ts` (`.gitignore` blocks `*.workflow.ts` and `sdk-scratch/`). Edit the TS, build back to JSON, re-import via the normal path, delete the TS. This does not replace the "Edit in n8n UI, export JSON" rule — it's a scratch tool alongside it.
- **Security (primary control = what you feed it)**: codegen copies parameter values, credential *reference IDs*, and chat IDs verbatim — not the actual API keys/tokens (those stay encrypted in the instance). **Run it against the committed placeholder JSON**, which already uses `CREDENTIAL_ID_*` / `YOUR_CHAT_ID_1`, so the generated TS is inherently placeholdered. Do NOT run it against a live `*.local.n8n.json` export (that carries real instance IDs). The `*.workflow.ts` gitignore is a backstop, not the safeguard. See the public-repo rules at the top of this file.
- **No skill** — invoke the `npm run` commands directly. LLM-oriented SDK reference strings ship at `@n8n/workflow-sdk/prompts/sdk-reference` if you need the builder API while editing.
- Full how-to, API notes, and round-trip verification: `projects/n8n/docs/workflow-as-code-sdk.md`.

### Sticky Note Conventions

| Color | Code | Usage |
|-------|------|-------|
| Yellow | (default) | Main documentation stickies (overview, schema reference) |
| Orange | 2 | — |
| Red | 3 | Drag-drop setup: shows what needs updating in Config node after importing |
| Green | 4 | — |
| Blue | 5 | Behind Execute Workflow nodes: documents parameters being passed |
| Violet | 6 | — |
| Black/White | 7 | Subunit labels (e.g., "E-Mail trigger", "attachment processor") |

Blue sticky notes behind Execute Workflow nodes serve as quick-restore reference when n8n UI silently clears `workflowInputs`.

**`.st.json` files**: JSON Schema examples for LLM structured output (project 01).

### Common Troubleshooting

**Subworkflow changes not reflected**: You tested the subworkflow directly but forgot to republish. Fix: Republish the subworkflow. If publish fails with "1 node has issues", go to Executions → pick a successful run → Copy to Editor → Publish.

**LLM structured output errors**: Model failed to return valid JSON. Use a model with strong structured output support or simplify the schema.

### Cross-Project Patterns

**Two-stage AI classification**: Cheap classifier LLM → expensive extractor LLM only for matching documents. Reduces costs.

**LLM confidence scores**: Structured outputs include `confidence` or `class_confidence` fields for observability. Thresholds: 0.9+ auto-process, 0.7-0.9 log for review, <0.7 flag for human verification.

**Google Apps Script integration**: n8n API writes don't trigger Sheets `onEdit`. Use Execution API to call Apps Script functions. Requires same GCP project for OAuth, local authorization first.

**Folder structure convention**: `/{RootFolder}/{Year}/{MM_Month}/{Category}/` with MM_Month format (01_January, 02_February) for sorted display.

**State the grain of every output table**: the grain is what exactly one row represents — "one row per X, keyed by Y". Declare it in the project's docs before writing rows. Source documents are evidence, not rows: several can describe one event, one can describe several. Grain is almost never "one row per input item", so `.first()` and blind `append` both produce the wrong row count while the run reports success. Definition and worked example: `projects/n8n/04_inbox-attachment-organizer/README.md` (FAQ).

**Absence is not a diagnosis**: when a value is missing, the honest output is `unknown` — never a specific, plausible cause. A fallback that guesses converts a silent gap into a confident wrong answer, and confident wrong answers do not get investigated. Two sightings in this repo, both expensive: a MIME label routed SVG into a raster decoder because *a label is a category, not a capability* (see the `03` thread above); and `010-error-handler` defaulted an unreadable error to the sentence *"LLM output did not match required schema"*, whose own classifier then matched that sentence — mislabelling **100% of failures** as an LLM problem for months, and hiding a workflow that had failed daily since before the retained window. The tell is the same both times: a fallback that is more specific than the evidence supporting it. Worked example: `projects/n8n/10_error-handler/CLAUDE.md` § Absence is not a diagnosis.

**One instrument, one lie**: alerting redundancy is not alerting independence. Four mechanisms watched the failure above — the error handler, the 8-hour resolver, the upkeep digest, the external heartbeat — and all four agreed, because all four read the same classifier. Before trusting agreement between monitors, check whether they share an upstream. A field that every consumer reads is worth more verification than any of them.

**Sheets are referenced by id, and ids drift**: two Drive files can carry the same name. This lab has two `Billing_Ledger` and two `FailedItems` documents; a workflow left on the stale twin fails with a `404` that reads like a data problem, and one had done so daily for months. When a Sheets node 404s, compare its document id **length and value** against a workflow known to work rather than trusting the cached name shown in the UI.

**Incident retry mechanism**: For workflows that retry failed executions, ALWAYS use the n8n API retry endpoint (`POST /api/v1/executions/{id}/retry`), NOT Execute Workflow nodes. API retry preserves original trigger data (Gmail messages, webhooks, etc.) while Execute Workflow starts fresh with no context. See `projects/n8n/04_inbox-attachment-organizer/config/8-hour-incident-resolver-docs.md` for rationale


### Key Documentation

- `projects/n8n/troubleshooting.md` - Common issues and fixes
- `projects/n8n/credentials-guide.md` - Setting up API credentials
- `projects/n8n/docs/observability-through-llm-confidence-estimate.md` - LLM confidence scoring pattern
- `.claude/skills/n8n-executions/skill.md` - When to use MCP vs REST API
- `projects/n8n/docs/row-index-pattern.md` - Batch table operations pattern
- `projects/n8n/docs/n8n-retry-api-reference.md` - n8n API retry endpoint behavior
- `projects/n8n/docs/infra-ops.md` - Infrastructure, binary data mode, volume management
- `projects/n8n/docs/workflow-as-code-sdk.md` - Code-first authoring/refactoring via `@n8n/workflow-sdk` (throwaway TS)
