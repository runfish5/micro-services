# 17. Site Forms

One webhook, `POST /webhook/reach`, for what a website's forms say: a contact message, or a
newsletter request with **double opt-in**.

- A **contact message** is stored in a `Messages` tab, one row per message, and the sender is
  added to the contact book (`Entries`) in the group `contact`.
- A **newsletter request** mails one confirmation link, from a no-reply address on your own
  domain through a transactional mail API, and waits as `pending` in a `Subscribers` tab. The
  link opens a page on your own site; pressing the button there confirms, and the address joins
  `Entries` in the group `newsletter`. The same token unsubscribes.
- Nothing pings Telegram. The **morning briefing** has a `SITE INBOX` section that prints
  yesterday's messages in full and who asked, confirmed or left. This workflow renders that
  section itself; the briefing calls it by id (one line in its `Plugins` node).
- The door answers only after the row is written (and, for a newsletter request, after the
  mail is sent), so the site can tell a visitor honestly whether it worked.
- The door listens only to a sender that holds the shared secret, sent as the `X-Forms-Secret`
  header. Anyone else gets `403`.

No workflow *sends* a newsletter yet. This is the list and its consent record.

## Files

| File | Purpose |
|------|---------|
| `workflows/site-forms.n8n.json` | Public copy, placeholders (`YOUR_*`, `CREDENTIAL_ID_*`) |
| `workflows/site-forms.local.n8n.json` | Gitignored import copy with the real bindings |

## What your site needs

Two things: a server-side forwarder that POSTs `{ kind, email, name, message, path, token }`
here with the secret header, and a page for the mailed link that POSTs
`{ kind: 'confirm' | 'unsubscribe', token }` through that forwarder when its button is pressed.
The forwarder mints the token for a newsletter request; the workflow refuses a request without
one. Setup steps are on the yellow sticky note in the workflow; the design notes are in
[`CLAUDE.md`](CLAUDE.md).

| Tab | Grain | Columns |
|-----|-------|---------|
| `Messages` | one row per contact-form message, append-only | `ts, email, name, message, path` |
| `Subscribers` | one row per address: the consent record | `email, state, token, requested_at, path, confirmed_at, unsubscribed_at, mails` |

Both tabs sit in the document that [`15_site-visits`](../15_site-visits/README.md) writes
`Visits` to. The contact book is the `Entries` sheet of [`02_smart-table-fill`](../02_smart-table-fill/).

## If your site is on Vercel: the sender in six steps

The confirmation mail needs a sender on your own domain, such as `no-reply@example.com`.
A Vercel project can get one without opening another account by hand:

1. **Provision the mail service from the Vercel CLI**, inside the linked project:
   `vercel integration add resend/resend-email --plan free -m domain=example.com -m region=eu-west-1 -e production`.
   The first run asks you to accept the provider's terms (`vercel integration accept-terms resend`).
   Vercel creates the account, bills it with your project, and stores `RESEND_API_KEY` as a
   production environment variable.
2. **Verify the domain.** The service lists three DNS records: one DKIM `TXT` at
   `resend._domainkey`, and an `MX` plus an SPF `TXT` at `send`. Add them wherever your DNS is
   hosted, which is not necessarily Vercel. They sit on subdomains, so existing mail routing on the
   apex is untouched. Until they verify, every send is refused and the form says "not saved".
3. **Give n8n the key.** Read it once with `vercel env pull --environment=production` into a file
   outside the repo, then create an n8n **Header Auth** credential with name `Authorization` and
   value `Bearer <key>`. Delete the pulled file.
4. **Bind it** to `Send Confirmation Mail` and set `mail_from` in `Set Site Config` to the
   no-reply address on the verified domain.
5. **Share a secret.** Generate a long random value, store it in an n8n **Header Auth** credential
   with name `X-Forms-Secret` bound to `When Form Is Sent`, and store the same value as a
   server-only variable on the Vercel project.
6. **Point the site at the door.** Store the `reach` webhook's production URL as a second
   server-only variable and redeploy; a Vercel variable only takes effect on the next deployment.

The mail key lives in two places, Vercel and n8n, and the site itself never uses it: n8n sends the
mail so that "mail first, then the row" stays one transaction the form can report honestly.
Any other transactional mail API works the same way; only the URL in `Send Confirmation Mail` and
the DNS records differ.
