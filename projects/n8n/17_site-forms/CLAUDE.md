# CLAUDE.md — `17_site-forms`

**Live since 2026-10-12** as its own workflow. It started on 2026-10-11 as a third door inside
`shared/signup-intake` and was moved out the next day: it shared that workflow's spreadsheets and
nothing else, and a public template has one job.

```
When Form Is Sent → Set Site Config → Validate Form → Route by Kind
   contact     → Append Message Row (raw HTTP) → Respond Saved → Build Contact From Message ──┐
   newsletter  → Get Subscriber List in Sheets → Plan Confirmation Mail → If Mail Is Due      │
                    yes → Write Confirmation Mail → Send Confirmation Mail                    │
                          → Upsert Subscriber in Sheets → Respond Pending                     │
                    no  → Respond Pending                                                     │
   token       → Find Subscriber by Token → Decide Token Change → If Token Is Valid           │
                    yes → Update Subscriber in Sheets → Respond Done → If State Changed       │
                             yes → Build Contact From Subscription ───────────────────────────┤
                    no  → Respond Invalid (422)                                               ▼
   invalid     → Respond Invalid       Find Contact in Sheets + Combine Change With Contact
                                          → Prepare Contact Row → Upsert Contact in Sheets

When Called for Briefing → Get Messages in Sheets → Get Subscribers for Briefing → Build Briefing Section
```

`Subscribers.state`: `pending` → `confirmed` → `unsubscribed`. Asking again after unsubscribing
starts over at `pending` with a fresh token.

Design facts, each with the failure it prevents:

- **The webhook has header auth.** Without it anyone who learned the address could post
  `kind: confirm` with a token of their own choosing and walk past the double opt-in.
- **The workflow stamps the time; the sender only mints the token.** The resend limit and the
  link's age are counted from `received_at`, so a sender-supplied time would let a caller reset
  both. A newsletter request without a valid token is refused: there is no second mint here.
- **This door answers after the write.** A visitor typed this, so the sender must be able to say
  "not saved" and mean it. For a newsletter request the answer waits for the mail too. The order
  is mail, then row: if the row were written first and the mail failed, the retry would find a
  fresh `pending` row and send nothing.
- **Nothing here pings Telegram**, by operator decision. The briefing section is the only
  announcement, so it prints each message in full instead of a count.
- **`Plan Confirmation Mail` is an abuse gate, not a convenience.** The form is public and takes
  any address. A confirmed address gets no mail; a pending one at most one per `resend_after_h`
  and `max_mails_unconfirmed` in total; the whole list at most `max_mails_per_hour`. The count
  lives in the `mails` column and survives a new request, so asking again does not reset it. The
  answer is the same in every case so the form cannot be used to test who is on the list.
- **The mailed link opens a page on the sender's site, never an n8n URL.** That page shows a button
  and POSTs the token back through the sender as `kind: confirm` or `unsubscribe`. A GET that
  changed state would be triggered by every mail scanner that follows links, and a link into n8n
  would publish the instance host to every subscriber.
- **A confirm link expires after `confirm_within_days`; an unsubscribe link never does.** An old
  confirm link does not revive an unsubscribed address either. `Decide Token Change` answers
  "invalid" for both.
- **`Update Subscriber in Sheets` is `update`, matched on `token`.** An upsert here would append a
  row for a token that matched nothing.
- **A repeated confirm or unsubscribe is a quiet yes that changes nothing.** `If State Changed`
  keeps a replayed link from rewriting the contact book.
- **The contact book learns only what changed.** `Prepare Contact Row` emits `groups`, `last_topic`
  and `contact_updated_at` for a known contact and a full row only for a new one;
  `Upsert Contact in Sheets` auto-maps, so it writes exactly those keys. A newsletter address joins
  `Entries` on **confirm**, not on request: an unconfirmed address may not be its owner's.
- **Sheets writes are `cellFormat: RAW`**, and the message append is the raw HTTP call with
  `insertDataOption=INSERT_ROWS`, for the reasons in `15_site-visits/README.md`. The two
  `Subscribers` writes go through the Sheets node, which reads before it writes: two requests for
  the *same* address in the same second can collide. Accepted at this volume.
- **`Find Contact in Sheets` matches `email` only.** A person filed under another address in
  `more_emails` gets a second row. `record-search` in project 02 is the fix if it matters.
- **The confirmation mail is plain text.** A consent mail has one job and should survive any mail
  client.
- **`Send Confirmation Mail` is an HTTP call to a transactional mail API, not the Gmail node.**
  Gmail can only send as the account that is bound, which puts a personal address in front of every
  subscriber. The sender is `mail_from` in `Set Site Config`, a no-reply address on the site's own
  domain. That domain has to be verified with the mail service (DNS records) or every send is
  refused; a refused send fails the request, so the form says so.
- **Both briefing reads are `alwaysOutputData`, the second also `executeOnce`.** An empty
  `Messages` tab would otherwise stop the branch and the briefing would report a crashed plugin.
- **Successful executions are not saved** (`saveDataSuccessExecution: none`): they carry addresses
  and tokens. Failures still are, and go to the error workflow.
- **No workflow sends a newsletter yet.** When one exists it must read only `state = confirmed` and
  put `<confirm_page>?a=unsubscribe&t=<token>` in every mail.

## Two committed copies

`site-forms.n8n.json` is public and carries placeholders; `site-forms.local.n8n.json` is gitignored
and carries the real sheet ids and credentials. Keep them structurally identical.
