# smart-table-fill

Extract structured data from unstructured text into any Google Sheets table - zero schema configuration required.

## Features

- **Auto-schema discovery**: Reads your table headers, builds extraction schema automatically
- **LLM-powered extraction**: Uses Groq to parse unstructured notes into structured fields
- **Dynamic field mapping**: Works with any table structure without code changes

## Quick Start

1. Import workflow into n8n
2. Connect Google Sheets credentials
3. Point to your sheet with column headers defined
4. Feed unstructured text - get structured rows

## Requirements

- n8n v2+
- Google Sheets OAuth credentials
- Groq API key
