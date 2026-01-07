// Google Apps Script - Contact Manager with Auto Folder & MD File Creation
// SETUP: Run this script once, then use the menu "Folder Automation" > "Setup Auto-Folder Creation"
// NOTE: Uses EMAIL as the unique identifier and folder name

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

const CONFIG = {
  sheetName: 'Entries',
  observedColumn: 'email',  // Column header name (finds column dynamically)
  folderPath: ['PrivateD', 'ContactManager', 'names_folders'],
  spreadsheetId: '1si4ZYujqQBnKOTJPi-C7oBuWyS0xri_sZSVQ5hbIjRQ',
  logSheetName: 'AppScript_Logs'
};

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

// Get spreadsheet by ID (works in Web App context, unlike getActiveSpreadsheet)
function getSpreadsheet() {
  return SpreadsheetApp.openById(CONFIG.spreadsheetId);
}

// Log to AppScript_Logs sheet (creates sheet if needed)
function logToSheet(level, functionName, message, data) {
  try {
    const ss = getSpreadsheet();
    let logSheet = ss.getSheetByName(CONFIG.logSheetName);

    // Create log sheet if it doesn't exist
    if (!logSheet) {
      logSheet = ss.insertSheet(CONFIG.logSheetName);
      logSheet.appendRow(['Timestamp', 'Level', 'Function', 'Message', 'Data']);
      logSheet.getRange(1, 1, 1, 5).setFontWeight('bold');
    }

    // Append log entry
    const timestamp = new Date().toISOString();
    const dataStr = data ? JSON.stringify(data) : '';
    logSheet.appendRow([timestamp, level, functionName, message, dataStr]);
  } catch (e) {
    // Fallback to console if logging fails
    console.error('logToSheet failed:', e.message);
  }
}

function getColumnByHeader(sheetName, headerName) {
  const sheet = getSpreadsheet().getSheetByName(sheetName);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const colIndex = headers.findIndex(h => h.toString().toLowerCase() === headerName.toLowerCase());
  return colIndex + 1; // Convert to 1-based
}

// Validate email format (basic but proper validation)
// Accepts: user@domain.tld, user.name+tag@sub.domain.co.uk
// Rejects: @, test@, @test, test@@test.com, spaces
function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email.trim());
}

// ═══════════════════════════════════════════════════════════════
// MENU & TRIGGER SETUP
// ═══════════════════════════════════════════════════════════════

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Folder Automation')
    .addItem('Setup Auto-Folder Creation', 'setupTrigger')
    .addToUi();
}

// Run this once to set up the trigger
function setupTrigger() {
  // Delete existing triggers to avoid duplicates
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => ScriptApp.deleteTrigger(trigger));

  // Create the onEdit trigger
  const ss = getSpreadsheet();
  ScriptApp.newTrigger('onSpreadsheetEdit').forSpreadsheet(ss).onEdit().create();

  const pathDisplay = 'My Drive/' + CONFIG.folderPath.join('/') + '/';
  SpreadsheetApp.getUi().alert(
    '✅ Auto-folder creation is now active!\n\n' +
    `Watching: "${CONFIG.observedColumn}" column in "${CONFIG.sheetName}"\n` +
    `Folders created at: ${pathDisplay}{email}/\n\n` +
    'Each folder will contain:\n' +
    '- README.md (ContactManager-Record)\n' +
    '- emails/ subfolder\n\n' +
    'Both folder_id and emails_folder_id will be stored in the sheet.'
  );
}

// Sanitize email for use as folder name
function sanitizeEmailForFolder(email) {
  return email
    .toLowerCase()
    .replace('@', '_at_')
    .replace(/[^a-z0-9._-]/g, '_');
}

// Triggered when manually editing (fires after edit is complete)
function onSpreadsheetEdit(e) {
  if (!e || !e.range) return;

  const sheet = e.range.getSheet();
  if (sheet.getName() !== CONFIG.sheetName) return;

  const colNum = getColumnByHeader(CONFIG.sheetName, CONFIG.observedColumn);
  if (e.range.getColumn() !== colNum) return;

  const email = e.range.getValue();
  if (email && isValidEmail(email.toString())) {
    const row = e.range.getRow();
    // Get name from column A (for display in README)
    const name = sheet.getRange(row, 1).getValue() || '';
    createFolderForContact(email.toString().trim(), name.toString().trim(), row);
  }
}

