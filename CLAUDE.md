# CLAUDE.md

Guidance for Claude Code in this repository. **Keep this file short:** rules and pointers only.
No incident stories: state the rule and the current state; history lives in git, detail in the
project's own `CLAUDE.md` and docs.

## SECURITY - Public Repository

This repository is **PUBLIC**. Never commit:
- Telegram chat IDs or bot tokens
- n8n credential IDs (the `"id"` field inside `"credentials"` blocks)
- Google Sheet document IDs
- API keys, JWT tokens, or passwords
- The n8n instance URL

Use placeholder values (e.g., `CREDENTIAL_ID_TELEGRAM`, `YOUR_CHAT_ID_1`) in all committed files.
Actual values belong in `.env` files (already gitignored) or in the n8n instance directly.

## Git — don't commit or push by default

**Never `git commit` or `git push` unless the operator says so. A commit ask is not a push ask.**

- "Go ahead", "set it up" or "looks good" is neither a commit ask nor a push ask.
- Asked to commit: commit exactly what was named. List anything unfinished and leave it out
  unless told otherwise.
- When something only takes effect after a push (Railway builds from GitHub, the heartbeat Action
  runs the committed script), say so and stop. Do not push to make it work.
- Never chain a push onto a commit.

## Home Lab Context

This repository supports a **home lab automation setup**.

- **n8n instance**: hosted on Railway at `YOUR_N8N_INSTANCE.up.railway.app`
- **Claude's role**: supervisor. Monitors executions, debugs failures, retries workflows
- **API credentials**: `.claude/n8n-api.env`

| Task | Use |
|------|-----|
| Search/view/execute workflows | **MCP tools** (built-in auth) |
| Fetch execution logs, debug, retry | **REST API** (requires API key), skill `/n8n-executions` |

Collection of n8n workflows for document processing and AI-powered data extraction. Runs on
free-tier LLM APIs; some optional capabilities cost money.

## Rules that apply everywhere

- **LLM references in docs**: never name a model or provider. Describe by capability: "LLM",
  "vision-capable LLM", "TTS model".
- **User tiers are an audience model, not a control.** T3 maintainer (fixes), T2 operator
  (configures), T1 recipient (reads Telegram). A tier gates the action, never the information;
  most of the lab is tierless; unset means T1. Details: `projects/n8n/docs/user-tiers.md`.
- **Alerting is a safety net: preserve it.** Every workflow keeps its `errorWorkflow` binding
  (an unbound workflow is invisible to the error handler). Only the error handler itself is
  unbound, on purpose. Details: `projects/n8n/10_error-handler/CLAUDE.md`,
  `projects/n8n/13_n8n-ops-center/docs/external-heartbeat.md`.
- **Big jobs must not fill n8n's database** (500 MB volume). Before starting one, read
  `projects/n8n/14_db-janitor/CLAUDE.md`. In short:
  - A batch workflow stores nothing in n8n: `saveDataSuccessExecution: none` **and**
    `saveDataErrorExecution: none`, and it creates no n8n files (send data on in an HTTP request).
  - The guard (`db-guard`, a Railway service next to Postgres) switches off a workflow that stores
    more than 5 MB in 3 minutes or 20 MB in an hour. A legitimate big job needs an allowance:
    `scripts/db-guard.sh allow <workflow id> <MB> <hours>`.
  - The guard lives outside n8n on purpose. Do not rebuild it as a workflow.
- **Workflow IDs in committed files**: not secrets. The repo mixes real IDs and
  `YOUR_*_WORKFLOW_ID` placeholders; follow the file you are editing.

