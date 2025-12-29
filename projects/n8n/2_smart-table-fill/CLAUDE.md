# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

n8n workflow that extracts structured data from unstructured text using LLM and dynamically-generated schema from Google Sheets headers. Key feature: no manual schema definition needed - point it at any table and it auto-discovers the structure.

## How It Works

1. Reads column headers from Google Sheets "Description" tab
2. Generates JSON schema dynamically from headers
3. Uses LLM (Groq) to extract structured data from raw text input
4. Updates matching row in Google Sheets with extracted fields

## Where Information Lives

### Workflows
- `workflows/smart-table-fill.json` - Main workflow

### Documentation
- `docs/` - Setup guides and flow documentation
