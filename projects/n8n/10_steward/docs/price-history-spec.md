# Price History Tracking — Design Spec

> Status: Fully implemented (Phases 0-3 + documentation).

## Problem

The deal-finder only stored 4 price snapshots per product: `current_price`, `previous_price`, `lowest_price`, `highest_price`. No per-day historical log means no trends, seasonality, or way to judge if a price is actually a good deal.

## Architecture Decisions

### Storage: Google Sheets (not Postgres)

New **"Price History"** tab in the existing `Steward_Deals` Google Sheet.

- Entire deal-finder system already uses Sheets — no split data layer
- Visually inspectable (open sheet, scan the log)
- Same credential (`CREDENTIAL_ID_GOOGLE_DRIVE`)
- 10 products x 365 days = 3,650 rows/year — well within Sheets limits

### Charting: QuickChart.io

Proven pattern from `expense-trend-report.json` (project 04): Code node builds Chart.js config, HTTP POST to quickchart.io returns PNG, Telegram sendPhoto delivers it. Free tier, no API key.

### Data Retention: No Pruning

At ~3,650 rows/year, the tab won't hit performance issues for years.

## Data Model

### Price History Tab Schema

```
date	url	product_name	price	currency
```

| Column | Type | Notes |
|--------|------|-------|
| `date` | string (ISO) | Date of the check |
| `url` | string | Foreign key to Tracked Prices tab |
| `product_name` | string | Denormalized for readability |
| `price` | number | Empty if extraction failed |
| `currency` | string | From Config |

### Relationship

```
Tracked Prices (live state, 1 row per product)
  └─ url ──→ Price History (append-only log, N rows per product)
               ↑ one row appended per product per check cycle
```

## Commands

| Command | Behavior |
|---------|----------|
| `/deals history <name>` | Single-product price chart (partial name/URL match) |
| `/deals plot` | All products overlaid on one chart (aliases: chart, graph, trend) |

## Out of Scope (Future Ideas)

- Price alert charts auto-included in daily briefing on significant drops
- `/deals compare <product1> <product2>` — side-by-side chart
- `/deals export` — CSV download of Price History
- History pruning (delete rows older than N months)
