# 10 - Steward

Personal assistant via Telegram — config-driven command hub with AI routing and subworkflow delegation.

## What It Does

Receives Telegram messages (button taps, slash commands, free text) and routes them:

- **Deterministic**: `/deals`, `/learning`, `/expenses`, `/help` — dispatches to the matching subworkflow
- **AI-classified**: Free text — LLM classifier (with conversation memory) routes to subworkflows or LLM backends (reasoning, web search, research)

The morning briefing (project 05) provides the scheduled entry point; the steward handles everything interactive.

## Commands

| Command | What It Does |
|---------|-------------|
| `/help` | Dynamic command list generated from Config registry |
| `/deals` | Shopping advisor + price tracker (add, remove, track, history, plot...) |
| `/learning` | AI-summarized Notion notes |
| `/expenses` | Monthly expense chart + insights |

Free text is routed by the AI Classifier to the best-fit agent or LLM backend. Conversation memory (Postgres) enables follow-up messages without repeating context.

`/help` is dynamically generated from the Config node's `subCommands` arrays — adding a new sub-command to Config automatically updates the help text. The daily briefing also has a `Help` inline button that triggers the same output.

## Workflows

| File | Purpose | Activation | |
|------|---------|------------|-|
| `daily-briefing.json` | Calendar + buttons message | Schedule (7 AM) | |
| `menu-handler.json` | Config-driven hub with AI routing | Always on (webhook) | |
| `subworkflows/learning-notes.json` | Notion AI summary | Called by menu-handler | |
| `subworkflows/deal-finder.json` | Shopping advisor + price tracker | Called by menu-handler | [headers](workflows/mainflow.md#google-sheet-schemas) |
| `subworkflows/price-checker.json` | Batch price checking engine | Called by daily-briefing + deal-finder | [headers](workflows/mainflow.md#google-sheet-schemas) |

## Setup

1. Import all 4 workflows into n8n (daily-briefing is in project 05)
2. In `menu-handler.json`, update workflowId values in menu-handler Config node
3. Activate `menu-handler.json` (must be always-on for button taps)
4. `daily-briefing.json` runs on schedule or test via Manual Trigger

## Credentials

See [workflows/mainflow.md](workflows/mainflow.md#credentials) for the full credential table with setup instructions.

## Dependencies

- Google Calendar OAuth
- Telegram Bot (n8n_house_bot)
- Groq API (classifier + reasoning LLM)
- Perplexity API (research queries)
- Brave Search API (factual lookups — Header Auth credential)
- Notion API (for learning-notes)
- Google Gemini API (for learning-notes)
- Postgres (for AI chat memory)
- Project 04 expense-trend-report (for expenses button)
