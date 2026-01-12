# Credentials Guide

## AI Chatbot APIs

These power the AI nodes in n8n that extract data from text and images.

### Groq

Free tier API for text-based AI (data extraction, classification).

- Get API key at [console.groq.com](https://console.groq.com)
- n8n: Credentials → Add → Groq

### Google Gemini

Free tier API for image/PDF reading (OCR, vision).

- Get API key at [aistudio.google.com](https://aistudio.google.com)
- n8n: Credentials → Add → Google Gemini API

---

## n8n Service Credentials

General n8n credential setup: [docs.n8n.io/credentials](https://docs.n8n.io/credentials/)

### Gmail

For email monitoring and reading attachments.

- Uses Google OAuth2 (same credential works for Drive and Sheets)
- n8n: Credentials → Add → Gmail OAuth2

### Google Drive

For uploading files and creating folder structures.

- Uses same Google OAuth2 credential as Gmail
- n8n: Credentials → Add → Google Drive OAuth2

### Telegram

For bot notifications (optional).

- Create bot via [@BotFather](https://t.me/botfather), get token
- n8n: Credentials → Add → Telegram

### n8n + Google Apps Script Authentication

When n8n writes to Google Sheets via API, the `onEdit` trigger does NOT fire (Google limitation). To call Apps Script from n8n, use the Execution API.

**Setup Guide:** [02_smart-table-fill/docs/apps-script-execution-api-setup.md](02_smart-table-fill/docs/apps-script-execution-api-setup.md)
