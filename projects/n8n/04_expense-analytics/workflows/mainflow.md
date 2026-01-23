# Expense Trend Report

> Monthly expense chart to Telegram. Converts CHF/EUR → USD with live rates.

## Node Sequence

```
Trigger → Config → Fetch Exchange Rates → Read Invoices → Build Chart Data → QuickChart API → Telegram
```

## Key Nodes

| Node | Purpose | References |
|------|---------|------------|
| Config | User settings (MONTHS_BACK, TOP_N_VENDORS, thresholds) | — |
| Fetch Exchange Rates | `GET frankfurter.app/latest?base=USD` | — |
| Build Chart Data | Currency conversion, aggregation, Chart.js config | `$('Config')`, `$('Fetch Exchange Rates')` |

## Data Contract

**Input (Google Sheets):**
| Column | Required | Notes |
|--------|----------|-------|
| `supplier_name` | ✓ | Vendor name |
| `invoice_date` | ✓ | Supports `DD.MM.YYYY` and ISO |
| `total_amount_due` | ✓ | Parsed as float |
| `currency` | — | CHF/EUR/USD, defaults to EUR |

**Output (Telegram):**
```
📊 Nov 25: $392 (Helsana $297, Anthropic $94)
📊 Dec 25: $227 (Thomann $206, TalkTalk $22)
💱 Rates: 1 USD = 0.89 CHF, 0.92 EUR
```

## Gotchas

- **Currency conversion**: `amount_usd = amount / rate` (rate = units per 1 USD)
- **No currency column** → assumes EUR
- **Empty leading months** trimmed from chart
- **Vendor names** truncated to 15 chars
- **Alert emoji** (⚠️) when MoM variance > `VARIANCE_ALERT_PCT`

## APIs (both free, no auth)

- **frankfurter.app**: ECB exchange rates
- **quickchart.io**: Chart.js → PNG
