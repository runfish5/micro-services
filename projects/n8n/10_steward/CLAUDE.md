# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What This Is

Personal assistant (steward) that serves as the central touchpoint for the user via Telegram. Manages morning briefings with today's calendar, dispatches on-demand tasks through inline buttons, and delegates to specialized subworkflows (expense report, learning notes, deal finder). Two main workflows plus two subworkflows.

## How It Works

1. `daily-briefing.json` fires at 7 AM (or manual trigger), fetches Google Calendar events for today
2. Formats a message with time ranges and event titles, appends 3 inline keyboard buttons
3. Sends to Telegram; user taps a button whenever they want
4. `menu-handler.json` (always-on) receives the callback query, validates the chat ID, parses the action
5. Routes to the matching subworkflow via Execute Workflow node
6. Each subworkflow handles its own Telegram reply

## Where Information Lives

### Workflows
- `../05_daily-briefing/daily-briefing.json` - Extracted to standalone project (Mode B buttons still reference menu-handler here)
- `workflows/menu-handler.json` - Button tap router (18 nodes + 2 sticky notes)
- `workflows/subworkflows/learning-notes.json` - Notion AI summary (12 nodes)
- `workflows/subworkflows/deal-finder.json` - Stub (3 nodes)

### Documentation
- `workflows/mainflow.md` - Node breakdown, credentials, post-import setup

## Key Configuration

| Parameter | Location | Value |
|-----------|----------|-------|
| Morning schedule | daily-briefing / Schedule Trigger | 7 AM daily |
| Calendar | daily-briefing / Get Today's Events | `uniqued4ve@gmail.com` |
| Chat ID | daily-briefing / Send to Telegram | `YOUR_CHAT_ID_1` |
| Allowed users | menu-handler / Whitelist | `YOUR_CHAT_ID_1`, `YOUR_CHAT_ID_2` |
| Notion search term | learning-notes / Config | `NVIDIA` (configurable) |

## Post-Import Setup

After importing `menu-handler.json`, update the 3 Execute Workflow node IDs to point to the actual subworkflow IDs in your n8n instance. The expense button calls `expense-trend-report` from project 04 (which now has an Execute Workflow Trigger).

## Dependencies

- **Google Calendar OAuth** - Calendar: `CREDENTIAL_ID_GOOGLE_CALENDAR`
- **Telegram API** - Bot: `CREDENTIAL_ID_TELEGRAM` (n8n_house_bot)
- **Groq API** - Classifier + reasoning: `CREDENTIAL_ID_GROQ`
- **Perplexity API** - Research queries: `CREDENTIAL_ID_PERPLEXITY`
- **Brave Search API** - Header Auth: `CREDENTIAL_ID_BRAVE_SEARCH` (see [mainflow.md](workflows/mainflow.md#credentials))
- **Notion API** - Account 2: `CREDENTIAL_ID_NOTION`
- **Google Gemini** - PaLM API: `CREDENTIAL_ID_GEMINI`
- **Postgres** - Chat memory: `CREDENTIAL_ID_POSTGRES`
- **Project 04** - expense-trend-report (callable via Execute Workflow Trigger)