// Unified folder creation - returns { folderId, emailsFolderId }
// Called by both onEdit trigger (createFolderForContact) and API endpoint (writeContactData)
function createOrGetContactFolder(email, row) {
  const targetFolder = getOrCreateFolderPath(CONFIG.folderPath);
  const folderName = sanitizeEmailForFolder(email);

  // Check if folder already exists
  const existingFolders = targetFolder.getFoldersByName(folderName);
  if (existingFolders.hasNext()) {
    const existingFolder = existingFolders.next();
    const folderId = existingFolder.getId();
    // Find or create emails subfolder
    const emailsFolders = existingFolder.getFoldersByName('emails');
    let emailsFolderId = '';
    if (emailsFolders.hasNext()) {
      emailsFolderId = emailsFolders.next().getId();
    } else {
      // Create emails subfolder if missing (handles partial folder state)
      const emailsFolder = existingFolder.createFolder('emails');
      emailsFolderId = emailsFolder.getId();
    }
    storeFolderIdsInSheet(row, folderId, emailsFolderId);
    console.log(`Folder exists for ${email}, IDs: ${folderId}, ${emailsFolderId}`);
    return { folderId, emailsFolderId };
  }

  // Create new folder
  const contactFolder = targetFolder.createFolder(folderName);
  const folderId = contactFolder.getId();
  contactFolder.createFile('README.md', createReadmeContent(), MimeType.PLAIN_TEXT);
  const emailsFolder = contactFolder.createFolder('emails');
  const emailsFolderId = emailsFolder.getId();
  storeFolderIdsInSheet(row, folderId, emailsFolderId);
  console.log(`Created folder "${folderName}" for ${email}, IDs: ${folderId}, ${emailsFolderId}`);
  return { folderId, emailsFolderId };
}

// Wrapper for onEdit trigger (maintains backwards compatibility)
function createFolderForContact(email, name, row) {
  try {
    createOrGetContactFolder(email, row);
  } catch (error) {
    console.error(`Error creating folder for ${email}:`, error);
  }
}

// Store BOTH folder_id AND emails_folder_id in the sheet
function storeFolderIdsInSheet(row, folderId, emailsFolderId) {
  const sheet = getSpreadsheet().getSheetByName(CONFIG.sheetName);
  if (!sheet) return;

  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

  // Store folder_id
  const folderIdColIndex = headers.findIndex(h => h.toString().toLowerCase() === 'folder_id');
  if (folderIdColIndex >= 0) {
    sheet.getRange(row, folderIdColIndex + 1).setValue(folderId);
  } else {
    console.log('folder_id column not found in sheet headers');
  }

  // Store emails_folder_id
  const emailsIdColIndex = headers.findIndex(h => h.toString().toLowerCase() === 'emails_folder_id');
  if (emailsIdColIndex >= 0) {
    sheet.getRange(row, emailsIdColIndex + 1).setValue(emailsFolderId);
  } else {
    console.log('emails_folder_id column not found in sheet headers');
  }
}

// Create README.md content with YAML frontmatter (minimal - no data duplication)
function createReadmeContent() {
  return `---
name: ContactManager-Record
description: Most salient summary of the person that contacted me.
---

`;
}

// Helper to create/navigate folder path
function getOrCreateFolderPath(pathArray) {
  let currentFolder = DriveApp.getRootFolder();

  for (const folderName of pathArray) {
    const subfolders = currentFolder.getFoldersByName(folderName);
    if (subfolders.hasNext()) {
      currentFolder = subfolders.next();
    } else {
      currentFolder = currentFolder.createFolder(folderName);
    }
  }

  return currentFolder;
}

// ============================================================
// APPS SCRIPT EXECUTION API ENDPOINT
// ============================================================
// Called by n8n via Apps Script Execution API (uses OAuth, secure)
// Deploy: Deploy → New deployment → API Executable
// n8n calls: POST https://script.googleapis.com/v1/scripts/{scriptId}:run
// Body: { "function": "writeContactData", "parameters": [{ email, name, ... }] }

