# Price History Tracking — Project Spec

## Problem

The deal-finder tracks product prices via URL scraping (`/deals track <url>`), but only stores 4 price snapshots per product: `current_price`, `previous_price`, `lowest_price`, `highest_price`. There is no per-day historical log. Without time-series data, you can't see trends, seasonality, or whether a current price is actually a good deal relative to the last few weeks/months.

The Perplexity research (digest) is useful for discovery, but inconsistent across runs — different products, guessed prices, accuracy issues. The real value of deal-finder is in **tracking specific products at known URLs** with concrete, scraped prices recorded over time.

## Goal

1. **Record** one price data point per product per check cycle (append-only log)
2. **Visualize** price history as a line chart sent to Telegram on demand
3. **No new infrastructure** — Google Sheets + QuickChart.io (both already used)

---

## Architecture Decisions

### Storage: Google Sheets (not Postgres)

New **"Price History"** tab in the existing `Steward_Deals` Google Sheet.

| For Sheets | Against Postgres |
|------------|-----------------|
| Entire deal-finder system already uses Sheets | Would split the data layer — some price data in Sheets, some in Postgres |
| Visually inspectable (open sheet, scan the log) | Requires SQL client to inspect |
| Same credential (`CREDENTIAL_ID_GOOGLE_DRIVE`) | Adds data model complexity |
| 10 products x 365 days = 3,650 rows/year — well within Sheets limits | Overkill for home lab scale |

### Charting: QuickChart.io

Proven pattern from `expense-trend-report.json` (project 04):
- Code node builds a Chart.js config object
- HTTP POST to `https://quickchart.io/chart` → returns PNG binary
- Telegram `sendPhoto` sends the image to the chat

Free tier, no API key, no auth, no rate limits at home lab scale.

### Data Retention: No Pruning

At ~3,650 rows/year with 10 products, the tab won't hit performance issues for years. Pruning can be added later if needed — not worth the complexity now.

---

## Data Model

### Price History Tab Schema

Header row (copy-paste to create the tab):

```
date	url	product_name	price	currency
```

| Column | Type | Example | Notes |
|--------|------|---------|-------|
| `date` | string (ISO) | `2026-02-18` | Date of the check |
| `url` | string | `https://digitec.ch/...` | Links to Tracked Prices tab |
| `product_name` | string | `Raspberry Pi 5 8GB` | Denormalized for readability |
| `price` | number | `89.90` | Scraped price. Empty if extraction failed |
| `currency` | string | `CHF` | From Config |

Design notes:
- `url` is the stable foreign key to `Tracked Prices` tab
- `product_name` is denormalized (avoids cross-tab joins in Code nodes)
- Empty `price` rows are logged when extraction fails — distinguishes "checked but couldn't read" from "never checked"
- Rows are naturally sorted chronologically (append-only)

### Relationship to Existing Tabs

```
Tracked Prices (live state, 1 row per product)
  └─ url ──→ Price History (append-only log, N rows per product)
                ↑ one row appended per product per check cycle
```

---

## Implementation Phases

### Phase 1 — History Storage

**Goal**: Start recording price history with every check cycle. Even before charts exist, this builds up the dataset.

**Prerequisite**: Create "Price History" tab in Google Sheet with the 5-column header row.

**Scope**: `price-checker.json` only

**Changes**:

1. **Config node** — add default:
   ```js
   historySheetName: input.historySheetName || 'Price History'
   ```

2. **New node: "Append History"** (Google Sheets, append operation) — insert between `Extract & Compare` and `Update Row`:
   ```
   Before: Extract & Compare → Update Row
   After:  Extract & Compare → Append History → Update Row
   ```
   Writes: `{ date: $json.last_checked, url: $json.url, product_name: $json.product_name, price: $json.new_price, currency: $json.currency }`

   Set `onError: continueRegularOutput` so history failures don't block price updates.

3. **Sticky note** (purple, color 5) behind Append History: `Appends to Price History tab: date, url, product_name, price, currency`

**Acceptance criteria**:
- [ ] Price History tab exists with header row
- [ ] Run `/deals check_prices` (or wait for daily briefing)
- [ ] One row per tracked product appears in Price History with correct date and price
- [ ] If price extraction failed for a product, a row still appears with empty price
- [ ] `Update Row` still works correctly (Tracked Prices tab updates as before)

**Files modified**: `projects/n8n/10_steward/workflows/subworkflows/price-checker.json`

---

### Phase 2 — `/deals history <product>` Command

**Goal**: Single-product price chart sent to Telegram.

**Scope**: `deal-finder.json`

**New command**: `/deals history <name>` — partial name/URL matching (same pattern as existing `untrack`)

**Node additions** (~6 new nodes):

| Node | Type | Purpose |
|------|------|---------|
| Load History | Google Sheets (read) | Read entire Price History tab |
| Filter Product History | Code | Partial-match by name/URL, build `dataPoints[]`, error if <2 points |
| History Found? | IF | Route to chart or error message |
| Build History Chart | Code | Chart.js line config: single dataset, filled area, date x-axis, price y-axis |
| QuickChart API (History) | HTTP Request | POST to quickchart.io, response as binary PNG |
| Send History Chart | Telegram (sendPhoto) | Send PNG + stats caption |

