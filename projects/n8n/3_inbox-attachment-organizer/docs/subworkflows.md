# Subworkflows Documentation

This workflow system uses several subworkflows to handle specific tasks. Here's a detailed breakdown of each subworkflow and its requirements.

---

## 1. google-drive-folder-id-lookup

**Purpose:** Locates or creates Google Drive folder structure based on a given path.

**Called by:** Main workflow (inbox-attachment-organizer)

**Workflow file:** `workflows/subworkflows/google-drive-folder-id-lookup.json`

**Requirements:**
- Google OAuth credentials (Drive + Sheets access)
- **PathToIDLookup Google Sheet** with columns: `path | folder_id | child_ids | last_update`
  - Location: Root directory of Google Drive
  - Purpose: Caches folder IDs to avoid repeated API calls

**Input:** Path components (year, month, category, etc.)

**Output:** Google Drive folder ID where files should be uploaded

**How it works:**
1. Checks PathToIDLookup sheet for cached folder ID
2. If found: Returns cached ID
3. If not found: Calls `google-drive-folder-id-recursion` to create folder structure
4. Updates PathToIDLookup sheet with new folder ID

---

## 2. google-drive-folder-id-recursion

**Purpose:** Recursively creates Google Drive folder structure when folders don't exist.

**Called by:** google-drive-folder-id-lookup subworkflow

**Workflow file:** `workflows/subworkflows/google-drive-folder-id-recursion.json`

**Requirements:**
- Google OAuth credentials (Drive + Sheets access)
- **PathToIDLookup Google Sheet** with columns: `path | folder_id | child_ids | last_update`

**How it works:**
1. Receives path components from parent workflow
2. Creates folders hierarchically (parent ’ child ’ grandchild)
3. Records each folder ID in PathToIDLookup sheet
4. Returns final folder ID to calling workflow

---

## 3. any-file2json-converter

**Purpose:** Extracts text content from various file types (PDFs, images, documents) and returns structured JSON.

**Called by:** Main workflow (inbox-attachment-organizer)

**Workflow file:** `workflows/subworkflows/any-file2json-converter.json`

**Requirements:**
- AI provider credentials:
  - Groq (free) OR
  - Google Gemini (free tier)
- Handles: PDFs, images (with OCR), Word documents, Excel files, etc.

**Input:** File attachment from email

**Output:** Structured JSON with extracted text and metadata

**How it works:**
1. Detects file type
2. Uses appropriate extraction method:
   - **Images:** Gemini Flash Vision (OCR)
   - **PDFs:** Text extraction or OCR if image-based
   - **Documents:** Direct text parsing
3. Returns structured JSON output

---

## 4. gmail-systematic-processor

**Purpose:** Batch processes all existing emails in your Gmail inbox (not just new incoming emails).

**Workflow file:** `workflows/subworkflows/gmail-systematic-processor.json`

**Requirements:**
- Google OAuth credentials (Gmail + Drive + Sheets access)
- All main workflow requirements (AI provider, Google Sheets, etc.)

**When to use:**
- **After first setup** to process historical emails
- The main workflow's Gmail trigger only catches NEW incoming emails
- This workflow cleans up and organizes all existing attachments

**How it works:**
1. Queries Gmail for all emails with attachments
2. Processes each email using the same logic as the main workflow
3. Files attachments to appropriate Google Drive folders
4. Logs data to Google Sheets

**Usage:**
- Run manually once after initial setup
- Run periodically to catch up on any missed emails
- Safe to run multiple times (won't duplicate files)

---

## Summary

| Subworkflow | Purpose | Requires PathToIDLookup | Requires AI Provider |
|-------------|---------|------------------------|---------------------|
| google-drive-folder-id-lookup | Find/create folders |  Yes | L No |
| google-drive-folder-id-recursion | Recursive folder creation |  Yes | L No |
| any-file2json-converter | Extract text from files | L No |  Yes |
| gmail-systematic-processor | Batch process existing emails |  Yes (via folder lookup) |  Yes (via file converter) |

---

## Import Order

It's recommended to import subworkflows in this order:
1. google-drive-folder-id-recursion (no dependencies)
2. google-drive-folder-id-lookup (depends on recursion)
3. any-file2json-converter (no dependencies)
4. inbox-attachment-organizer (main workflow - depends on all subworkflows)
5. gmail-systematic-processor (depends on main workflow logic)
