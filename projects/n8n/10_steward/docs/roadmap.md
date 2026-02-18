# Steward Roadmap

> Written after Phase 0 reconsolidation (2 weeks post-creation, 19 commits).
> Updated after completing bug fixes (B1-B3), cleanup (C1-C2), Price History (Phases 1-4), and Dynamic Help (F2).

## Current State

| Workflow | Nodes | Stickies | Health |
|----------|-------|----------|--------|
| daily-briefing.json | 6 | 3 | Clean (removed passthrough node) |
| menu-handler.json | 20 (+4 sub-nodes) | 4 | Good — fully config-driven |
| deal-finder.json | 52 | 4 | Large — config-driven, well-structured branches incl. price history charts |
| learning-notes.json | 8 (+2 sub-nodes) | 1 | Functional as subworkflow (fixed caller input, removed unused memory) |
| price-checker.json | 13 | 2 | Clean — now appends price history on each check cycle |

**Total**: ~99 nodes across 5 workflows. deal-finder grew by 11 nodes for price history (Phases 2-3) but branches remain independent and spatially separated.

---

## Bug Fixes ~~(do first)~~ DONE

All three fixed and verified.

### ~~B1. Route switch `/help` double-matches~~ DONE

Added second condition to Route "agent" rule: `action != "chat"` AND `action != "help"`.

### ~~B2. learning-notes ignores caller's `text` and `chatId`~~ DONE

Replaced Set Config node with Code node that merges caller input over defaults. `input.text` maps to `searchTerm`.

### ~~B3. learning-notes Postgres memory on a one-shot summarizer~~ DONE

Removed Postgres Chat Memory sub-node and its `ai_memory` connection from AI Summary.

---

## Cleanup

C1 and C2 done. C3 and C4 are pending decisions.

### ~~C1. Remove "Prepare Price Check" passthrough in daily-briefing~~ DONE

Removed node, rewired Get Today's Events → Check Prices directly.

### ~~C2. Remove `chatId` default from price-checker Config~~ DONE

Removed unused `chatId` from Config defaults.

### C3. Decide on Whitelist node

The Whitelist node in menu-handler is disabled. Two options:
- **Re-enable it** with real chat IDs (security-conscious)
- **Remove it entirely** and document that the Telegram bot token is the only auth layer (simpler)

Either way, the current state (exists but disabled, documented as if active) is the worst option.

### C4. Decide on Perplexity in menu-handler

Perplexity Research node in menu-handler is disabled. The AI Classifier still lists it as a routing option, meaning the LLM can route to it and the user gets nothing. Options:
- Remove from Classifier prompt and route enum (clean)
- Re-enable if you have a Perplexity API key for menu-handler (note: deal-finder has its own Perplexity node that IS active)

---

## Design Principles

Patterns that emerged organically. Codify these so future work follows them:

### 1. Config-driven registry
The Config code node is the single source of truth. All routing, help text, and dispatch derive from it. **Never hardcode** agent names, workflow IDs, or descriptions outside Config.

~~**Violation**: Build Help hardcodes `/deals add` and `/deals track` sub-commands.~~ Fixed in F2 — Config now has `subCommands` arrays, Build Help reads them dynamically.

### 2. Subworkflows own their replies
Subworkflows (deal-finder, learning-notes) send their own Telegram messages. The hub's Format Skill Response node detects this (empty response) and does nothing. This is correct — subworkflows know their own output format best.

**Corollary**: Subworkflows that return `{response, chatId}` instead of sending their own reply can do so, and the hub forwards it. Both patterns coexist.

### 3. Fail gracefully with continueOnFail
Both Execute Workflow nodes have `onError: continueOnFail`. Format Skill Response detects error payloads and replies "temporarily unavailable". This prevents error handler cascades.

**Rule**: Every Execute Workflow node calling a subworkflow should have `continueOnFail` and connect to a guard node.

### 4. Purple sticky notes behind Execute Workflow nodes
Documents the parameters being passed. Serves as quick-restore reference when n8n UI silently clears `workflowInputs`.

### 5. Expression-first, node-last
Prefer n8n expressions and Code node logic over adding new nodes. Each node adds visual complexity and connection overhead. A ternary in an expression is better than an IF node for simple conditions.

---

## Feature Roadmap

### ~~F1. Price History~~ DONE

All phases implemented. See `docs/price-history-spec.md` (status: Implemented).
- Phase 1: Append History node in price-checker (append-only log to Price History tab)
- Phase 2: `/deals history <product>` — single-product line chart via QuickChart.io
- Phase 3: `/deals plot` — multi-product overlay chart with color-coded lines
- Phase 4: Documentation updated (mainflow.md, CLAUDE.md, setup-guide.md, spec)

### ~~F2. Make Build Help fully dynamic + morning briefing hint~~ DONE

Added `subCommands` array to deals entry in Config registry. Build Help now iterates `subCommands` dynamically — new commands auto-appear in `/help`. Also added a `❓ Help` button to the daily briefing's second button row (`briefing:help`), which routes through Normalize's existing `builtinActions` handling.

### F3. `/start` command

Telegram bots conventionally respond to `/start`. Currently this routes to the AI Classifier which gives an unstructured LLM response. Add `start` to built-in actions alongside `help`, showing a welcome message + help text.

### F4. Threshold price alerts in daily briefing

price-checker already has `notify_mode: "threshold"` and `price_threshold` in the schema but no implementation. When a tracked item drops below threshold:
- Include a highlight in the daily briefing's price section
- Optionally send an immediate alert (separate from briefing)

### F5. Weekly digest

A scheduled weekly summary: categories researched, price changes over the week, any threshold hits. Complements the daily briefing with a higher-level view.

---

## Refactoring Considerations

### deal-finder size management

At 52 nodes (post-Phase 3), deal-finder is the largest workflow. It's manageable because branches are independent (digest, add, modify, track, untrack, tracked, check_prices, history, plot). Each branch is spatially separated in the canvas.

**Options if it gets too large**:
- Extract the track/untrack/tracked branch into a separate `price-tracker.json` subworkflow
- Extract the digest branch (Perplexity research loop) into a separate `deal-research.json` subworkflow
- Keep it monolithic — n8n handles large workflows fine visually when branches are spatially separated

**Not urgent** — branches are independent and well-separated.

### Shared Config pattern

deal-finder and price-checker both define `sheetId` defaults independently. If they ever diverge, things break silently. Consider:
- price-checker reads `sheetId` from its Execute Workflow input (passed by deal-finder or daily-briefing)
- Only deal-finder's Config defines the sheet ID
- This is already partially the case (price-checker's Config merges `input` over defaults)

---

## Suggested Next Steps

Completed: B1-B3, C1-C2, F1 (Price History Phases 1-4), F2 (Dynamic Help + briefing hint).

Remaining work, in priority order:
1. **C3 + C4 decisions** — Whitelist and Perplexity: decide keep-or-remove
2. **F3: `/start` command** — small, quick win for Telegram UX
3. **F4: Threshold price alerts** — leverage existing `notify_mode`/`price_threshold` schema
4. **F5: Weekly digest** — scheduled summary of the week's activity
