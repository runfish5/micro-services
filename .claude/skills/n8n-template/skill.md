---
name: n8n-template
description: Make an n8n workflow compliant with n8n's template rules (stickies, node names, portal fields) before submitting it to the creator portal.
user_invocable: true
---

# n8n template compliance

Usage: `/n8n-template <workflow.json>`. The rules live in
`projects/n8n/docs/template-submission.md`; read it first. This skill is the procedure only.

1. **Re-fetch the guideline.** POST `loadPageChunk` for the Notion page (recipe in the doc) and
   compare it with the doc's rules. If a rule changed, update the doc and
   `scripts/n8n-template.js` before touching the workflow. If the fetch fails, say so and proceed
   on the doc.
2. **Check.** `npm run wf:template-check -- <workflow.json>`. The list of violations is the work.
3. **Rebuild the stickies** per the doc: one yellow main sticky (width 480, top-left, 100–300
   words, `### How it works` + `### Setup steps` checkboxes, GitHub link), white `## Sentence case`
   sections under 50 words over several nodes without overlap, a red warning only over a single
   node whose miss silently breaks the run. Move input lists and per-node gotchas into the
   node's Notes (`notes`, `notesInFlow: false`); move setup notes into `### Setup steps`; move
   long text into the project docs.
4. **Rename.** Draft `{old: new}` in a scratch map file following the naming table, then
   `npm run wf:template-rename -- <workflow.json> <map.json>`. Grep the other workflow JSONs for
   the old names first: the error handler reads run data by node name.
5. **Update the docs that name nodes**: the project's `mainflow.md`, `CLAUDE.md`, setup guide,
   and every other file a grep for the old names finds.
6. **Write `docs/template-listing.md`**: the portal fields as they will be pasted, each with its
   word count against the doc's limits.
7. **Check again** until it exits 0. Then grep the JSON for the SECURITY list (root `CLAUDE.md`).

Never commit. The operator re-imports the JSON into n8n, looks over the canvas and uploads.
