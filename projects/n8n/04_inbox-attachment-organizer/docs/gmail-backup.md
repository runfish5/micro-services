# Gmail Backup with Restore (`gmail-backup`)

Saves the whole mailbox to Google Drive, proves the copy is complete, and can put the mailbox back
the way it was. Run it before any job that changes many emails, for example before
[catching up the organizer](gmail-processor-datesize.md#catching-up-the-organizer). It calls no
other workflow and none calls it.

## What it does

`action` in **Config** picks the mode:

| `action` | Does | Changes Gmail? |
|---|---|---|
| `backup` (default) | saves every email as a complete `.eml` file in Drive (folder `gmail-backup`, only emails without a file yet, 25 per chunk), then every email's labels as a JSON snapshot. Reads the snapshot back and **stops with an error** unless both match the mailbox | no |
| `verify` | compares a snapshot with the mailbox as it is now and lists what changed | no |
| restore (own form trigger) | shows what would change, then, only after you type `RESTORE <count>`: resets the labels `n8n`, `gdr` and `inProgress`, and imports deleted emails back from their `.eml` with the labels they had. What you read or archived yourself, and mail that arrived after the backup, stay untouched | yes |

Other **Config** fields: `backup_folder_id` (where the snapshots go; `root` = top of My Drive),
`snapshot_file_id` (for `verify`), `scope` (optional Gmail search that limits the backup to part
of the mailbox; empty = everything).

**Three entry points on one canvas:** the button (backup or verify), the restore form, and
**When Saving Email Chunk**, which only the workflow itself calls, once per 25 emails. That
self-call keeps one run from holding the raw mailbox; it is why the workflow must be **published**.

## How to use it

1. **Back up.** Click ▶ on the trigger **When Clicking Execute** (not one of the other two). The output of **Compare Snapshot to Mailbox** shows
   `verified: true` and `snapshot_file_id`: note the ID.
2. **Do the job** you wanted the backup for.
3. **See what it changed** (optional): set `action: verify`, paste the ID into
   `snapshot_file_id`, click again.
4. **Undo it** (only if needed): click ▶ on **When Restore Requested**, open the form, enter the
   ID. It shows the changes and waits for `RESTORE <count>`.

A restore resets labels and brings deleted emails back. It does **not** remove files a workflow
saved to Drive or rows it wrote to a sheet.

## Good to know

- **Speed.** Reading the mailbox: about 3 minutes per 800 emails. First backup: about 10 seconds
  per 25 emails. Later runs only add new emails.
- **Emails over 8 MB are not backed up automatically.** The result lists them in
  `emails_too_large` (file name, subject, size): download each in Gmail (*Download message*) and
  drop it into `gmail-backup` under that file name.
- **Leave the mailbox alone while a backup runs** (a few minutes). If an email is deleted for good
  or a draft is edited between the listing and the fetch, the run stops with
  `Requested entity was not found`. Nothing is lost: click again.
- **Drafts are skipped on restore and verify.** Gmail gives a draft a new id on every edit, and a
  sent draft is gone.
- **Restore more or fewer labels:** change `RESTORE_LABELS` in **Compute Restore Plan**. Add
  `INBOX` if your workflow archives. An empty list restores every label.
- **Nothing is stored in n8n.** The chunk runs keep no history, on success or on failure, and an
  email goes from Gmail to Drive in one HTTP request, never through n8n's own file store. Keep
  both: `Save Email to Drive` is an HTTP request on purpose.
