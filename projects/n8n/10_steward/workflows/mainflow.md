# Steward

> Morning calendar + config-driven personal assistant via Telegram. Two workflows + three subworkflows.

## Architecture

```
daily-briefing.json          Scheduled morning message with inline buttons
menu-handler.json            Always-on hub with config-driven routing + conversation memory
  -> Config registry         Defines agents: name → workflowId + description
  -> Deterministic path      Buttons and /commands → dynamic Execute Workflow
  -> AI Classifier path      Free text → LLM routes to agents OR LLM backends
     -> expense-trend-report (project 04, via registry)
     -> learning-notes       Notion AI summary (via registry)
     -> deal-finder          Shopping advisor (via registry)
     -> Groq Reasoning       Coding, analysis, creative tasks
     -> Brave Search         Factual lookups
     -> Perplexity           Research and comparisons
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

Config-driven hub-and-spoke with conversation-aware AI routing (21 nodes + 1 sticky note). Three architectural layers:

1. **Agent Registry** (Config node) — single source of truth for available agents and their workflow IDs
2. **Deterministic routing** — buttons and /commands match registry keys, dispatch via dynamic Execute Workflow
3. **AI routing** — free text goes through a conversation-aware LLM classifier that routes to both agents and LLM backends

```
Telegram Trigger (callback_query + message)
  --> Whitelist
    --> Config (agent registry) --> Normalize --> Route (2-way switch)
Chat Trigger -----/                                  |            |
  (MCP access,                                  [agent]      [chat]
   bypasses Whitelist)                              |            |
                                                    v            v
                                              Call Agent    AI Classifier (+ Router Memory)
                                              (dynamic)          |
                                                           LLM Route (4-way)
                                                          /    |     |     \
                                                     agent  groq  brave  perplexity
                                                       |     |     |      |
                                                       v     └─────┴──────┘
                                              Resolve Agent        |
                                                   |          Format Response
                                              Agent Available?     |
                                              (IF node)       Send Reply
                                               /       \
                                          [true]      [false]
                                             |            |
                                        Call Agent (AI)   |
                                        (dynamic)    Format Response
