# Main Flow (6 Nodes)

> Last verified: 2026-01-22

## Overview

Monthly expense analytics workflow that generates visual reports following financial institution standards:
- Rolling period analysis (configurable lookback)
- Month-over-Month (MoM) variance tracking
- Year-over-Year (YoY) variance (when data available)
- Top vendor concentration analysis
- Stacked bar chart visualization via Telegram

## Flow Summary

### Phases
```
Trigger & Config (Nodes 1-2)
  - Schedule or Manual → Config parameters
Data Collection (Node 3)
  - Google Sheets read (all invoice rows)
Analytics Processing (Node 4)
  - Group by month/vendor → Calculate variance → Build Chart.js config
Output (Nodes 5-6)
  - QuickChart API → Telegram notification with chart image
```

### Data Flow
```
Schedule Trigger ───┐
                    ├──→ Config ──→ Read Invoices ──→ Build Chart Data
Manual Trigger ─────┘                                        │
                                                             ▼
                                                    QuickChart API
                                                             │
                                                             ▼
                                                Send Chart to Telegram
```

### Lineage Tree
```
START: Schedule Trigger (1st of month, 9 AM)
  │    OR Manual Trigger (for testing)
  │
  └→ Config (Code node - user configuration)
       │
       └→ Read Invoices (Google Sheets - all rows)
            │
            └→ Build Chart Data (Code node - aggregation + variance)
                 │  - Groups by month AND vendor
                 │  - Calculates MoM and YoY variance
                 │  - Builds Chart.js stacked bar config
                 │
                 └→ QuickChart API (HTTP Request - PNG generation)
                      │
                      └→ Send Chart to Telegram (Photo with caption)
```

## Configuration Node

The `Config` node centralizes all user-editable parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MONTHS_BACK` | 6 | Rolling period lookback |
| `TOP_N_VENDORS` | 6 | Vendors shown in chart legend |
| `CURRENCY_SYMBOL` | `€` | Display symbol |
| `CURRENCY_CODE` | `EUR` | ISO code for filtering |
| `VARIANCE_ALERT_PCT` | 20 | Alert threshold (%) |
| `CHAT_ID` | 7582730035 | Telegram recipient |
| `SHEET_ID` | (2505_Invoices) | Source spreadsheet |
| `SHEET_NAME` | Sheet1 | Tab within spreadsheet |

## Node Details

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Runs on 1st of month at 9 AM |
| 2 | Config | code | Centralized user configuration |
| 3 | Read Invoices | googleSheets | Fetches all invoice rows |
| 4 | Build Chart Data | code | Aggregates, calculates variance, builds Chart.js config |
| 5 | QuickChart API | httpRequest | Generates PNG from Chart.js config |
| 6 | Send Chart to Telegram | telegram | Delivers chart image with insights caption |
| 7 | Manual Trigger | manualTrigger | Testing entry point |

## Analytics Logic (Build Chart Data)

### Variance Calculations

**Month-over-Month (MoM):**
```
MoM % = ((Current Month - Previous Month) / Previous Month) * 100
```

**Year-over-Year (YoY):**
```
YoY % = ((Current Month - Same Month Last Year) / Same Month Last Year) * 100
```
Returns `N/A` if no data exists for comparison month.

### Output Format

**Caption example:**
```
Jan 26: €1,247 | MoM: ↑12% vs Dec 25 | YoY: ↓5% | 8 invoices
```

Alert emoji (⚠️) appended when MoM variance exceeds `VARIANCE_ALERT_PCT`.

**Chart:**
- Type: Stacked bar chart
- X-axis: Rolling months (e.g., Aug 25, Sep 25, ...)
- Y-axis: Currency amounts
- Colors: Each vendor gets a distinct color
- Legend: Bottom position

## Data Requirements

Source sheet must have these columns:

| Column | Type | Notes |
|--------|------|-------|
| `supplier_name` | string | Vendor name (grouping key) |
| `invoice_date` | string/date | Invoice date (filter key) |
| `total_amount_due` | string/number | Amount (parsed as float) |

## QuickChart API

Uses POST to `https://quickchart.io/chart` with JSON body:
```json
{
  "chart": { /* Chart.js config */ },
  "width": 700,
  "height": 450,
  "format": "png"
}
```

Returns binary PNG image for Telegram upload.

## Notes

- **Testing**: Use Manual Trigger instead of waiting for schedule
- **Credential**: Uses same Google OAuth as other n8n workflows
- **Rate limits**: QuickChart has generous free tier (no auth needed)
- **Date parsing**: Invalid dates are skipped (logged but not counted)
- **Vendor truncation**: Names limited to 15 chars for chart readability

---
