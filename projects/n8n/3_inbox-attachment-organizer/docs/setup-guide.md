## ⚡ Quick Start

**Time:** 60 minutes | **Difficulty:** Easy | **Cost:** Free

> ### ⚡ Setup Advantage
>
> **ONE Google OAuth connection** (Gmail + Drive + Sheets) — not 3-5 platforms.
> **Standard n8n cloud nodes only** — no self-hosted requirements.
> **Import and run immediately.**

### 1. Import Workflows
Download and paste these workflow clipboard :clipboard: content directly into your [n8n-browser-window](n8n.io) :
1. [inbox-manager-main.json](workflows/inbox-manager-main.json)
2.  [universal-document-parser.json](workflows/subworkflows/universal-document-parser.json)
3.  [drive-folder-path-resolver.json](workflows/subworkflows/drive-folder-path-resolver.json)
4. [auto-create-folder-structure.json](workflows/subworkflows/auto-create-folder-structure.json)
5. [gmail-systematic-processor.json](workflows/subworkflows/gmail-systematic-processor.json)

### 2. Setup Credentials
Only one authentication needed: **Google OAuth**

Follow: [credentials-guide.md](config/credentials-guide.md)

### 3. Create Google Sheet
Create a Google Sheet named **"2505_Invoices"** with these exact column headers:
```
supplier_name | supplier_address | invoice_date | total_amount_due | currency_code |
subtotal_amount | recipient_business_name | payment_method | date_paid | payment_reference
```

Place this sheet at the root of your Google Drive accounting folder (e.g., `/Accounting/2505_Invoices`)

### 4. Activate
- Send test email with invoice attachment
- Check Google Drive for auto-created folders
- **For existing emails:** Run the `gmail-systematic-processor` workflow to process all emails already in your mailbox (the Gmail trigger only catches new incoming emails)
- Activate Gmail trigger ✅

**Note:** Google Drive folders will be auto-created in this structure:
```
/Accounting/
  └─ 2025/
      └─ 05_May/
          ├─ Revenue/
          └─ Expense/
```

## 🌟 Use Cases

**Out-of-the-box:** Financial documents (invoices, receipts)

**Extend to:**
- Legal contracts (Contracts/ClientName/YYYY/)
- HR documents (Personnel/EmployeeName/)
- Project files (Projects/ProjectName/Deliverables/)