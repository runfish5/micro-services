# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What This Is

Personal assistant (steward) that serves as the central touchpoint for the user via Telegram. Manages morning briefings with today's calendar, dispatches on-demand tasks through inline buttons and slash commands, and delegates to specialized subworkflows. Uses a config-driven agent registry and conversation-aware AI routing.

## How It Works

1. `daily-briefing.json` fires at 7 AM (or manual trigger), fetches Google Calendar events for today
2. Calls `price-checker.json` to get current prices for tracked products
3. Formats a combined message with calendar + price tracker section, appends 3 inline keyboard buttons
3. Sends to Telegram; user taps a button whenever they want
4. `menu-handler.json` (always-on) receives the callback query, validates the chat ID
5. **Config node** provides the agent registry (name → workflowId + description)
6. **Normalize** parses input using the registry to identify known actions
7. **Route** dispatches: known actions go to a dynamic Execute Workflow; free text goes to the AI Classifier
8. **AI Classifier** (with Postgres conversation memory) routes free text to either subworkflows or LLM backends
9. Each subworkflow handles its own Telegram reply; LLM backend responses are formatted and sent by the hub

## Architecture: Config-Driven Routing

The menu-handler uses a **Config code node** as the single source of truth for available agents:

```javascript
const agents = {
  expenses: { workflowId: '...', label: 'Expense Report',  desc: 'Monthly expense trends...', ready: true  },
  learning: { workflowId: '...', label: 'Learning Notes',  desc: 'AI-summarized notes...',     ready: false },
  deals:    { workflowId: '...', label: 'Deal Finder',     desc: 'Price tracker + deal research', ready: true  }
};
```

Agents with `ready: false` are stubs — friendly "not available yet" message instead of dispatching.

### Adding a New Agent

1. Add entry to Config node `agents` object with `workflowId`, `label`, `desc`, and `ready: false`
2. Add agent key to the Classifier Output Parser `route_type` enum
3. (Optional) Add inline button to daily-briefing.json
4. Set `ready: true` once the subworkflow is tested and production-ready

Everything else adapts automatically from the registry.

### Two Routing Paths

| Path | Trigger | How it works |
|------|---------|-------------|
| Deterministic | Button tap, /command | Normalize matches registry key → dynamic Execute Workflow |
| AI-classified | Free text | Classifier routes to agents OR LLM backends (Groq, Brave, Perplexity) |

### Conversation Memory

The AI Classifier has Postgres-backed conversation memory (keyed by Telegram chatId). This enables follow-up routing — asking "What is NVIDIA?" then "What about their competitors?" maintains context across messages.

## Where Information Lives

### Workflows
- `../05_daily-briefing/daily-briefing.json` - Extracted to standalone project (Mode B buttons still reference menu-handler here)
- `workflows/menu-handler.json` - Config-driven hub with AI routing (21 nodes + 1 sticky note)
- `workflows/subworkflows/learning-notes.json` - Notion AI summary (12 nodes)
- `workflows/subworkflows/deal-finder.json` - Shopping advisor + price tracker with Sheets CRUD + Perplexity (38 nodes)
- `workflows/subworkflows/price-checker.json` - Batch price checking engine (13 nodes)

### Documentation
- `workflows/mainflow.md` - Node breakdown, credentials, "how to add agent" guide

## Key Configuration

| Parameter | Location | Value |
|-----------|----------|-------|
| Morning schedule | daily-briefing / Schedule Trigger | 7 AM daily |
| Calendar | daily-briefing / Get Today's Events | `uniqued4ve@gmail.com` |
| Chat ID | daily-briefing / Send to Telegram | `YOUR_CHAT_ID_1` |
| Allowed users | menu-handler / Whitelist | `YOUR_CHAT_ID_1`, `YOUR_CHAT_ID_2` |
| Agent registry | menu-handler / Config | expenses, learning, deals |
| Notion search term | learning-notes / Config | `NVIDIA` (configurable) |

## Post-Import Setup

After importing `menu-handler.json`:
1. Update Config node `workflowId` values to match your n8n instance
2. Set credential IDs for Groq, Telegram, Postgres, and Brave Search
3. Verify Postgres is accessible (shared with learning-notes for chat memory)

## Dependencies

- **Google Calendar OAuth** - Calendar: `CREDENTIAL_ID_GOOGLE_CALENDAR`
- **Telegram API** - Bot: `CREDENTIAL_ID_TELEGRAM` (n8n_house_bot)
- **Groq API** - Classifier + reasoning: `CREDENTIAL_ID_GROQ`
- **Perplexity API** - Research queries: `CREDENTIAL_ID_PERPLEXITY`
- **Brave Search API** - Header Auth: `CREDENTIAL_ID_BRAVE_SEARCH` (see [mainflow.md](workflows/mainflow.md#credentials))
- **Notion API** - Account 2: `CREDENTIAL_ID_NOTION`
- **Google Gemini** - PaLM API: `CREDENTIAL_ID_GEMINI`
- **Postgres** - Router Memory + learning-notes chat memory: `CREDENTIAL_ID_POSTGRES`
- **Project 04** - expense-trend-report (callable via Execute Workflow Trigger)