function writeContactData(data) {
  // Acquire script-level lock to prevent race conditions (concurrent calls creating duplicate rows)
  const lock = LockService.getScriptLock();
  const lockAcquired = lock.tryLock(30000); // Wait up to 30 seconds

  if (!lockAcquired) {
    return {
      status: 'error',
      error: 'Could not acquire lock - another request is in progress. Please retry.'
    };
  }

  try {
    const email = data.email;

    if (!email || !isValidEmail(email)) {
      throw new Error('Valid email is required');
    }

    logToSheet('INFO', 'writeContactData', 'Request received', { email, fieldCount: Object.keys(data).length });

    const sheet = getSpreadsheet().getSheetByName(CONFIG.sheetName);
    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

    // 1. Find existing row by email, or get next empty row
    const emailColIndex = headers.findIndex(h => h.toString().toLowerCase() === 'email');
    if (emailColIndex === -1) {
      throw new Error('email column not found in sheet headers');
    }

    const allData = sheet.getDataRange().getValues();
    let rowIndex = allData.findIndex((row, i) => i > 0 && row[emailColIndex] === email);
    let rowNumber;
    let action;

    if (rowIndex === -1) {
      rowNumber = sheet.getLastRow() + 1;
      action = 'created';
      logToSheet('INFO', 'writeContactData', 'Creating new row', { rowNumber });
    } else {
      rowNumber = rowIndex + 1;
      action = 'updated';
      logToSheet('INFO', 'writeContactData', 'Updating existing row', { rowNumber });
    }

    // 2. Write all fields to matching columns
    let fieldsWritten = 0;
    for (const [key, value] of Object.entries(data)) {
      const colIndex = headers.findIndex(h => h.toString().toLowerCase() === key.toLowerCase());
      if (colIndex !== -1 && value !== undefined && value !== null) {
        sheet.getRange(rowNumber, colIndex + 1).setValue(value);
        fieldsWritten++;
      }
    }
    logToSheet('INFO', 'writeContactData', `Wrote ${fieldsWritten} fields`, { rowNumber });

    // 3. Create folder if email exists and folder_id is empty
    const folderIdColIndex = headers.findIndex(h => h.toString().toLowerCase() === 'folder_id');
    let folderId = '';
    let emailsFolderId = '';

    if (folderIdColIndex !== -1) {
      folderId = sheet.getRange(rowNumber, folderIdColIndex + 1).getValue() || '';
    }

    if (!folderId) {
      logToSheet('INFO', 'writeContactData', 'Creating folder', { email });
      const result = createOrGetContactFolder(email, rowNumber);
      folderId = result.folderId;
      emailsFolderId = result.emailsFolderId;
    } else {
      const emailsIdColIndex = headers.findIndex(h => h.toString().toLowerCase() === 'emails_folder_id');
      if (emailsIdColIndex !== -1) {
        emailsFolderId = sheet.getRange(rowNumber, emailsIdColIndex + 1).getValue() || '';
      }
      if (!emailsFolderId) {
        try {
          const folder = DriveApp.getFolderById(folderId);
          const emailsFolders = folder.getFoldersByName('emails');
          if (emailsFolders.hasNext()) {
            emailsFolderId = emailsFolders.next().getId();
            storeFolderIdsInSheet(rowNumber, folderId, emailsFolderId);
          }
        } catch (e) {
          logToSheet('WARN', 'writeContactData', 'Could not find emails folder', { folderId, error: e.message });
        }
      }
    }

    logToSheet('INFO', 'writeContactData', 'Success', { action, rowNumber, folder_id: folderId, emails_folder_id: emailsFolderId });

    // Return object directly (Execution API returns this as JSON)
    return {
      status: 'success',
      action: action,
      row_number: rowNumber,
      folder_id: folderId,
      emails_folder_id: emailsFolderId
    };

  } catch (error) {
    logToSheet('ERROR', 'writeContactData', error.message, data);
    return {
      status: 'error',
      error: error.message
    };
  } finally {
    // Always release the lock
    lock.releaseLock();
  }
}

// Test writeContactData from Apps Script editor
function testWriteContactData() {
  const result = writeContactData({
    email: "api-test@example.com",
    name: "API Test User"
  });
  console.log(JSON.stringify(result, null, 2));
}

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

// Utility function to manually create folders for existing contacts
// Run this from the script editor to process existing rows
function processExistingContacts() {
  const sheet = getSpreadsheet().getSheetByName(CONFIG.sheetName);
  if (!sheet) {
    console.log(`${CONFIG.sheetName} sheet not found`);
    return;
  }

  const data = sheet.getDataRange().getValues();
  let created = 0;
  let skipped = 0;

  // Find email column dynamically
  const emailColIndex = getColumnByHeader(CONFIG.sheetName, CONFIG.observedColumn) - 1; // 0-based
  const NAME_COL = 0;  // Column A

  // Skip header row (index 0)
  for (let i = 1; i < data.length; i++) {
    const name = data[i][NAME_COL];
    const email = data[i][emailColIndex];

    if (email && isValidEmail(email.toString())) {
      try {
        const targetFolder = getOrCreateFolderPath(CONFIG.folderPath);
        const folderName = sanitizeEmailForFolder(email.toString().trim());
        const existingFolders = targetFolder.getFoldersByName(folderName);

        if (!existingFolders.hasNext()) {
          createFolderForContact(email.toString().trim(), name ? name.toString().trim() : '', i + 1);
          created++;
        } else {
          skipped++;
        }
      } catch (error) {
        console.error(`Error processing row ${i + 1}:`, error);
      }
    }
  }

  console.log(`Done! Created: ${created}, Skipped (existing): ${skipped}`);
}
