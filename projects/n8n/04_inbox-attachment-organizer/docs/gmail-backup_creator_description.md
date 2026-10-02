# Back up your whole Gmail to Google Drive, verify it, and restore from it

Before you let an automation loose on your inbox, take a copy you can go back to. This workflow
saves every email as an `.eml` file in your Drive, plus all labels, proves the copy is complete,
and restores from it through a form.

> ### 🛡️ Why This Workflow Is Safe to Run on Your Real Inbox
>
> * **The backup only reads.** It never deletes, moves or edits an email.
> * **Verified, not assumed.** Every email is saved as a complete `.eml` file (text, attachments, headers), plus all labels. The run stops with an error unless the copy matches the mailbox.
> * **Gentle on your n8n.** Emails go straight from Gmail to Drive in small chunks. They are never stored in n8n's own database, and the chunk runs keep no history.
> * **New mail stays safe.** A restore only touches emails that existed at backup time. Deleted emails come back from their `.eml`.
> * **Your own changes stay safe.** A restore only resets the labels you list. What you read, starred or archived stays as you left it.
> * **No accidental restore.** Restore has its own form. It shows exactly what will change and waits until you type `RESTORE <count>`.

**Good to know**

* Reading the mailbox takes about 3 minutes per 800 emails.
* The first backup takes about 10 seconds per 25 emails. Later runs only add new emails.
* Emails over 8 MB are not fetched automatically. The result names them: download them in Gmail and drop them into the `gmail-backup` folder.
* A restore does not remove files or sheet rows that another workflow created in the meantime.

# How it works

1. Saves every email not yet backed up as an `.eml` file in Google Drive, 25 per chunk.
2. Saves all labels as a JSON snapshot, reads it back and compares it with the mailbox and with Gmail's own count. The run stops if anything is missing.
3. `verify` shows exactly which labels changed since a snapshot.
4. The separate restore form sets the labels back and imports deleted emails again.

# Set up steps

* Connect one Google account in n8n (Gmail and Google Drive).
* Optionally set `backup_folder_id` in **Config**. The default `root` saves snapshots to the top of My Drive.
* Publish the workflow: it calls itself to save emails in chunks.
* Run it. You should see `verified: true`, a `gmail-backup` folder and a snapshot file in Drive.

# Requirements

* Gmail and Google Drive, through one Google OAuth credential

# Customising this workflow

* Change `RESTORE_LABELS` in **Compute Restore Plan** to choose which labels a restore resets. The default is the three labels of the [inbox attachment organizer](https://github.com/runfish5/micro-services/tree/main/projects/n8n/04_inbox-attachment-organizer); an empty list restores every label.
* Set `scope` in **Config** to a Gmail search to back up only part of the mailbox.

---

📂 **[Full documentation & source code](https://github.com/runfish5/micro-services/blob/main/projects/n8n/04_inbox-attachment-organizer/docs/gmail-backup.md)**
