# Steward

> Morning calendar + interactive menu via Telegram. Two workflows + two subworkflows.

## Architecture

```
daily-briefing.json        Scheduled morning message with inline buttons
menu-handler.json          Always-on hub: routes buttons, /commands, and free text
  -> expense-trend-report  (project 04, called via Execute Workflow)
  -> learning-notes        Notion AI summary
  -> deal-finder           Stub
  -> LLM classifier        Groq/Brave Search/Perplexity (inlined from mini-dave)
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
| Send to Telegram | telegram | Sends message + 3 inline keyboard buttons | Chat ID: `YOUR_CHAT_ID_1` |

### Inline Keyboard Buttons

| Button | Callback Data |
|--------|---------------|
| Expenses | `briefing:expenses` |
| Learning Notes | `briefing:learning` |
| Deal Finder | `briefing:deals` |

## menu-handler.json

Hub-and-spoke architecture. Accepts four input types: button taps (`callback_query`), slash commands (`/expenses`), free text, and n8n Chat Trigger (for MCP access). A central **Normalize** node produces `{ action, chatId, text }` for all inputs. Known actions (`expenses`, `learning`, `deals`) route deterministically to subworkflows; unknown buttons and free text fall through to an LLM classifier.

```
Telegram Trigger (callback_query + message)
  --> Whitelist
    --> Normalize --------> Route (switch on action)
Chat Trigger ----/                |-- expenses  --> Call Expenses
  (MCP access,                   |-- learning  --> Call Learning Notes
   bypasses Whitelist)           |-- deals     --> Call Deal Finder
                                 |-- chat (catch-all) --> AI Classifier --> LLM Route
                                                              |                |-0-> Groq Reasoning --|
                                                              |                |-1-> Brave Search ----|-> Format Response --> Send Reply
                                                              |                |-2-> Perplexity ------|
                                                            (sub-nodes)
                                                            Groq Classifier LLM
                                                            Classifier Output Parser
```

### Normalize Hub

The Normalize code node handles four input shapes and outputs a unified object:

| Input | action | chatId | text |
|-------|--------|--------|------|
| Chat Trigger `Hello` | `chat` | `n8n-chat` | `"Hello"` |
| Button tap `briefing:expenses` | `expenses` | from `callback_query.message.chat.id` | `""` |
| Button tap `briefing:unknown` (unknown) | `chat` | from `callback_query.message.chat.id` | `"unknown"` |
| Text `/expenses` | `expenses` | from `message.chat.id` | `""` |
| Text `/expenses some context` | `expenses` | from `message.chat.id` | `"some context"` |
| Text `/unknown foo` (unknown cmd) | `chat` | from `message.chat.id` | `"foo"` |
| Text `What is AI?` (no slash) | `chat` | from `message.chat.id` | `"What is AI?"` |

`action` defaults to `chat`. Only known actions (`expenses`, `learning`, `deals`) override it. This avoids empty-string matching issues in the n8n Switch node.

### Route Switch

4 explicit outputs: 3 deterministic (`expenses`, `learning`, `deals`) plus a **catch-all** rule (output 3, named `chat`) that matches `action == "chat"`. Since Normalize defaults `action` to `"chat"` and only overrides it for known actions, all free text, unknown buttons, and unknown commands hit this rule. `fallbackOutput` is set to `"extra"` as a safety net (output 4, unconnected).

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Telegram Trigger | telegramTrigger | Listens for `callback_query` and `message` events |
| Chat Trigger | chatTrigger | MCP-compatible entry point; bypasses Whitelist, connects directly to Normalize |
| Whitelist | if | Checks sender ID from either `callback_query` or `message` against allowed chat IDs |
| Normalize | code | Extracts `{ action, chatId, text }` from buttons, /commands, Chat Trigger, or free text |
| Route | switch | 3 named outputs + explicit catch-all (`chat`) to LLM path |
| Call Expenses | executeWorkflow | Dispatches to expense-trend-report (project 04) |
| Call Learning Notes | executeWorkflow | Dispatches to learning-notes subworkflow |
| Call Deal Finder | executeWorkflow | Dispatches to deal-finder subworkflow |
| AI Classifier | chainLlm | LLM routing prompt — classifies free text into 3 categories |
| Groq Classifier LLM | lmChatGroq | Llama 4 Maverick powering the classifier |
| Classifier Output Parser | outputParserStructured | Enforces `{output_type, query, reasoning, route_name}` schema |
| LLM Route | switch | 3-way on `output.output_type` (0, 1, 2), fallback=0 |
| Groq Reasoning | chainLlm | Route 0: reasoning, coding, creative tasks |
| Groq Reasoning LLM | lmChatGroq | Llama 4 Maverick for reasoning |
| Brave Search | httpRequest | Route 1: Brave Search API (via HTTP Request) |
| Perplexity Research | perplexity | Route 2: research and comparison queries |
| Format Response | code | Normalizes all three route outputs into `{ response, chatId }` |
| Send Reply | telegram | Sends the formatted response to chat |

### LLM Classifier Routes

| output_type | route_name | Use case | Backend |
|-------------|------------|----------|---------|
| 0 | groq_reasoning | Reasoning, coding, creative writing, analysis | Groq Llama 4 Maverick |
| 1 | brave_search | Simple factual lookups ("what is", "who is") | Brave Search API |
| 2 | perplexity | Research, comparisons, investigations | Perplexity API |

### Allowed Chat IDs

- `YOUR_CHAT_ID_1`
- `YOUR_CHAT_ID_2`

### Credentials

| Service | n8n Credential Type | Setup |
|---------|-------------------|-------|
| Telegram | Built-in Telegram API (`CREDENTIAL_ID_TELEGRAM`) | Bot token from @BotFather |
| Groq (classifier + reasoning) | Built-in Groq API (`CREDENTIAL_ID_GROQ`) | API key from [console.groq.com](https://console.groq.com) |
| Perplexity | Built-in Perplexity API (`CREDENTIAL_ID_PERPLEXITY`) | API key from [perplexity.ai](https://perplexity.ai) |
| Brave Search | **Header Auth** (`CREDENTIAL_ID_BRAVE_SEARCH`) | Name: `X-Subscription-Token`, Value: API key from [brave.com/search/api](https://brave.com/search/api/) |

### Post-Import Setup

1. Update the 3 Execute Workflow node IDs to match actual subworkflow IDs in your n8n instance
2. Set Groq, Perplexity, and Telegram credential IDs
3. Create a **Header Auth** credential (Name: `X-Subscription-Token`, Value: API key from [brave.com/search/api](https://brave.com/search/api/))

### Import Collision Warning

If you re-import a workflow without deleting the old one first, n8n silently renames colliding nodes (e.g., `AI Classifier` → `AI Classifier1`) but leaves `$node['AI Classifier']` expressions unchanged — causing `"Referenced node doesn't exist"` at runtime. See [troubleshooting.md](../../troubleshooting.md#referenced-node-doesnt-exist-after-import).

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
