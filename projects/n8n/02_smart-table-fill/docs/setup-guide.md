## Setup Guide — Standalone Extraction

**Time:** ~15 min | **Difficulty:** Easy | **Cost:** Free

Paste raw text, get a structured row in your Google Sheet.

> **Go further:**
> [Email-CRM Guide](email-crm-guide.md) · [JSON Worksheet](json-worksheet.md) · [Parameters Reference](parameters.md)

---

### Prerequisites

- **n8n instance** — cloud or self-hosted ([n8n.io](https://n8n.io))
- **Google account** — for Sheets OAuth
- **Free LLM API key** — any provider with structured output support

---

### Step 1: Create Your Google Sheet

1. Create a new spreadsheet at [sheets.google.com](https://sheets.google.com)
2. Rename the first tab to **Contacts** (or any name)
3. Add headers to **row 1**:

| name | email | company | role | phone | location |
|------|-------|---------|------|-------|----------|

Leave every other row empty — the workflow fills them.

> **Tip:** You can use any column names. The workflow reads whatever headers you provide and builds extraction rules to match.

---

### Step 2: Import the Workflow

1. Download [`smart-table-fill.n8n.json`](../workflows/smart-table-fill.n8n.json)
2. In n8n: **Workflows → Import from File** → select the JSON
3. **Save**, then **Publish**

Publishing is required — subworkflow calls won't resolve without it.

---

### Step 3: Set Up Credentials

**Google Sheets (OAuth2)**
- **Credentials → Add Credential → Google Sheets (OAuth2)** and follow the OAuth flow
- Details: [n8n Google Sheets credentials docs](https://docs.n8n.io/integrations/builtin/credentials/google/)

**LLM API Key**
- Add a credential for your LLM provider (the node will prompt you)
- Free tier is fine — the workflow handles rate limits

Assign each credential to its matching nodes. (n8n highlights missing credentials in red.)

---

### Step 4: Configure the String Input Node

Open the **String Input** node (first node after Manual Trigger):

| Field | Value | How to find it |
|-------|-------|----------------|
| `spreadsheet_id` | Your Google Sheet's ID | The long string in the URL: `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit` |
| `data_sheet_name` | `Contacts` | The tab name from Step 1 |
| `body_core` | Any text to extract from | An email, a note, a bio — anything with data matching your columns |

Leave all other fields at defaults.

---

### Step 5: Run Your First Extraction

Paste any text into `body_core` — an email signature, a LinkedIn bio, meeting notes. Click **Test Workflow**.

**What happens:**
1. Reads your column headers from the Contacts sheet
2. First run creates a schema sheet (`Description_hig7f6`) with auto-generated extraction rules
3. LLM extracts structured data from the text
4. New row appears in your Contacts sheet

Takes 10–30 seconds depending on your LLM provider.

---

### Step 6: Check the Results

Open your Google Sheet:

- **Contacts tab** — new row with extracted data matching your columns
- **`Description_hig7f6` tab** — auto-generated schema, reused on future runs:

| ColumnName | Type | Description | Classes |
|------------|------|-------------|---------|
| name | str | Full name of the person | |
| email | str | Email address | |
| company | str | Company or organization name | |
| ... | ... | ... | |

You can edit the schema to refine types, descriptions, or add enum classes — see [json-worksheet.md](json-worksheet.md).

---

### Step 7: Try Different Schemas

Change your column headers, delete the `Description_hig7f6` tab, and re-run. The workflow rebuilds the schema for any table shape.

**Example headers:**

`book_title | author | year_published | genre`

`product_name | brand | price | rating | pros | cons`

---

### Troubleshooting

| Problem | Fix |
|---------|-----|
| "Schema sheet already exists" error | Delete the `Description_hig7f6` tab and re-run |
| LLM returns empty or garbage | Check API key validity and structured output support |
| Rate limit errors (429) | Increase `rate_limit_wait_seconds` in Config, or wait and retry |
| "Sheet not found" | Verify `spreadsheet_id` and `data_sheet_name` match exactly |
| Schema types look wrong | Edit `Description_hig7f6` manually — change Type, Description, or Classes |
| Nodes highlighted red | Assign Google Sheets and LLM credentials to those nodes |
