# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

n8n workflow that extracts structured data from unstructured text using LLM and dynamically-generated schema from Google Sheets headers. Key feature: **auto-creates schema sheet on first run** using LLM to infer types, descriptions, and enum values from column names.

## How It Works

1. Reads column headers from user's data sheet (e.g., "Entries")
2. Checks if schema sheet (`Description_hig7f6`) exists
3. If not: creates it via Sheets API, uses LLM to generate Type/Description/Classes for each column
4. Generates JSON schema dynamically from schema sheet
5. Uses LLM (Groq) to extract structured data from raw text input
6. Updates matching row in data sheet with extracted fields

## Where Information Lives

### Workflows
- `workflows/smart-table-fill.n8n.json` - Main workflow (21 nodes)

### Documentation
- `docs/mainflow.md` - Complete node breakdown, data flow diagrams
- `docs/setup-guide.md` - Setup instructions

## Key Configuration (String Input Node)

| Field | Purpose |
|-------|---------|
| `SpreadsheetId` | Google Sheets document ID |
| `DataSheetName` | Your data sheet (e.g., "Entries") |
| `SchemaSheetName` | Schema definition sheet (`Description_hig7f6`) |
| `TextObject_User` | Raw text to extract data from |
| `MatchColumn` / `MatchValue` | Which row to update |
| `BatchSize` | Fields per LLM batch |

## Schema Sheet Structure

The `Description_hig7f6` sheet is auto-generated with columns:
- `ColumnName` - Exact column name from data sheet
- `Type` - One of: `str`, `int`, `date`, `list`, `class`
- `Description` - Brief field description
- `Classes` - Comma-separated enum values (only for `class` type)

LLM infers initial values; users can refine them.