```

### Config Node — Agent Registry

The Config code node defines all available agents as a JSON registry. To add a new agent, add an entry here and update the Classifier Output Parser enum.

```javascript
const agents = {
  expenses: { workflowId: '...', label: 'Expense Report',  desc: 'Monthly expense trends...', ready: true  },
  learning: { workflowId: '...', label: 'Learning Notes',  desc: 'AI-summarized notes...',     ready: false },
  deals:    { workflowId: '...', label: 'Deal Finder',     desc: 'Shopping and deal research',  ready: false }
};
```

The registry key (e.g., `expenses`) is used as:
- The button callback data suffix (`briefing:expenses`)
- The slash command name (`/expenses`)
- The AI classifier route target
- The lookup key for the dynamic Execute Workflow

### Normalize Hub

The Normalize code node reads `knownActions` from the Config registry (only `ready: true` agents). Outputs a unified object:

| Input | action | chatId | text | workflowId |
|-------|--------|--------|------|------------|
| Chat Trigger `Hello` | `chat` | `n8n-chat` | `"Hello"` | `""` |
| Button tap `briefing:expenses` | `expenses` | from callback_query | `""` | from registry |
| Button tap `briefing:unknown` | `chat` | from callback_query | `"unknown"` | `""` |
| Text `/expenses` | `expenses` | from message | `""` | from registry |
| Text `/expenses some context` | `expenses` | from message | `"some context"` | from registry |
| Text `What is AI?` (no slash) | `chat` | from message | `"What is AI?"` | `""` |

### Route Switch

2 outputs (simplified from 4):

| Output | Condition | Destination |
|--------|-----------|-------------|
| 0 "agent" | `action` != "chat" | Call Agent (dynamic Execute Workflow) |
| 1 "chat" | `action` == "chat" | AI Classifier |
| fallback | safety net | Extra output (unconnected) |

### AI Classifier — Conversation-Aware Unified Router

The AI Classifier is a `chainLlm` node with three sub-nodes:

| Sub-node | Type | Purpose |
|----------|------|---------|
| Groq Classifier LLM | lmChatGroq | LLM powering the classification |
| Classifier Output Parser | outputParserStructured | Enforces `{route_type, query, reasoning}` schema |
| Router Memory | memoryPostgresChat | Postgres-backed conversation memory, keyed by chatId |

The classifier prompt dynamically lists all agents from the Config registry plus the 3 LLM backends. It routes free text to the most appropriate handler — including subworkflows. For example, "check my expenses" routes to the expense agent without needing `/expenses`.

**Conversation memory** enables follow-up routing: asking "What is NVIDIA?" then "What about their competitors?" correctly maintains context across messages.

### Classifier Output Schema

```json
{
  "route_type": "expenses|learning|deals|groq_reasoning|brave_search|perplexity",
  "query": "the original user query",
  "reasoning": "why this route was chosen"
}
```

### LLM Route Switch

| Output | route_type | Destination |
|--------|------------|-------------|
| 0 "groq" | `groq_reasoning` | Groq Reasoning chain |
| 1 "brave" | `brave_search` | Brave Search API |
| 2 "perplexity" | `perplexity` | Perplexity Research |
| fallback | any agent key | Resolve Agent → Agent Available? → Call Agent (AI) |

The fallback catches agent route_types and passes them through **Resolve Agent** (registry lookup) → **Agent Available?** (IF node) → Call Agent (AI) or "not available" via Format Response.

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Telegram Trigger | telegramTrigger | Listens for `callback_query` and `message` events |
| Chat Trigger | chatTrigger | MCP-compatible entry point; bypasses Whitelist |
| Whitelist | if (disabled) | Checks sender ID against allowed chat IDs |
| Config | code | Agent registry: maps action names to workflow IDs and descriptions |
| Normalize | code | Extracts `{ action, chatId, text, workflowId, agents }` using registry |
| Route | switch | 2 outputs: agent (known action) or chat (AI classifier) |
| Call Agent | executeWorkflow | Dynamic dispatch — reads workflowId from Normalize output |
| AI Classifier | chainLlm | Conversation-aware LLM router with memory, output parser |
| Groq Classifier LLM | lmChatGroq | LLM powering the classifier |
| Classifier Output Parser | outputParserStructured | Enforces `{route_type, query, reasoning}` |
| Router Memory | memoryPostgresChat | Conversation context across messages, keyed by chatId |
| LLM Route | switch | 4-way: groq, brave, perplexity, or agent (fallback) |
| Resolve Agent | code | Looks up workflowId from Config registry; returns graceful "not available" message when agent is not ready |
| Agent Available? | if | Routes to Call Agent (AI) when workflowId is present; routes to Format Response when not |
| Call Agent (AI) | executeWorkflow | Dynamic dispatch — reads workflowId from Resolve Agent |
| Groq Reasoning | chainLlm | Reasoning, coding, creative tasks |
| Groq Reasoning LLM | lmChatGroq | Llama 4 Maverick for reasoning |
| Brave Search | httpRequest | Brave Search API (via HTTP Request) |
| Perplexity Research | perplexity | Research and comparison queries (currently disabled) |
| Format Response | code | Normalizes all LLM route outputs into `{ response, chatId }` |
| Send Reply | telegram | Sends the formatted response to chat |

### How to Add a New Agent

1. **Config node**: Add entry with `workflowId`, `label`, `desc`, and `ready: false` (flip to `true` when production-ready)
2. **Classifier Output Parser**: Add the agent key to the `route_type` enum array
3. **daily-briefing** (optional): Add an inline button with callback data `briefing:<key>`

Everything else adapts automatically.

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
| Postgres | Built-in Postgres (`CREDENTIAL_ID_POSTGRES`) | Connection for Router Memory table |

### Post-Import Setup

1. Update Config node workflowId values to match your n8n instance
2. Set Groq, Perplexity, Telegram, and Postgres credential IDs
3. Create a **Header Auth** credential for Brave Search (Name: `X-Subscription-Token`, Value: API key)
4. Verify Postgres is accessible (same instance used by learning-notes)

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
