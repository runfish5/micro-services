## Setup Guide — Standalone Extraction

**Time:** ~15 min | **Difficulty:** Easy | **Cost:** Free

Paste raw text into a row, get the rest of the row filled in.

> **Go further:**
> [Email-CRM Guide](email-crm-guide.md) · [JSON Worksheet](json-worksheet.md)

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

| email | Text_to_interpret | name | company | role | phone | location | extraction_error |
|-------|-------------------|------|---------|------|-------|----------|------------------|

4. In a few rows, fill `email` and paste some text into `Text_to_interpret` (an email signature, a bio, meeting notes). Leave the other columns empty; the workflow fills them.

- `email` is the key: the workflow writes each result back into the row with the same email.
- `Text_to_interpret` is what the LLM reads. Rows where it is empty are skipped.
- `extraction_error` is optional. If a row fails, the reason is written there instead of being hidden.

> **Tip:** Every other column name is up to you. The workflow reads whatever headers you provide and builds extraction rules to match.

---

### Step 2: Import the Workflow

1. Download [`smart-table-fill.n8n.json`](../workflows/smart-table-fill.n8n.json)
2. In n8n: **Workflows → Import from File** → select the JSON
3. **Save**, then **Publish**

Publishing is only required if another workflow will call this one.

---

### Step 3: Set Up Credentials

**Google Sheets (OAuth2)**
- **Credentials → Add Credential → Google Sheets (OAuth2)** and follow the OAuth flow
- Assign it to **Get Rows in Sheet**, **Fetch Data Sheet Headers**, **Try Fetch Schema Sheet**, **Create and Write Schema Sheet** and **Write Extracted Row**
- Details: [n8n Google Sheets credentials docs](https://docs.n8n.io/integrations/builtin/credentials/google/)

**LLM API Key**
- Add a credential for your LLM provider on **Schema LLM** and **LLM Processor**
- Free tier is fine

n8n highlights nodes with missing credentials in red. The three disabled CRM nodes (bottom right) can stay as they are.

---

### Step 4: Pick Your Sheet

Open the **Get Rows in Sheet** node and select your spreadsheet and the **Contacts** tab from the dropdowns.

That is the only place you need to set them. **String Input** reads both from this node. All other settings have working defaults:

| Field in String Input | Default | Change it to… |
|---|---|---|
| `match_same_row` | `true` | `false` to append a new row per text instead of updating the matching row (the `email` column is then left empty) |
| `text_column` | `Text_to_interpret` | use a different column as the input text |
| `batch_size` | `10` | fewer columns per LLM call if your model struggles with wide tables. Each call repeats the prompt and text, so more calls cost more tokens |
| `schema_sheet_name` | `Description_hig7f6` | a different name for the schema tab |

---

### Step 5: Run Your First Extraction

Click **Test workflow**.

**What happens:**
1. Reads your rows and your column headers
2. On the first run only, creates a schema tab (`Description_hig7f6`) with auto-generated extraction rules
3. The LLM extracts the fields from each row's `Text_to_interpret`
4. The values are written back into each row

Takes 10–30 seconds per row, depending on your LLM provider.

---

### Step 6: Check the Results

Open your Google Sheet:

- **Contacts tab** — the empty columns of each row are now filled
- **`Description_hig7f6` tab** — auto-generated schema, reused on future runs:

| ColumnName | Type | Description | Classes |
|------------|------|-------------|---------|
| name | str | Full name of the person | |
| email | str | Email address | |
| company | str | Company or organization name | |
| ... | ... | ... | |

You can edit the schema to refine types, descriptions, or add enum classes — see [json-worksheet.md](json-worksheet.md).

> **Re-running** processes every row with text again and overwrites the extracted columns. Clear `Text_to_interpret` on rows you want left alone.

---

### Step 7: Try Different Schemas

Change your column headers (keep `email` and `Text_to_interpret`), delete the `Description_hig7f6` tab, and re-run. The workflow rebuilds the schema for any table shape.

**Example headers:**

`email | Text_to_interpret | book_title | author | year_published | genre`

`email | Text_to_interpret | product_name | brand | price | rating | pros | cons`

No natural key like email? Set `match_same_row` to `false` in **String Input**, and each text is appended as a new row. A row with no email is always appended.

---

### Troubleshooting

| Problem | Fix |
|---------|-----|
| **Fetch Data Sheet Headers** fails with 404 | No spreadsheet picked yet in **Get Rows in Sheet**, or the tab name is wrong |
| "Schema sheet already exists" error | Delete the `Description_hig7f6` tab and re-run |
| **Build Output Schema** stops: "Type class but Classes is empty" | Add comma-separated values in the schema tab's `Classes` column, or change the Type to `str` |
| A row is written with an `extraction_error` | The LLM failed on that row twice. Read the message; usually a rate limit or a schema the model could not satisfy |
| Rate limit errors (429) | Process fewer rows per run, or see [troubleshooting.md](../../troubleshooting.md) |
| Schema types look wrong | Edit `Description_hig7f6` manually — change Type, Description, or Classes |
| Nodes highlighted red | Assign Google Sheets and LLM credentials to those nodes |
