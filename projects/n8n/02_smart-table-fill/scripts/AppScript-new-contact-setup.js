// Google Apps Script - Contact Manager with Auto Folder & MD File Creation
// SETUP: Run this script once, then use the menu "Folder Automation" > "Setup Auto-Folder Creation"
// NOTE: Uses EMAIL as the unique identifier and folder name

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
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  ScriptApp.newTrigger('onSpreadsheetEdit').forSpreadsheet(ss).onEdit().create();

  SpreadsheetApp.getUi().alert(
    '✅ Auto-folder creation is now active!\n\n' +
    'Folders will be created at:\n' +
    'My Drive/PrivateD/Contact_Manager/names_folders/{email}/\n\n' +
    'Each folder will contain:\n' +
    '- README.md (ContactManager-Record)\n' +
    '- emails/ subfolder'
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
  if (sheet.getName() !== 'Entries') return;

  const col = e.range.getColumn();
  const row = e.range.getRow();

  // Column B = email (the unique identifier) - adjust if your email column is different
  const EMAIL_COLUMN = 2;

  if (col === EMAIL_COLUMN) {
    const email = e.range.getValue();
    if (email && email.toString().trim() !== '' && email.includes('@')) {
      // Get name from column A (for display in README)
      const name = sheet.getRange(row, 1).getValue() || '';
      createFolderForContact(email.toString().trim(), name.toString().trim(), row);
    }
  }
}

// Create folder with markdown files for a contact
function createFolderForContact(email, name, row) {
  try {
    // Navigate to: My Drive/PrivateD/Contact_Manager/names_folders
    const targetFolder = getOrCreateFolderPath(['PrivateD', 'Contact_Manager', 'names_folders']);

    // Folder name is sanitized email
    const folderName = sanitizeEmailForFolder(email);

    // Check if folder already exists
    const existingFolders = targetFolder.getFoldersByName(folderName);
    if (existingFolders.hasNext()) {
      // Folder exists - this is fine for emails (same contact, no error)
      console.log(`Folder already exists for ${email}`);
      return;
    }

    // Create new folder
    const contactFolder = targetFolder.createFolder(folderName);
    const folderId = contactFolder.getId();
    const createdDate = new Date().toISOString();

    // Create README.md
    const readmeContent = createReadmeContent(email, name, createdDate);
    contactFolder.createFile('README.md', readmeContent, MimeType.PLAIN_TEXT);

    // Create emails subfolder
    contactFolder.createFolder('emails');

    // Store folder_id back to the sheet (optional - add column for folder_id)
    // Uncomment and adjust column index if you want to track folder IDs:
    // const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Entries');
    // sheet.getRange(row, FOLDER_ID_COLUMN).setValue(folderId);

    console.log(`Created folder "${folderName}" for ${email} with ID: ${folderId}`);

  } catch (error) {
    console.error(`Error creating folder for ${email}:`, error);
  }
}

// Create README.md content with YAML frontmatter
function createReadmeContent(email, name, createdDate) {
  return `---
name: ContactManager-Record
description: Most salient summary of the person that contacted me.
contact_email: ${email}
contact_name: ${name}
created: ${createdDate}
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

// Utility function to manually create folders for existing contacts
// Run this from the script editor to process existing rows
function processExistingContacts() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Entries');
  if (!sheet) {
    console.log('Entries sheet not found');
    return;
  }

  const data = sheet.getDataRange().getValues();
  let created = 0;
  let skipped = 0;

  // Column indices (0-based) - adjust if your columns are different
  const NAME_COL = 0;  // Column A
  const EMAIL_COL = 1; // Column B

  // Skip header row (index 0)
  for (let i = 1; i < data.length; i++) {
    const name = data[i][NAME_COL];
    const email = data[i][EMAIL_COL];

    if (email && email.toString().trim() !== '' && email.includes('@')) {
      try {
        const targetFolder = getOrCreateFolderPath(['PrivateD', 'Contact_Manager', 'names_folders']);
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
