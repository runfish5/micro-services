# Steward

> Morning calendar + interactive menu via Telegram. Two workflows + three subworkflows.

## Architecture

```
daily-briefing.json        Scheduled morning message with inline buttons
menu-handler.json          Always-on hub: routes buttons, /commands, and free text
  -> expense-trend-report  (project 04, called via Execute Workflow)
  -> learning-notes        Notion AI summary
  -> deal-finder           Shopping advisor with Perplexity research (region-configurable)
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

## deal-finder.json (Subworkflow)

Personal shopping advisor that stores product requirements in Google Sheets and uses Perplexity to research the best current options. Region, retailers, and currency are configurable (defaults to Switzerland).

### Commands

| Command | Example | Action |
|---------|---------|--------|
| `/deals` | `/deals` | Get recommendations for all active categories |
| `/deals <category>` | `/deals phone` | Get recommendations for specific category only |
| `/deals add <category> <price> <constraints>` | `/deals add phone 800CHF flagship camera` | Add requirement to watchlist |
| `/deals remove <category>` | `/deals remove phone` | Remove category from watchlist |
| `/deals pause <category>` | `/deals pause phone` | Pause category (won't appear in digests) |
| `/deals resume <category>` | `/deals resume phone` | Resume paused category |

### Flow Diagram

```
Execute Workflow Trigger
  ↓
Config (sheet ID, chat ID)
  ↓
Parse Command → Route Operation
                    |
                    |-- digest  → Load Requirements → Filter Active → Check Empty
                    |                                                     |-- empty → Send Empty Message
                    |                                                     |-- has items → Loop → Perplexity → Format → Collect → Build Digest → Send
                    |
                    |-- add     → Append Requirement → Confirm Add
                    |
                    |-- remove  → Load for Remove → Find Row → Check Found
                    |                                              |-- found → Delete Row → Confirm Remove
                    |                                              |-- not found → Not Found message
                    |
                    |-- pause   → Load → Find → Check Found → Update to Paused → Confirm
                    |
                    └-- resume  → Load → Find → Check Found → Update to Active → Confirm
```

### Google Sheet Schema

Create a Google Sheet named "Deal Finder Requirements" with these columns:

| Column | Type | Example |
|--------|------|---------|
| category | string | Phone |
| constraints | string | flagship, good camera, OLED |
| max_price | string | 800 CHF |
| priority | string | high / medium / low |
| status | string | active / paused |

### Perplexity Prompt Template

The Perplexity node uses this prompt for each requirement (values from Config):

```
You are a shopping advisor for {{ region }}. Find the current best value option for:

Category: {{ category }}
Requirements: {{ constraints }}
Budget: {{ max_price }}
Priority: {{ priority }}

Search retailers in {{ region }} ({{ retailers }}, etc.) and recommend 2-3 options with:
- Product name and model
- Current price in {{ currency }}
- Where to buy (retailer name)
- Why it's a good value

Focus on products actually available in {{ region }}.
```

### Config Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `sheetId` | `YOUR_DEAL_FINDER_SHEET_ID` | Google Sheet document ID |
| `sheetName` | `Requirements` | Sheet/tab name |
| `chatId` | `YOUR_CHAT_ID_1` | Telegram chat for responses |
| `region` | `Switzerland` | Country/region for shopping |
| `retailers` | `Digitec, Galaxus, Toppreise, IKEA, Interdiscount, MediaMarkt, Brack, Microspot` | Comma-separated retailer list |
| `currency` | `CHF` | Currency code for prices |

Callers can override any of these by passing values in the Execute Workflow input. For example:
```json
{ "region": "Germany", "currency": "EUR", "retailers": "Amazon.de, Saturn, MediaMarkt" }
```

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Config | code | Merges defaults with input overrides |
| Parse Command | code | Parses `/deals` command variants, extracts operation/category/constraints |
| Route Operation | switch | 5 outputs: digest, add, remove, pause, resume |
| Load Requirements | googleSheets | Reads all rows from requirements sheet |
| Filter Active | code | Filters to status=active, optional category filter |
| Check Empty | if | Routes empty results to message vs. Perplexity loop |
| Loop Requirements | splitInBatches | Processes one requirement at a time |
| Perplexity Research | perplexity | Swiss shopping research via Perplexity API |
| Format Result | code | Adds emoji header, formats Perplexity response |
| Collect Results | aggregate | Aggregates all formatted results |
| Build Digest | code | Combines results into final Telegram message |
| Send Digest | telegram | Sends digest with Markdown formatting |
| Append Requirement | googleSheets (append) | Adds new row to sheet |
| Delete Row | googleSheets (delete) | Removes row by index |
| Update to Paused/Active | googleSheets (update) | Changes status field |

### Credentials

| Service | n8n Credential Type | Purpose |
|---------|-------------------|---------|
| Google Sheets | Google Sheets OAuth2 (`CREDENTIAL_ID_GOOGLE_DRIVE`) | Read/write requirements |
| Perplexity | Built-in Perplexity API (`CREDENTIAL_ID_PERPLEXITY`) | Shopping research |
| Telegram | Built-in Telegram API (`CREDENTIAL_ID_TELEGRAM`) | Send results |

### Post-Import Setup

1. Create Google Sheet with the schema above
2. Update Config node with your sheet ID
3. Verify Perplexity and Telegram credential IDs match your n8n instance
