#!/usr/bin/env node
/*
 * n8n-template.js — checks a workflow against n8n's template rules and renames nodes safely.
 * No dependencies. The rules are owned by projects/n8n/docs/template-submission.md.
 *
 * Usage:
 *   node scripts/n8n-template.js check  <workflow.json>             # exit 1 on any violation
 *   node scripts/n8n-template.js rename <workflow.json> <map.json>  # map = {"Old": "New"}, in place
 */
'use strict';

const fs = require('fs');

const STICKY = 'n8n-nodes-base.stickyNote';
const YELLOW = new Set([undefined, null, 1]);
const SECTION = 7;
const WARNING = 3;
const NODE_SIZE = 100;
const STICKY_DEFAULT = { width: 240, height: 160 };
const BARE_DEFAULTS = new Set([
  'If', 'Merge', 'Gmail', 'Code', 'Switch', 'Set', 'Edit Fields', 'Filter', 'Wait', 'Loop Over Items',
  'Split Out', 'HTTP Request', 'Google Sheets', 'Google Drive', 'Telegram', 'Execute Workflow',
  'Gmail Trigger', 'Schedule Trigger', 'Webhook', 'Manual Trigger', 'No Operation, do nothing',
  'When Executed by Another Workflow', 'Basic LLM Chain', 'AI Agent', 'Structured Output Parser',
]);
const PROVIDERS = /\b(groq|gemini|openai|gpt-?\d*|claude|anthropic|mistral|llama|ollama|deepseek|cohere|openrouter)\b/i;
const NAME_CHARS = /^[A-Za-z0-9 -]+$/;
// A sticky holding only a video embed: any color, anywhere, never the main sticky.
const isVideo = (n) => n.type === STICKY && /^@\[youtube\]\([^)\s]+\)$/.test((n.parameters?.content || '').trim());

