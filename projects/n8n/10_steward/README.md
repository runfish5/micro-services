# 10 - Steward

Personal assistant via Telegram — morning briefing, on-demand dispatch, and subworkflow delegation.

## What It Does

Every morning at 7 AM, sends a Telegram message with:
- Today's Google Calendar events (time + title)
- 4 inline buttons for on-demand actions

```
  ☀ Good morning! Your day:
  09:00-10:00  Team standup
  14:00-15:30  Client call

  [📊 Expenses]     [📚 Learning Notes]
  [🛒 Deal Finder]  [🐟 Mr. Runfish]
```

Tapping a button triggers the corresponding subworkflow.

## Workflows

| File | Purpose | Activation |
|------|---------|------------|
| `daily-briefing.json` | Calendar + buttons message | Schedule (7 AM) |
| `menu-handler.json` | Button tap router | Always on (webhook) |
| `subworkflows/learning-notes.json` | Notion AI summary | Called by menu-handler |
| `subworkflows/deal-finder.json` | Stub | Called by menu-handler |
| `subworkflows/runfish-inbox.json` | Stub | Called by menu-handler |

## Button Actions

| Button | Status | What It Does |
|--------|--------|------------|
| Expenses | Active | Calls expense-trend-report (project 04) - sends chart + insights |
| Learning Notes | Active | Searches Notion, AI-summarizes notes, sends to Telegram |
| Deal Finder | Stub | Responds "not yet set up" |
| Mr. Runfish | Stub | Responds "not yet accepting tasks" |

## Setup

1. Import all 5 workflows into n8n
2. In `menu-handler.json`, update the 4 Execute Workflow node IDs to match actual workflow IDs
3. Activate `menu-handler.json` (must be always-on for button taps)
4. `daily-briefing.json` runs on schedule or test via Manual Trigger

## Dependencies

- Google Calendar OAuth
- Telegram Bot (n8n_house_bot)
- Notion API (for learning-notes)
- Google Gemini API (for learning-notes)
- Postgres (for AI chat memory)
- Project 04 expense-trend-report (for expenses button)
