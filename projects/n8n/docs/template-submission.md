# n8n template submission: stickies, node names, portal fields

**The single source for template rules.** Read it before creating, annotating or submitting a
workflow. `npm run wf:template-check -- <workflow.json>` checks the mechanical part; the
`/n8n-template` skill runs the whole procedure.

## Sources and re-verify step

- n8n's [Sticky note guidelines for templates](https://n8n.notion.site/Sticky-note-guidelines-for-templates-2aa5b6e0c94f8058b0aefddd02655887)
- n8n's auto-annotation template [13868](https://n8n.io/workflows/13868-auto-generate-sticky-notes-and-rename-nodes/)
  (JSON: `https://api.n8n.io/api/templates/workflows/13868`), whose prompts and "Apply Renames"
  code define the naming patterns and the rename logic.
- Captured 2026-09-14.

**Re-verify before every submission.** The Notion page renders through JavaScript, so a plain
fetch returns nothing. Read it through Notion's page API:

```bash
curl -s -X POST https://n8n.notion.site/api/v3/loadPageChunk \
  -H 'content-type: application/json' \
  -d '{"pageId":"2aa5b6e0-c94f-8058-b0ae-fddd02655887","limit":100,"cursor":{"stack":[]},"chunkNumber":0,"verticalColumns":false}'
```

The text sits in `recordMap.block.*.value.properties.title`. If a rule changed, update this file
first, then `scripts/n8n-template.js`, then the workflow.

## Sticky notes

| Kind | Count | Color | Content | Placement |
|---|---|---|---|---|
| **Main** | exactly one | yellow: `color` unset or `1` | 100–300 words: `## Title`, `### How it works`, `### Setup steps`, optional `### Customization` | top-left of every node and sticky |
| **Section** | required at 4+ nodes | white: `color: 7` | under 50 words: `## Sentence case title` (3–6 words) + 1–2 lines | over **several** nodes, no overlap (32 px gap) |
| **Warning** | sparingly | red: `color: 3` | one critical setup step or risk | over **one** node only |
| **Video** | optional | any | `@[youtube](VIDEO_ID)` | anywhere |

No other color is allowed. Details from 13868:

- **Main sticky:** width 480. `### How it works` is a numbered list of 2–6 items, third person,
  one sentence each. `### Setup steps` is a list of `- [ ]` checkboxes (credentials and
  configuration). End with the GitHub link. No model or provider names.
- **Section stickies:** ordered by execution flow; nodes that belong together logically *and* sit
  together on the canvas share one section, roughly one section per 3 nodes. Positions and sizes
  snap to a 16 px grid.

## Where our old conventions go now

The old scheme (orange setup notes, blue input notes, `#` subunit labels, several yellow notes) is
**deprecated**. Legacy stickies in other workflows are migrated the next time that workflow is
edited.

| Was | Now |
|---|---|
| Blue sticky behind an Execute Workflow node listing its inputs | The node's **Notes** (`notes`, `notesInFlow: false`): the inputs, one `name: value` per line. Notes ride on the node, never count as stickies, and survive n8n silently clearing `workflowInputs` |
| Per-node gotcha in a small sticky | The node's **Notes** |
| Orange/red "after import" or "select your sheet" notes | A `- [ ]` line in the main sticky's `### Setup steps` |
| A setup step that silently breaks the run if missed, on one node | One red warning sticky over that node |
| Long explanations, schemas, paste-in header rows | The project docs on GitHub, linked from the main sticky |

## Node names

Title Case, under 40 characters, unique, only letters, digits, spaces and hyphens, starting with a
verb. Never a bare default (`If`, `Merge`, `Gmail`, `Code`, `Switch`, `Set`, …) and never a copy
digit (`Any LM1`).

| Node | Pattern | Example |
|---|---|---|
| Trigger | "When [event]" | When Email Received |
| Execute Workflow Trigger | "When Called [by/for what]" | When Called for Catch-up |
| HTTP Request | "[Verb] [what]" | Fetch Mailbox Profile |
| Set | "Set / Prepare / Build [what]" | Build Folder Path |
| If | "If [condition]" | If Has Attachments |
| Switch | "Route by [criteria]" | Route by Email Category |
| Code | "[Verb] [what]" | Prepare Ledger Row |
| Filter | "Filter [criteria]" | Filter by Sender Whitelist |
| Google Sheets | "[Action] in Sheets" | Upsert Ledger Row in Sheets |
| Split Out | "Split [what]" | Split Attachments |
| Execute Workflow | what the call achieves, not the subworkflow's name | Find or Create Drive Folder |
| LLM sub-node | its **role**, never the provider | Classifier LLM |
| Output parser | "[Role] Output Schema" | Classifier Output Schema |

**Rename only with `npm run wf:template-rename -- <workflow.json> <map.json>`.** n8n does not
rewrite names inside Code strings or expressions; the script rewrites node names, connection keys
and targets, `$('…')` / `$node["…"]` references and `pinData` keys in one pass, then `check`
confirms nothing dangles. It does not touch other workflows: grep them (the error handler reads
run data by node name) and the project docs for the old names.

## Portal fields

One file per submitted workflow, `docs/template-listing.md`, holds the fields exactly as they are
pasted into the creator portal, with word counts.

| Field | Limit |
|---|---|
| Title | names the integrations used (n8n's listing convention: the one place a product name is allowed) |
| Quick overview | 10–50 words |
| How it works | 50+ words |
| Setup | 50+ words |
| Requirements | list |
| Customization | short |
| Additional info | optional; the GitHub link |

Everywhere outside the Title, describe LLMs by capability ("LLM", "vision-capable LLM").

**The portal's AI drafts every field from the uploaded JSON and names each LLM node's provider**,
in the title too ("… with Groq", "… with Groq and Google Gemini"), and the title cannot be edited
afterwards. So swap every LLM node to the OpenRouter chat model node **before** uploading: the
provider is then the importer's choice, and no specific vendor lands in the listing.

Wrong titles are fixed in **one** email to n8n, sent after all planned workflows (7–8) are
submitted. Until then each listing file records its wanted title under `## Title`.

## Pre-submit checklist

- [ ] Every LLM node is the OpenRouter chat model node (no Groq, Gemini or other vendor node).
- [ ] The Notion guideline was re-fetched and this file still matches it.
- [ ] `npm run wf:template-check -- <workflow.json>` exits 0.
- [ ] The JSON holds only SECURITY placeholders (root `CLAUDE.md`): no credential IDs, chat IDs,
      sheet IDs, keys or instance URL.
- [ ] `docs/template-listing.md` word counts are inside the limits above.
- [ ] The workflow was re-imported into n8n and the canvas looked over: one yellow sticky top-left,
      white groups without overlap, notes visible in node settings.
- [ ] The JSON the portal generates is never uploaded unread: it has replaced the stickies with an
      empty "Untitled workflow" note before.
