# n8n Troubleshooting

## Subworkflows Not Reflecting Changes

Execution behaves differently than when you tested? You tested the subworkflow directly, not via the parent - and forgot to republish.

**Fix**: Republish the subworkflow.


If publish button won't work (an error like *1 node has issues, fix them before publishing.*):

<img src="assets/trouble-shooting-publish-error1.png" width="300">

1. Go to Executions
2. Pick a successful run → Copy to Editor
3. Publish

This works because the execution data fills in whatever n8n thinks is missing.

---

## LLM Structured Output Errors

Error: "Model output doesn't fit required format" or empty error `{}` in error handler.

**Cause**: The LLM failed to return valid JSON matching the required schema. Smaller or older models struggle with structured output.

**Fix**: Use a model with better structured output support:
- **OpenAI gpt-oss-120b** - Best open-source model for structured output (as of Jan 2026)
- Simplify the schema if possible (fewer required fields, simpler nesting)

---

## Apps Script Execution API

### 404 "Requested resource/entity was not found"

- **Most common:** You're using Script ID instead of Deployment ID
- **Fix:** Get the Deployment ID from Deploy > Manage deployments (starts with `AKfycb...`)

### 403 Permission Errors (incl. GCP Project Migration)

Switched to a new GCP project but kept the same Apps Script? This is the most common cause:

1. **Re-link Apps Script** — script.google.com → Project Settings → Change project → enter new **Project Number** (not ID)
2. **Re-authorize locally** — run `testWriteContactData()` from the Apps Script editor → accept OAuth consent for the new project
3. **Re-enable API** — GCP Console → APIs & Services → enable **Apps Script API** in the new project
4. **Reconnect n8n credential** — Disconnect → Reconnect the Google OAuth2 API credential (clears cached token)

Still 403? Verify all 3 scopes in `appsscript.json` match the n8n credential. See [credentials-guide.md](credentials-guide.md#403-troubleshooting) for the full table.

### Dataset Size Limitation

The Apps Script loads the entire sheet into memory to find rows:
- Works well for sheets < 5,000 rows
- May timeout or fail on very large sheets (10,000+ rows)
- Apps Script has 6-minute execution limit and ~6MB heap

---

## Rate Limit Errors (HTTP 429)

Error: "Rate limit exceeded" when using free-tier APIs (e.g., Groq 5 req/min).

**Fix**: Add a Split In Batches + Wait loop before your LLM node. Set batch size to your API's requests-per-minute limit, wait time to 60s.

**Workflow-specific:**

- **smart-table-fill**:
  1. Disconnect "Build Output Schema" → "Extract Data from String"
  2. Add **Split In Batches** node (Batch Size: 5)
  3. Add **Wait** node (60 seconds)
  4. Wire: `Build Output Schema → Split In Batches → Extract Data from String → Wait → (loop back to Split In Batches)`
  5. Connect Split In Batches **second output** (done) → "Merge Outputs"

---

## "Referenced node doesn't exist" After Import

Error: `Referenced node doesn't exist` with stack trace pointing to `workflow-data-proxy.js`.

**Cause**: Re-importing a workflow without deleting the old one first. n8n appends `1` to
colliding node names (`AI Classifier` → `AI Classifier1`) but expressions like
`$node['AI Classifier']` still reference the original name.

**Prevention**: Delete the old workflow before importing the updated version.

**Fix**:
1. Open the workflow in the n8n editor
2. Find nodes with `1` suffix (e.g., `AI Classifier1`, `Brave Search1`)
3. Either rename them back (remove the `1`) or update all `$node['...']` expressions to match
4. Save and republish

---

## Google OAuth "Client Authentication Failed"

<img src="assets/trouble-shooting-oauth-client-auth-failed.png" width="500">

OAuth callback fails with **"Client authentication failed"** when connecting a Google service in n8n.

The downloaded credential JSON filename contains the Client ID (e.g., `client_secret_000-000.apps.googleusercontent.com.json`). **Fix**: Check that the Client Secret in n8n matches the one for this Client ID in Cloud Console.
