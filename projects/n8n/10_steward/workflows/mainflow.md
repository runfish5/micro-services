# Steward

> Morning calendar + price tracker + config-driven personal assistant via Telegram. Two workflows + four subworkflows.

## Architecture

```
daily-briefing.json          Scheduled morning message with inline buttons
menu-handler.json            Always-on hub with config-driven routing + conversation memory
  -> Config registry         Defines agents: name → workflowId + description
  -> Deterministic path      Buttons and /commands → dynamic Execute Workflow
  -> AI Classifier path      Free text → LLM routes to agents OR LLM backends
     -> expense-trend-report (project 04, via registry)
     -> learning-notes       Notion AI summary (via registry)
     -> deal-finder          Shopping advisor + price tracker (via registry)
  -> price-checker          Batch price checking engine (called by daily-briefing + deal-finder)
     -> Groq Reasoning       Coding, analysis, creative tasks
     -> Brave Search         Factual lookups
     -> Perplexity           Research and comparisons
```

## daily-briefing.json

```
Schedule Trigger (7 AM) --> Get Today's Events --> Prepare Price Check --> Check Prices (Execute Workflow) --> Format Message --> Send to Telegram
Manual Trigger ---------/
```

### Node Details

| Node | Type | Purpose | References |
|------|------|---------|------------|
| Schedule Trigger | scheduleTrigger | Fires daily at 7 AM | -- |
| Manual Trigger | manualTrigger | Testing entry point | -- |
| Get Today's Events | googleCalendar | Fetches today's events, `alwaysOutputData: true` | Calendar: `uniqued4ve@gmail.com` |
| Prepare Price Check | code | Passes calendar events forward for price-checker | -- |
| Check Prices | executeWorkflow | Calls price-checker.json, returns `{ priceReport, priceSection }` | `YOUR_PRICE_CHECKER_WORKFLOW_ID` |
| Format Message | code | Builds calendar lines + appends price tracker section from Check Prices | References `$('Get Today\'s Events')` for calendar |
| Send to Telegram | telegram | Sends combined message | Chat ID: `YOUR_CHAT_ID_1` |

### Inline Keyboard Buttons

| Button | Callback Data |
|--------|---------------|
| Expenses | `briefing:expenses` |
| Learning Notes | `briefing:learning` |
| Deal Finder | `briefing:deals` |

## menu-handler.json

Config-driven hub-and-spoke with conversation-aware AI routing (24 nodes + 4 sticky notes). Three architectural layers:

1. **Agent Registry** (Config node) — single source of truth for available agents and their workflow IDs
2. **Deterministic routing** — buttons and /commands match registry keys, dispatch via dynamic Execute Workflow
3. **AI routing** — free text goes through a conversation-aware LLM classifier that routes to both agents and LLM backends

```
Telegram Trigger (callback_query + message)
  --> Whitelist
    --> Config (agent registry) --> Normalize --> Route (3-way switch)
Chat Trigger -----/                              |          |            |
Execute Workflow --/                          [help]    [agent]      [chat]
Trigger                                          |          |            |
  (subworkflow calls,                            v          v            v
   bypass Whitelist)                        Build Help  Run Skill    AI Classifier (+ Router Memory)
                                                |       (dynamic)        |
                                                |          |        LLM Route (4-way)
                                                |          |       /    |     |     \
                                                |          |  agent  groq  brave  perplexity
                                                |          |    |     |     |      |
                                                |          |    v     +-----+------+
                                                |          | Resolve Agent        |
                                                |          |    |          Format Response
                                                |          | Agent Available?     |
                                                |          | (IF node)            |
                                                |          |  /       \           |
                                                |          |[true]   [false]      |
                                                |          |  |          |        |
                                                |          | Run Skill (AI)  Format Response
                                                |          | (dynamic)
                                                |          |  |
                                                |          +--+
                                                |          |
                                                |    Format Skill Response
                                                |          |
                                                v          v
                                              Send Reply
```

### Config Node — Agent Registry

The Config code node defines all available agents as a JSON registry. To add a new agent, add an entry here and update the Classifier Output Parser enum.

```javascript
const agents = {
  expenses: { workflowId: '...', label: 'Expense Report',  desc: 'Monthly expense trends...', ready: true  },
  learning: { workflowId: '...', label: 'Learning Notes',  desc: 'AI-summarized notes...',     ready: true  },
  deals:    { workflowId: '...', label: 'Deal Finder',     desc: 'Price tracker + deal research', ready: true  }
};
```

