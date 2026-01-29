# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What This Is

n8n workflow that generates monthly expense analytics reports following financial institution standards. Reads invoice data from Google Sheets, aggregates by vendor and time period, calculates variance metrics, and delivers a stacked bar chart visualization via Telegram.

**No LLM required** - pure data aggregation and Chart.js visualization.

## How It Works

1. Schedule trigger fires on 1st of each month (or manual trigger for testing)
2. Loads user configuration (rolling period, vendor count, thresholds)
3. Reads all invoice rows from Google Sheets
4. Aggregates by month and vendor, calculates MoM/YoY variance
5. Builds Chart.js stacked bar configuration
6. Posts to QuickChart API to generate PNG
7. Sends chart image to Telegram with insights caption

## Where Information Lives

### Workflows
- `workflows/expense-trend-report.json` - Main workflow (6 nodes + 1 manual trigger)

### Documentation
- `workflows/mainflow.md` - Node breakdown, variance formulas, data flow

## Key Configuration (Config Node)

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `MONTHS_BACK` | 6 | Rolling period lookback |
| `TOP_N_VENDORS` | 6 | Vendors in chart |
| `CURRENCY_SYMBOL` | `€` | Display symbol |
| `VARIANCE_ALERT_PCT` | 20 | Alert threshold |
| `SHEET_ID` | Billing_Ledger | Source document |

## Data Source

Uses `Billing_Ledger` Google Sheet (same as Telegram Invoice OCR workflow).

**Required columns:**
- `counterparty_name` - Vendor name
- `invoice_date` - Date for filtering/grouping
- `subtotal_amount` - Amount (parsed as float)
- `currency_code` - CHF/EUR/USD, defaults to EUR



## Financial Standards Applied

| Standard | Implementation |
|----------|----------------|
| Rolling periods | Configurable lookback (default 6 months) |
| MoM variance | % change vs prior month |
| YoY variance | Same month comparison (if data exists) |
| Top-N concentration | Configurable vendor limit |
| Visual reporting | Stacked bar chart with color coding |

## Common Tasks

### Testing
Replace Schedule Trigger with Manual Trigger connection (already wired).

### Changing Period
Edit `MONTHS_BACK` in Config node (e.g., 3 for quarterly, 12 for annual).

### Adding Vendors
Increase `TOP_N_VENDORS` in Config node. More than 8 may crowd the legend.

### Different Currency
Update both `CURRENCY_SYMBOL` (for display) and `CURRENCY_CODE` (for filtering if multi-currency data).

## Dependencies

- **Google Sheets OAuth** - Same credential as other workflows
- **Telegram API** - Same bot credential
- **QuickChart.io** - Free tier, no auth required

## Output Example

**Caption:**
```
Jan 26: €1,247 | MoM: ↑12% vs Dec 25 | YoY: ↓5% | 8 invoices
```

**Chart:** 6-month stacked bar chart with top vendors color-coded.
