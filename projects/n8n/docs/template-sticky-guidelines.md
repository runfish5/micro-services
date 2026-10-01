# n8n template guidelines: sticky notes and node names

**Read this before creating or annotating any workflow.** It is what the n8n creator portal checks
before a template is published. Source: n8n's
[Sticky note guidelines for templates](https://n8n.notion.site/Sticky-note-guidelines-for-templates-2aa5b6e0c94f8058b0aefddd02655887)
and their official auto-annotation template
[13868](https://n8n.io/workflows/13868-auto-generate-sticky-notes-and-rename-nodes/) (captured 2026-09-30).

## Sticky notes (official)

| Kind | Required? | Color | Content | Placement |
|---|---|---|---|---|
| **Main overview** | exactly one | yellow (default, no `color`) | 100–300 words. `### How it works` + `### Setup`, optional `### Customization` | top-left of the canvas |
| **Section** | yes, for 4+ nodes | white (`color: 7`) | under 50 words: a `## Heading` + 1–2 short lines | stretched over **several** nodes |
| **Warning** | optional, use sparingly | red (`color: 3`) | a critical setup step or risk | over **one** node only |
| **Video** | optional, recommended | any | `@[youtube](VIDEO_ID)` | anywhere |

Details the official generator uses:

- **Main sticky:** width 480, `## <Workflow name>`, then `### How it works` as a numbered list of 2–6 items
  (third person, one sentence each), then `### Setup steps` as `- [ ]` checkboxes (credentials and
  configuration). Placed 80 px left of the leftmost section, top-aligned.
- **Section titles:** 3–6 words, sentence case ("Fetch and validate data"). Ordered by execution
  flow. Nodes that belong together logically *and* sit together on the canvas share one section.
  Aim for roughly one section per 3 nodes.
- Positions and sizes snap to a 16 px grid.

## Node names (from the official generator)

Title Case, under 40 characters, unique, letters/numbers/spaces/hyphens only, verb first where
possible.

| Node | Pattern | Example |
|---|---|---|
| Trigger | "When [event]" | When Email Received |
| HTTP Request | "[Verb] [what]" | Fetch Mailbox Profile |
| Set | "Set / Prepare / Build [what]" | Set Backfill Options |
| If | "If [condition]" / "Check [what]" | If Snapshot Needed |
| Switch | "Route by [criteria]" | Route by Document Type |
| Code | "[Verb] [what]" | Compare Snapshot to Mailbox |
| Filter | "Filter [criteria]" | Filter Backfill Runs |
| Google Sheets | "[Action] in Sheets" | Append Invoice to Sheets |
| Split Out | "Split [what]" | Split Label Changes |

**Renaming is not free here.** Code nodes and expressions reference nodes by name
(`$('Config')`), and n8n does not rewrite names inside Code strings. Rename only when every
reference is updated in the same edit, and re-check with
`grep "\$('Old Name')"` over the JSON. Never let an automatic renamer loose on a live workflow.

## How this fits our own conventions (root `CLAUDE.md`)

| Ours | Official rule | Resolution |
|---|---|---|
| Blue sticky (5) behind each Execute Workflow node, listing its inputs | not covered | Keep: small, over one node, protects against n8n silently clearing `workflowInputs`. Title it `## Inputs` so a reviewer reads it as a note, not a section |
| Red sticky (3) "After import" on the Config node | Warning sticky, one node | Already compliant. Keep it on the Config node only |
| Section labels in black/white (7) | Section = white (7) | Same thing |
| Long explanations in stickies | Main ≤ 300 words, sections < 50 | Move depth into the project docs, and link from the main sticky |
