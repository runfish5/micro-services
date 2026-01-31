# Steward

> Morning calendar + interactive menu via Telegram. Two workflows + three subworkflows.

## Architecture

```
daily-briefing.json        Scheduled morning message with inline buttons
menu-handler.json          Always-on, routes button taps to subworkflows
  -> expense-trend-report  (project 04, called via Execute Workflow)
  -> learning-notes        Notion AI summary
  -> deal-finder           Stub
  -> runfish-inbox         Stub
```

## daily-briefing.json

```
Schedule Trigger (7 AM) --> Get Today's Events --> Format Message --> Send to Telegram
Manual Trigger ---------/
```

### Node Details

| Node | Type | Purpose | References |
|------|------|---------|------------|
| Schedule Trigger | scheduleTrigger | Fires daily at 7 AM | -- |
| Manual Trigger | manualTrigger | Testing entry point | -- |
| Get Today's Events | googleCalendar | Fetches today's events, `alwaysOutputData: true` | Calendar: `uniqued4ve@gmail.com` |
| Format Message | code | Builds `HH:MM-HH:MM Title` lines, falls back to "No events today" | -- |
| Send to Telegram | telegram | Sends message + 4 inline keyboard buttons | Chat ID: `YOUR_CHAT_ID_1` |

### Inline Keyboard Buttons

| Button | Callback Data |
|--------|---------------|
| Expenses | `briefing:expenses` |
| Learning Notes | `briefing:learning` |
| Deal Finder | `briefing:deals` |
| Mr. Runfish | `briefing:runfish` |

## menu-handler.json

```
Telegram Trigger (callback_query) --> Whitelist --> Parse --> Route
                                                               |--> Call Expenses
                                                               |--> Call Learning Notes
                                                               |--> Call Deal Finder
                                                               |--> Call Mr. Runfish
```

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Telegram Trigger | telegramTrigger | Listens for `callback_query` events only |
| Whitelist | if | Checks `callback_query.from.id` against allowed chat IDs |
| Parse | code | Extracts action name from `briefing:expenses` -> `expenses` |
| Route | switch | 4 outputs by action name, each wired to an Execute Workflow node |

### Allowed Chat IDs

- `YOUR_CHAT_ID_1`
- `YOUR_CHAT_ID_2`

### Post-Import Setup

After importing, update the 4 Execute Workflow node IDs to match the actual workflow IDs in your n8n instance.

## learning-notes.json (Subworkflow)

```
Execute Workflow Trigger --> Config --> Search Notion --> Get Page Blocks --> Extract Text --> Set Fields --> AI Summary --> Send to Telegram
```

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Config | set | Configurable search term (default: "NVIDIA") and chat ID |
| Search Notion | notion (search) | Searches Notion pages by term |
| Get Page Blocks | notion (block/getAll) | Fetches block content from found page |
| Extract Text | code (Python) | Pulls text content from blocks |
| AI Summary | agent | Gemini Flash + structured output (`{think, summary}`) |
| Postgres Chat Memory | memoryPostgresChat | Context persistence across runs |
| Send to Telegram | telegram | Delivers the summary |

### Credentials

- Notion: `Notion account 2` (`CREDENTIAL_ID_NOTION`)
- Gemini: `Google Gemini(PaLM) Api account` (`CREDENTIAL_ID_GEMINI`)
- Postgres: `Postgres account` (`CREDENTIAL_ID_POSTGRES`)
- Telegram: `n8n_house_bot` (`CREDENTIAL_ID_TELEGRAM`)

## deal-finder.json (Stub Subworkflow)

```
Execute Workflow Trigger --> Send "Deal Finder is not yet set up."
```

3 nodes. Sticky note documents future plans: product watchlist, web price search, drop alerts.

## runfish-inbox.json (Stub Subworkflow)

```
Execute Workflow Trigger --> Send "Mr. Runfish is not yet accepting tasks."
```

3 nodes. Sticky note documents future plans: task queue, LLM router, execution handlers.