The registry key (e.g., `expenses`) is used as:
- The button callback data suffix (`briefing:expenses`)
- The slash command name (`/expenses`)
- The AI classifier route target
- The lookup key for the dynamic Execute Workflow

### Normalize Hub

The Normalize code node reads `knownActions` from the Config registry (only `ready: true` agents) and recognizes built-in actions (`help`) that route to dedicated nodes instead of subworkflows. Outputs a unified object:

| Input | action | chatId | text | workflowId |
|-------|--------|--------|------|------------|
| Chat Trigger `Hello` | `chat` | `n8n-chat` | `"Hello"` | `""` |
| Button tap `briefing:expenses` | `expenses` | from callback_query | `""` | from registry |
| Button tap `briefing:unknown` | `chat` | from callback_query | `"unknown"` | `""` |
| Text `/expenses` | `expenses` | from message | `""` | from registry |
| Text `/expenses some context` | `expenses` | from message | `"some context"` | from registry |
| Text `What is AI?` (no slash) | `chat` | from message | `"What is AI?"` | `""` |
| Execute Workflow `{ text: "check deals", chatId: "123" }` | `chat` | `"123"` | `"check deals"` | `""` |

### Route Switch

3 outputs:

| Output | Condition | Destination |
|--------|-----------|-------------|
| 0 "help" | `action` == "help" | Build Help |
| 1 "agent" | `action` != "chat" and != "help" | Run Skill (dynamic Execute Workflow) |
| 2 "chat" | `action` == "chat" | AI Classifier |
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
| fallback | any agent key | Resolve Agent → Agent Available? → Run Skill (AI) |

The fallback catches agent route_types and passes them through **Resolve Agent** (registry lookup) → **Agent Available?** (IF node) → Run Skill (AI) or "not available" via Format Response.

### Node Details

| Node | Type | Purpose |
|------|------|---------|
| Telegram Trigger | telegramTrigger | Listens for `callback_query` and `message` events |
| Chat Trigger | chatTrigger | MCP-compatible entry point; bypasses Whitelist |
| Execute Workflow Trigger | executeWorkflowTrigger | Subworkflow entry point; accepts {text, chatId} from parent workflows; bypasses Whitelist |
| Whitelist | if (disabled) | Checks sender ID against allowed chat IDs |
| Config | code | Agent registry: maps action names to workflow IDs and descriptions |
| Normalize | code | Extracts `{ action, chatId, text, workflowId, agents }` using registry |
| Route | switch | 3 outputs: help (built-in), agent (known action), or chat (AI classifier) |
| Run Skill | executeWorkflow | Dynamic dispatch — reads workflowId from Normalize output. `onError: continueOnFail` — errors flow to Format Skill Response instead of crashing |
| Build Help | code | Generates dynamic help message from the agents registry |
| Format Skill Response | code | Guards subworkflow returns — forwards response to Send Reply only if present. Detects `continueOnFail` error payloads and replies with "temporarily unavailable" |
| AI Classifier | chainLlm | Conversation-aware LLM router with memory, output parser |
| Groq Classifier LLM | lmChatGroq | LLM powering the classifier |
| Classifier Output Parser | outputParserStructured | Enforces `{route_type, query, reasoning}` |
| Router Memory | memoryPostgresChat | Conversation context across messages, keyed by chatId |
| LLM Route | switch | 4-way: groq, brave, perplexity, or agent (fallback) |
| Resolve Agent | code | Looks up workflowId from Config registry; returns graceful "not available" message when agent is not ready |
| Agent Available? | if | Routes to Run Skill (AI) when workflowId is present; routes to Format Response when not |
| Run Skill (AI) | executeWorkflow | Dynamic dispatch — reads workflowId from Resolve Agent. `onError: continueOnFail` — errors flow to Format Skill Response instead of crashing |
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

Everything else adapts automatically -- the `/help` command auto-updates from the registry, listing all agents with their descriptions.

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

Personal shopping advisor with price tracking and Perplexity research (40 nodes). Tracks specific product URLs for daily price updates and researches deals/alternatives from Swiss retailers. Region, retailers, and currency are configurable (defaults to Switzerland).

Remove, pause, and resume share a single "Modify Requirement" branch. All branches converge to one shared Send Reply Telegram node.

