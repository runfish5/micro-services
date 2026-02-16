# Shared n8n Subworkflows

Reusable workflows called by multiple projects.

## gdrive-recursion.json

Resolves folder paths to Google Drive IDs. n8n requires IDs, not paths.

**Features:**
- Self-recursive folder creation
- Caches results in PathToIDLookup sheet
- Batch or query mode

**Called by:**
- `04_inbox-attachment-organizer`