## Repository Structure

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
├── 11_8-hours-incident-resolver/    - Works through a Google Sheet of failed items
├── 12_steward/                      - Personal assistant: briefing, dispatch, subworkflows
├── 13_n8n-ops-center/               - Workflow monitoring (committed, not imported), heartbeat docs
├── 14_db-janitor/                   - DB growth guard: stops workflows that fill n8n's own database
├── 15_site-visits/                  - Website visit telemetry intake (beacon → Visits sheet)
├── 16_commitments-ledger/           - Our own record of what we signed up for; reconciles against 04's Billing_Ledger
└── shared/                          - Cross-project workflows: gdrive-recursion, signup-intake
```

Most projects have their own `CLAUDE.md`. Read it before working in that project.

## n8n Workflows

- **Read the project's `mainflow.md` first**, then the JSON.
- **Minimize node additions; expression-first, node-last.** A ternary in an expression beats an
  IF node. Use context variables like `$('NodeName').context['currentRunIndex']`.
- **Edit logic in the n8n UI**, then export JSON for version control.
- **Republish subworkflows** after changes: parents call the published version, not the draft.
  If publish fails with "1 node has issues": Executions → a successful run → Copy to Editor → Publish.
- **Replace triggers with a Manual Trigger** when testing.
- **Blue sticky behind every Execute Workflow node** listing the inputs passed (name: value, one
  per line). n8n's UI can silently clear `workflowInputs`; the sticky is the restore reference.
- **Sticky notes and node names**: read `projects/n8n/docs/template-sticky-guidelines.md` before
  creating or annotating a workflow.

| Sticky colour | Code | Usage |
|-------|------|-------|
| Yellow | (default) | the one main overview sticky |
| Red | 3 | what to update after import, over one node |
| Blue | 5 | inputs behind an Execute Workflow node |
| White | 7 | section labels over several nodes |

- **Workflow as code** (`@n8n/workflow-sdk`): `npm run wf:to-ts` / `wf:from-ts` for large
  refactors. The `.ts` is throwaway and never committed; run it only against the committed
  placeholder JSON. How-to: `projects/n8n/docs/workflow-as-code-sdk.md`.

## Cross-Project Patterns

- **Two-stage AI classification**: cheap classifier → expensive extractor only for matches.
- **LLM confidence scores**: 0.9+ auto-process, 0.7–0.9 log for review, below 0.7 flag for a human.
- **Google Apps Script**: n8n API writes don't trigger Sheets `onEdit`; call Apps Script through
  the Execution API (same GCP project, authorize locally first).
- **Folder structure**: `/{RootFolder}/{Year}/{MM_Month}/{Category}/` (`01_January`, `02_February`).
- **State the grain of every output table**: "one row per X, keyed by Y", declared before writing
  rows. Example: `projects/n8n/04_inbox-attachment-organizer/README.md` (FAQ).
- **Absence is not a diagnosis**: a missing value is `unknown`, never a plausible guess. A fallback
  must not be more specific than its evidence. Example: `projects/n8n/10_error-handler/CLAUDE.md`.
- **A MIME label is a category, not a capability**: when adding a route, ask what the branch can
  do, not what the label says the input is.
- **One instrument, one lie**: monitors that share an upstream are not independent. Check for a
  shared source before trusting their agreement.
- **Sheets are referenced by ID, and IDs drift**: when a Sheets node 404s, compare the document
  ID with a workflow known to work; the cached name in the UI proves nothing.
- **Retrying a failed run**: always the API retry endpoint (`POST /api/v1/executions/{id}/retry`),
  never an Execute Workflow node. Only the API retry keeps the original trigger data.

## Key Documentation

- `projects/n8n/troubleshooting.md` - Common issues and fixes
- `projects/n8n/credentials-guide.md` - Setting up API credentials
- `projects/n8n/docs/observability-through-llm-confidence-estimate.md` - LLM confidence scoring
- `.claude/skills/n8n-executions/skill.md` - When to use MCP vs REST API
- `projects/n8n/docs/n8n-retry-api-reference.md` - n8n API retry endpoint behavior
- `projects/n8n/docs/infra-ops.md` - Infrastructure, binary data mode, volume management
- `projects/n8n/14_db-janitor/docs/runbook.md` - DB growth guard: alerts, allowances, disk-full recovery
- `projects/n8n/docs/workflow-as-code-sdk.md` - Code-first authoring via `@n8n/workflow-sdk`
- `projects/n8n/docs/template-sticky-guidelines.md` - Sticky notes and node names
