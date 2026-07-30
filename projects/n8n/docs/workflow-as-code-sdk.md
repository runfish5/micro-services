# Workflow-as-Code with `@n8n/workflow-sdk`

Apply when a workflow is easier to change as typed TypeScript than as raw JSON — large refactors, bulk renames, restructuring branches, or just reading a dense topology. Stop reading if you're doing a small edit; do that in the n8n UI.

**Golden rule: the TypeScript is throwaway.** n8n UI/JSON is the single source of truth. Generated `.ts` is a scratch artifact — never committed (`.gitignore` blocks `*.workflow.ts` and `sdk-scratch/`). This does not replace "edit in UI, export JSON"; it's a power tool alongside it.

## Index

| Topic | Where |
|-------|-------|
| One-time setup | [Setup](#setup) |
| JSON → TS → JSON round-trip | [Commands](#commands) |
| How it maps to `mainflow.md` | [Relationship to mainflow.md](#relationship-to-mainflowmd) |
| Security | [Security](#security) |
| Why the official SDK (not n8n-kit) | [Package choice](#package-choice) |

## Setup

The SDK is a `devDependency` in the root `package.json`. Once per clone:

```bash
npm install
```

The SDK (`@n8n/workflow-sdk`, pinned to `0.23.2`) ships **no CLI**, so `scripts/n8n-sdk.js` wraps its two functions as npm scripts.

## Commands

```bash
# JSON -> TypeScript (read/refactor)
npm run wf:to-ts   -- projects/n8n/10_error-handler/workflows/010-error-handler.json sdk-scratch/eh.workflow.ts

# ...edit sdk-scratch/eh.workflow.ts...

# TypeScript -> JSON (build back)
npm run wf:from-ts -- sdk-scratch/eh.workflow.ts sdk-scratch/eh.json

# optional: structural validation of a JSON workflow
node scripts/n8n-sdk.js validate sdk-scratch/eh.json
```

Omit the output path to print to stdout. Then re-import `eh.json` into n8n the normal way (Import from File), publish, and **delete the scratch `.ts`**.

Under the hood these call `generateWorkflowCode(json)` and `parseWorkflowCode(tsString)` from the SDK.

### What the generated TypeScript looks like

Each node becomes a typed `node()` / `trigger()` const; expressions are wrapped in `expr()`, credentials in `newCredential()` (placeholder IDs preserved). The graph is a fluent chain that reads like the `mainflow.md` diagram:

```ts
const error_Trigger = trigger({ type: 'n8n-nodes-base.errorTrigger', version: 1,
  config: { name: 'Error Trigger', position: [-768, 592] } });

const runner_Infra_Down = node({ type: 'n8n-nodes-base.if', version: 2.2,
  config: { name: 'Runner/Infra Down?', parameters: { /* ... */ } } });

export default workflow('', '')
  .add(error_Trigger)
  .to(runner_Infra_Down
    .onTrue([Runner_Proof_Alert, Runner_Proof_Email])
    .onFalse(prepare_Classify_Error.to(/* ...normal pipeline... */)));
```

## Relationship to `mainflow.md`

The SDK reconstructs the **node graph** (types, params, connections, sticky notes). It does **not** replace `mainflow.md`, which remains the hand-written narrative (the ASCII/Mermaid diagram, the Key Nodes table, the "why"). Workflow: refactor in TS → build JSON → re-import → then update `mainflow.md` by hand if the topology changed. Node `name` fields stay the bridge between the JSON, the TS consts, and the `mainflow.md` tables — keep them stable.

## Security

**The control is the input, not the output.** Codegen copies parameter values, credential *reference IDs*, chat IDs, and email addresses **verbatim**. Note what these are: credential blocks in n8n are `{id, name}` references — the actual API keys/tokens live encrypted in the instance and never appear in the JSON or the generated TS. So the `.ts` carries *instance-identifying IDs*, not secrets (the exception is a secret hardcoded directly into a node parameter — this repo doesn't do that; it uses credential blocks).

Practices, in order of importance:

1. **Generate from the committed placeholder JSON.** It already uses `CREDENTIAL_ID_*`, `YOUR_CHAT_ID_1`, `YOUR_ALERT_EMAIL`, so the generated TS is inherently placeholdered and safe. Verified: the emitted line reads `newCredential('Telegram inbox_important', 'CREDENTIAL_ID_TELEGRAM_IMPORTANT')`.
2. **Never run codegen against a live `*.local.n8n.json` export** — that binds real instance IDs and would put them in the `.ts`.
3. **Backstop:** `*.workflow.ts` and `sdk-scratch/` are gitignored so a stray generated file can't be committed. This is defense-in-depth, not the safeguard — don't rely on it in place of practice 1.

> There is no built-in redaction flag. `generateWorkflowCode`'s `valuesExcluded` option concerns pinned *execution* data, not the workflow definition — it does **not** strip credential IDs or parameter values (verified: output is byte-identical with it on/off). Reference credentials by stable *name* and let the target instance resolve the ID if you ever parameterize.

See the public-repo rules in the root `CLAUDE.md`.

## Package choice

The official **`@n8n/workflow-sdk`** (by n8n) is used because its round-trip is programmatic and lossless. Verified on `010-error-handler.json` (23 nodes, 19 connections): JSON→TS→JSON preserved all nodes and connections, and `validateWorkflow` returned `valid: true`. The community `@vahor/n8n-kit` (alpha) is a viable alternative with its own import CLI, but is not used here — no need for a fallback.

The SDK also exports LLM-oriented reference strings at `@n8n/workflow-sdk/prompts/sdk-reference` (`SDK_LANGUAGE_REFERENCE`, `WORKFLOW_RULES`, `WORKFLOW_SDK_PATTERNS`, …) — pull these into context when writing a workflow from scratch in TS.

## When to apply

| Situation | Use |
|-----------|-----|
| Small param/expression tweak | n8n UI (don't bother with TS) |
| Large restructure, branch surgery, bulk rename | This SDK |
| Reading an unfamiliar dense workflow | `wf:to-ts`, read the chain, discard |
| Authoring a brand-new workflow in code | SDK builder + `prompts/sdk-reference` |