// $('Name') / $("Name") / $node["Name"] / $node['Name'], with JS escapes inside the quotes.
const REF = /\$(\(\s*|node\[\s*)(['"])((?:\\.|(?!\2)[^\\])*)\2(\s*[)\]])/g;
const PLACEHOLDER_REF = /^(\.{3}|…|NodeName)$/; // `$('...')` in a code comment

const die = (msg) => { console.error(msg); process.exit(1); };
const load = (p) => {
  if (!p || !fs.existsSync(p)) die(`Not found: ${p}`);
  return JSON.parse(fs.readFileSync(p, 'utf8'));
};
const unescape = (s) => s.replace(/\\(.)/g, '$1');
const escape = (s, q) => s.replace(/\\/g, '\\\\').split(q).join('\\' + q);
const words = (text) => (String(text || '').match(/[\p{L}\p{N}][\p{L}\p{N}'’._/-]*/gu) || []).length;

function eachString(value, fn) {
  if (typeof value === 'string') return fn(value);
  if (Array.isArray(value)) return value.map((v) => eachString(v, fn));
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = eachString(v, fn);
    return out;
  }
  return value;
}

function rect(sticky) {
  const p = sticky.parameters || {};
  const [x, y] = sticky.position;
  return { x, y, w: p.width ?? STICKY_DEFAULT.width, h: p.height ?? STICKY_DEFAULT.height };
}

function contains(r, node) {
  const cx = node.position[0] + NODE_SIZE / 2;
  const cy = node.position[1] + NODE_SIZE / 2;
  return cx >= r.x && cx <= r.x + r.w && cy >= r.y && cy <= r.y + r.h;
}

const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

function check(file) {
  const wf = load(file);
  const errors = [];
  const warnings = [];
  const stickies = wf.nodes.filter((n) => n.type === STICKY && !isVideo(n));
  const nodes = wf.nodes.filter((n) => n.type !== STICKY);
  const names = new Set(nodes.map((n) => n.name));
  const label = (s) => `sticky "${s.name}"`;

  // Main sticky
  const yellow = stickies.filter((s) => YELLOW.has(s.parameters?.color));
  if (yellow.length !== 1) errors.push(`main sticky: expected exactly 1 yellow sticky, found ${yellow.length}`);
  if (yellow.length >= 1) {
    const main = yellow[0];
    const r = rect(main);
    const text = main.parameters?.content || '';
    const n = words(text);
    if (n < 100 || n > 300) errors.push(`main sticky: ${n} words, needs 100-300`);
    if (!/^###\s+How it works/m.test(text)) errors.push('main sticky: missing "### How it works"');
    if (!/^###\s+Setup/m.test(text)) errors.push('main sticky: missing "### Setup"');
    const others = wf.nodes.filter((o) => o !== main && !isVideo(o));
    const minX = Math.min(...others.map((o) => o.position[0]));
    const minY = Math.min(...others.map((o) => o.position[1]));
    if (r.x + r.w > minX) errors.push(`main sticky: not left of everything (right edge ${r.x + r.w} > leftmost ${minX})`);
    if (r.y > minY) errors.push(`main sticky: not top-aligned (y ${r.y} > topmost ${minY})`);
  }

  // Colors, sections, warnings
  const whites = [];
  for (const s of stickies) {
    const color = s.parameters?.color;
    const text = (s.parameters?.content || '').trim();
    if (PROVIDERS.test(text)) warnings.push(`${label(s)}: names a model or provider ("${text.match(PROVIDERS)[0]}")`);
    if (YELLOW.has(color)) continue;
    const held = nodes.filter((n) => contains(rect(s), n));
    if (color === SECTION) {
      whites.push(s);
      if (!text.startsWith('## ')) errors.push(`${label(s)}: section must start with "## "`);
      const n = words(text);
      if (n >= 50) errors.push(`${label(s)}: ${n} words, section needs under 50`);
      if (held.length < 2) errors.push(`${label(s)}: section covers ${held.length} node(s), needs 2 or more`);
    } else if (color === WARNING) {
      if (held.length !== 1) errors.push(`${label(s)}: warning covers ${held.length} node(s), needs exactly 1`);
    } else {
      errors.push(`${label(s)}: color ${color} not allowed (yellow main, 7 section, 3 warning)`);
    }
  }
  if (nodes.length >= 4 && whites.length === 0) errors.push(`sections: ${nodes.length} nodes and no white section sticky`);
  for (let i = 0; i < whites.length; i++) {
    for (let j = i + 1; j < whites.length; j++) {
      if (overlaps(rect(whites[i]), rect(whites[j]))) {
        errors.push(`sections overlap: "${whites[i].name}" and "${whites[j].name}"`);
      }
    }
  }

  // Node names
  const seen = new Set();
  for (const n of nodes) {
    if (seen.has(n.name)) errors.push(`node "${n.name}": duplicate name`);
    seen.add(n.name);
    if (n.name.length >= 40) errors.push(`node "${n.name}": ${n.name.length} chars, needs under 40`);
    if (!NAME_CHARS.test(n.name)) errors.push(`node "${n.name}": only letters, digits, spaces and hyphens`);
    if (BARE_DEFAULTS.has(n.name)) errors.push(`node "${n.name}": bare default name`);
    if (/[A-Za-z]\d+$/.test(n.name)) warnings.push(`node "${n.name}": trailing copy digit`);
  }

  // References
  for (const [from, outputs] of Object.entries(wf.connections || {})) {
    if (!names.has(from)) errors.push(`connection from missing node "${from}"`);
    for (const branches of Object.values(outputs)) {
      for (const branch of branches || []) {
        for (const c of branch || []) {
          if (!names.has(c.node)) errors.push(`connection "${from}" -> missing node "${c.node}"`);
        }
      }
    }
  }
  for (const n of nodes) {
    eachString(n.parameters, (s) => {
      for (const m of s.matchAll(REF)) {
        const ref = unescape(m[3]);
        if (!names.has(ref) && !PLACEHOLDER_REF.test(ref)) errors.push(`node "${n.name}": reference to missing node "${ref}"`);
      }
      return s;
    });
  }

  for (const w of warnings) console.log(`WARN  ${w}`);
  for (const e of errors) console.log(`FAIL  ${e}`);
  console.log(`${file}: ${nodes.length} nodes, ${stickies.length} stickies, ${errors.length} violation(s), ${warnings.length} warning(s)`);
  process.exit(errors.length ? 1 : 0);
}

function rename(file, mapFile) {
  const wf = load(file);
  const map = load(mapFile);
  const names = new Set(wf.nodes.map((n) => n.name));
  for (const [from, to] of Object.entries(map)) {
    if (!names.has(from)) die(`rename: no node named "${from}"`);
    if (names.has(to) && !(to in map)) die(`rename: "${to}" already exists`);
  }
  const targets = Object.values(map);
  if (new Set(targets).size !== targets.length) die('rename: two nodes map to the same new name');

  const to = (name) => (Object.prototype.hasOwnProperty.call(map, name) ? map[name] : name);
  const rewrite = (s) => s.replace(REF, (all, open, q, inner, close) => {
    const name = unescape(inner);
    return to(name) === name ? all : `$${open}${q}${escape(to(name), q)}${q}${close}`;
  });

  for (const n of wf.nodes) {
    n.name = to(n.name);
    if (n.parameters) n.parameters = eachString(n.parameters, rewrite);
  }
  const connections = {};
  for (const [from, outputs] of Object.entries(wf.connections || {})) {
    for (const branches of Object.values(outputs)) {
      for (const branch of branches || []) for (const c of branch || []) c.node = to(c.node);
    }
    connections[to(from)] = outputs;
  }
  wf.connections = connections;
  if (wf.pinData) {
    wf.pinData = Object.fromEntries(Object.entries(wf.pinData).map(([k, v]) => [to(k), v]));
  }
  fs.writeFileSync(file, JSON.stringify(wf, null, 2) + '\n');
  console.log(`${file}: renamed ${Object.keys(map).length} node(s)`);
}

const [cmd, file, mapFile] = process.argv.slice(2);
if (cmd === 'check' && file) check(file);
else if (cmd === 'rename' && file && mapFile) rename(file, mapFile);
else die('Usage: node scripts/n8n-template.js check <workflow.json> | rename <workflow.json> <map.json>');