### Commands

**Requirement commands (category-based research):**

| Command | Example | Action |
|---------|---------|--------|
| `/deals` | `/deals` | Get recommendations for all active categories |
| `/deals <category>` | `/deals phone` | Get recommendations for specific category only |
| `/deals add <category> <price> <constraints>` | `/deals add phone 800CHF flagship camera` | Add requirement to watchlist |
| `/deals remove <category>` | `/deals remove phone` | Remove category from watchlist |
| `/deals pause <category>` | `/deals pause phone` | Pause category (won't appear in digests) |
| `/deals resume <category>` | `/deals resume phone` | Resume paused category |

**Tracking commands (URL-based price tracking):**

| Command | Example | Action |
|---------|---------|--------|
| `/deals track <url>` | `/deals track https://digitec.ch/...` | Track a product's price |
| `<url>` (auto-detect) | `https://digitec.ch/... track this` | Auto-detected URL → track |
| `/deals tracked` | `/deals tracked` | List all tracked items |
| `/deals untrack <name>` | `/deals untrack raspberry` | Stop tracking (partial name match) |
| `check_prices` | (internal) | Run price checker (delegates to price-checker.json) |

### Flow Diagram

```
Execute Workflow Trigger → Config → Parse Command → Route Operation (9 outputs)
  |
  |-- [0 digest] → Load Requirements → Filter Active → Check Empty
  |                                       (empty) → Send Reply
  |                                       (items) → Build Indicator → Send Reply  (fires immediately)
  |                                              → Is Seed?
  |                                                   (seed) → Seed Demo (append to sheet) → Loop
  |                                                   (not seed) → Loop
  |                                                   Loop → Perplexity → Format → Save Results → Loop
  |                                                   (done) → Collect → Build Digest → Send Reply
  |
  |-- [1 add] → Append Requirement → Build Add Response → Send Reply
  |
  |-- [2 remove] ─┐
  |-- [3 pause]  ──┼→ Load for Modify → Find & Route → Check Found
  |-- [4 resume] ─┘     (true) → Action Switch
  |                                 ├─ [remove] → Delete Requirement → Build Modify Response → Send Reply
  |                                 └─ [pause/resume] → Update Status → Build Modify Response → Send Reply
  |                      (false) → Build Not Found → Send Reply
  |
  |-- [5 track] → Fetch Page → Parse Page → Append Tracked → Build Track Response → Send Reply
  |
  |-- [6 untrack] → Load Tracked → Find Tracked → Check Tracked Found
  |                    (true) → Delete Tracked → Build Untrack Response → Send Reply
  |                    (false) → Build Untrack Not Found → Send Reply
  |
  |-- [7 tracked] → Load All Tracked → Format Tracked List → Send Reply
  |
  └── [8 check] → Execute Price Checker → Build Price Response → Send Reply
```

### Google Sheet Schemas

**`Steward_Deals`** — two tabs:

#### Requirements tab — category-based Perplexity research

Copy-paste this header row into your sheet:

```
category	constraints	max_price	priority	status	recommendations	last_researched
```

| Column | Type | Example |
|--------|------|---------|
| category | string | Phone |
| constraints | string | flagship, good camera, OLED |
| max_price | string | 800 CHF |
| priority | string | high / medium / low |
| status | string | active / paused |
| recommendations | string | (Perplexity output — raw research text) |
| last_researched | string | 2026-02-17 (ISO date of last research) |

#### Tracked Prices tab — URL-based price tracking

Copy-paste this header row into your sheet:

```
url	product_name	domain	current_price	currency	previous_price	lowest_price	highest_price	first_tracked	last_checked	status	notify_mode	price_threshold
```

| Column | Type | Example |
|--------|------|---------|
| url | string | `https://digitec.ch/...` |
| product_name | string | Raspberry Pi 5 8GB |
| domain | string | digitec.ch |
| current_price | number | 89.90 |
| currency | string | CHF |
| previous_price | number | 95.00 |
| lowest_price | number | 85.00 |
| highest_price | number | 99.00 |
| first_tracked | string | 2026-02-08 |
| last_checked | string | 2026-02-10 |
| status | string | active / paused |
| notify_mode | string | always / on_change / threshold |
| price_threshold | number | 80.00 |

### Price Extraction Strategy

When tracking a URL, the Parse Product Page node extracts product name and price using a 4-strategy cascade:

1. **JSON-LD** (`<script type="application/ld+json">` with `@type: Product`) — most reliable, used by most e-commerce sites for SEO
2. **Open Graph meta** (`product:price:amount`) — common on many retailers
3. **HTML `<title>` tag** — fallback for product name
4. **Regex** — Swiss price patterns (`89.90 CHF`, `CHF 89.90`, `89.–`)

If all strategies fail, the item is still tracked with price as `null` ("checking...") and retried on next price check.

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
| `sheetId` | `Steward_Deals` | Google Sheet document ID |
| `sheetName` | `Requirements` | Sheet/tab name for requirements |
| `trackingSheetName` | `Tracked Prices` | Sheet/tab name for price tracking |
| `chatId` | `YOUR_CHAT_ID_1` | Telegram chat for responses |
| `region` | `Switzerland` | Country/region for shopping |
| `retailers` | `Digitec, Galaxus, Toppreise, IKEA, Interdiscount, MediaMarkt, Brack, Microspot` | Comma-separated retailer list |
| `currency` | `CHF` | Currency code for prices |

Callers can override any of these by passing values in the Execute Workflow input. For example:
```json
{ "region": "Germany", "currency": "EUR", "retailers": "Amazon.de, Saturn, MediaMarkt" }
```

### Credentials

| Service | n8n Credential Type | Purpose |
|---------|-------------------|---------|
| Google Sheets | Google Sheets OAuth2 (`CREDENTIAL_ID_GOOGLE_DRIVE`) | Read/write requirements + tracked prices |
| Perplexity | Built-in Perplexity API (`CREDENTIAL_ID_PERPLEXITY`) | Shopping research |
| Telegram | Built-in Telegram API (`CREDENTIAL_ID_TELEGRAM`) | Send results |

### Post-Import Setup

1. Create Google Sheet with both tabs (Requirements + Tracked Prices) using the schemas above
2. Update Config node with your sheet ID and price-checker workflow ID
3. Verify Perplexity and Telegram credential IDs match your n8n instance

## price-checker.json (Subworkflow)

Batch price-checking engine. Called by daily-briefing (on schedule) or by deal-finder's `check_prices` operation (on demand). Reads all active tracked items, fetches each product page, extracts current price, compares with stored price, updates the sheet, and returns a formatted report.

### Flow Diagram

```
Execute Workflow Trigger → Config → Load Tracked (Sheets) → Filter Active → Empty?
                                                                              |-- empty → Return Empty report
                                                                              |-- has items → Loop (batch=1)
                                                                                               ↓
                                                                                          Fetch Page (HTTP)
                                                                                               ↓
                                                                                          Extract & Compare (Code)
                                                                                               ↓
                                                                                          Update Row (Sheets)
                                                                                               ↓
                                                                                          Loop (back)
                                                                                               ↓ (done)
                                                                                          Collect Results → Build Report → Return
```

### Notify Modes

| Mode | Behavior |
|------|----------|
| `always` | Item appears in every price report |
| `on_change` | Only appears when price changed since last check |
| `threshold` | Only appears when price drops below `price_threshold` (Phase 3) |

### Output Format

Returns `{ priceReport, priceSection }` where:
- `priceReport`: Array of item objects with price change details
- `priceSection`: Pre-formatted Markdown string for embedding in briefing messages

Example `priceSection`:
```
📍 *Price Tracker* (2 items)
  Raspberry Pi 5 8GB: 89.90 CHF ➡️
  Samsung Galaxy S25: 799 → 749 CHF 📉 (-6.3%)
```

### Config Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `sheetId` | `Steward_Deals` | Google Sheet document ID |
| `trackingSheetName` | `Tracked Prices` | Sheet/tab name |
| `currency` | `CHF` | Currency code |
| `chatId` | `YOUR_CHAT_ID_1` | Telegram chat (for future alerts) |

### Credentials

| Service | n8n Credential Type | Purpose |
|---------|-------------------|---------|
| Google Sheets | Google Sheets OAuth2 (`CREDENTIAL_ID_GOOGLE_DRIVE`) | Read/update tracked prices |

### Post-Import Setup

1. After importing, re-select `price-checker` in deal-finder's "Call Price Checker" node and daily-briefing's "Check Prices" node
2. Ensure the "Tracked Prices" tab exists in the Google Sheet with column headers
