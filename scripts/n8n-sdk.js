#!/usr/bin/env node
/*
 * n8n-sdk.js — thin CLI wrapper around @n8n/workflow-sdk.
 *
 * The SDK ships no binary, so this exposes its two round-trip functions as
 * commands. It is a DEV TOOL for reading/refactoring a workflow as typed
 * TypeScript — the generated .ts is THROWAWAY. n8n UI/JSON stays the source
 * of truth (see CLAUDE.md > n8n Workflows).
 *
 * Usage:
 *   node scripts/n8n-sdk.js to-ts   <workflow.json> [out.ts]     # JSON -> TypeScript
 *   node scripts/n8n-sdk.js from-ts <workflow.ts>   [out.json]   # TypeScript -> JSON
 *   node scripts/n8n-sdk.js validate <workflow.json>             # structural validation
 *
 * If the output path is omitted, the result is printed to stdout.
 *
 * SECURITY: codegen copies whatever credential IDs / chat IDs live in the input
 * verbatim. Run it against the committed placeholder JSON, or keep the .ts out
 * of git (.gitignore already ignores *.workflow.ts and sdk-scratch/). Never
 * commit a .ts generated from a live export — it would carry real IDs.
 */
'use strict';

const fs = require('fs');
const path = require('path');

let sdk;
try {
  sdk = require('@n8n/workflow-sdk');
} catch (e) {
  console.error(
    'Cannot load @n8n/workflow-sdk. Run `npm install` at the repo root first.\n' + e.message,
  );
  process.exit(1);
}

const [cmd, inPath, outPath] = process.argv.slice(2);

function die(msg) {
  console.error(msg);
  process.exit(1);
}

function emit(text) {
  if (outPath) {
    fs.writeFileSync(outPath, text);
    console.error(`Wrote ${path.relative(process.cwd(), outPath)} (${text.length} bytes)`);
  } else {
    process.stdout.write(text.endsWith('\n') ? text : text + '\n');
  }
}

if (!cmd || !inPath) {
  die('Usage: node scripts/n8n-sdk.js <to-ts|from-ts|validate> <input> [output]');
}
if (!fs.existsSync(inPath)) die(`Input not found: ${inPath}`);

if (cmd === 'to-ts') {
  const wf = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  emit(sdk.generateWorkflowCode(wf));
} else if (cmd === 'from-ts') {
  const code = fs.readFileSync(inPath, 'utf8');
  const wf = sdk.parseWorkflowCode(code);
  emit(JSON.stringify(wf, null, 2));
} else if (cmd === 'validate') {
  const wf = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  const result = sdk.validateWorkflow(wf);
  console.log(JSON.stringify(result, null, 2));
  if (result && result.valid === false) process.exit(2);
} else {
  die(`Unknown command: ${cmd}. Use to-ts | from-ts | validate.`);
}