**Other changes**:
- **Parse Command**: Add `history` pattern before existing operations block:
  ```js
  if (text.toLowerCase().startsWith('history ')) {
    const identifier = text.substring(8).trim();
    return [{ json: { operation: 'history', identifier, chatId } }];
  }
  ```
- **Route Operation**: Add output index 9 "history" → Load History
- **Config**: Add `historySheetName: 'Price History'` default

**Chart details**:
- Line chart with filled area, tension 0.3
- Y-axis: price with currency prefix
- Caption: current price, change since tracking start, all-time low/high, data point count

**Acceptance criteria**:
- [ ] `/deals history raspberry` returns a PNG line chart in Telegram
- [ ] Caption shows current price, % change, low/high, date range
- [ ] Partial matching works (e.g., "rasp" matches "Raspberry Pi 5 8GB")
- [ ] If <2 data points, replies with a text message explaining to wait for more checks
- [ ] If no matching product, replies with "No price history found for ..."

**Files modified**: `projects/n8n/10_steward/workflows/subworkflows/deal-finder.json`

---

### Phase 3 — `/deals plot` Command

**Goal**: All tracked products overlaid on one chart.

**Scope**: `deal-finder.json`

**New command**: `/deals plot` (aliases: `chart`, `graph`, `trend`, `trends`)

**Node additions** (~5 new nodes):

| Node | Type | Purpose |
|------|------|---------|
| Load All History (Plot) | Google Sheets (read) | Read Price History tab (separate node from Phase 2 — n8n can't share nodes across branches) |
| Build Multi Chart | Code | Group by product, one dataset per product, color rotation, `spanGaps: true` |
| Plot Empty? | IF | Route to chart or "no data yet" message |
| QuickChart API (Plot) | HTTP Request | Same pattern as Phase 2 |
| Send Plot Chart | Telegram (sendPhoto) | Send PNG + summary caption |

**Other changes**:
- **Parse Command**: Add `plot` pattern:
  ```js
  if (text.toLowerCase().match(/^(plot|chart|graph|trends?)$/)) {
    return [{ json: { operation: 'plot', chatId } }];
  }
  ```
- **Route Operation**: Add output index 10 "plot" → Load All History (Plot)

**Chart details**:
- Multi-line overlay, no fill, different color per product
- Legend at bottom
- `spanGaps: true` for products with missing days

**Acceptance criteria**:
- [ ] `/deals plot` returns an overlay chart with color-coded lines and legend
- [ ] Each product has its own line with a distinct color
- [ ] Caption shows product count and date range
- [ ] Aliases `/deals chart`, `/deals graph`, `/deals trend` all work
- [ ] If no history data exists, replies with a text message

**Files modified**: `projects/n8n/10_steward/workflows/subworkflows/deal-finder.json`

---

### Phase 4 — Documentation

| File | Update |
|------|--------|
| `projects/n8n/10_steward/workflows/mainflow.md` | Price History schema, new commands, updated node counts, updated price-checker flow |
| `projects/n8n/10_steward/CLAUDE.md` | Add history/chart capability to deal-finder description |
| `projects/n8n/10_steward/setup-guide.md` | Add "create Price History tab with header row" to post-import checklist |

**Acceptance criteria**:
- [ ] mainflow.md documents the Price History schema and new commands
- [ ] setup-guide.md includes the new tab creation step
- [ ] CLAUDE.md mentions price history and chart capabilities

---

## Reference Implementations

### QuickChart.io Pipeline (expense-trend-report.json)

```
Build Chart Data (Code) → QuickChart API (HTTP POST) → Send Chart to Telegram (sendPhoto)
```

**QuickChart API node config**:
```json
{
  "method": "POST",
  "url": "https://quickchart.io/chart",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({ chart: $json.chartConfig, width: 700, height: 450, format: 'png', version: '3' }) }}",
  "options": { "response": { "response": { "responseFormat": "file" } } }
}
```

**Telegram sendPhoto node config**:
```json
{
  "operation": "sendPhoto",
  "chatId": "={{ $('Config').first().json.chatId }}",
  "binaryData": true,
  "additionalFields": { "caption": "={{ $('Build Chart Data').first().json.insights }}" }
}
```

### Extract & Compare Output Shape (price-checker.json)

The node that produces the data for Append History:
```json
{
  "url": "https://digitec.ch/...",
  "product_name": "Raspberry Pi 5 8GB",
  "new_price": 89.90,
  "currency": "CHF",
  "last_checked": "2026-02-18",
  "old_price": 95.00,
  "previous_price": 95.00,
  "current_price": 89.90,
  "lowest_price": 89.90,
  "highest_price": 99.00,
  "priceChanged": true,
  "direction": "down",
  "shouldNotify": true,
  "notify_mode": "always"
}
```

Append History uses: `last_checked` → `date`, `url`, `product_name`, `new_price` → `price`, `currency`

---

## Out of Scope (Future Ideas)

- Price alert charts auto-included in daily briefing when significant drops occur
- `/deals compare <product1> <product2>` — side-by-side chart
- `/deals export` — CSV download of Price History
- Sub-daily check frequency (more cron triggers)
- History pruning (delete rows older than N months)
- Price prediction / trend analysis with LLM
