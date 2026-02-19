# Steward Roadmap

> Early development, single developer. This roadmap tracks what's done, what's next, and design decisions.

## Current State

| Workflow | Nodes | Health |
|----------|-------|--------|
| daily-briefing.json | 6 + 3 stickies | Clean |
| menu-handler.json | 20 (+4 sub-nodes) + 4 stickies | Good — fully config-driven |
| deal-finder.json | 52 + 4 stickies | Large — config-driven, well-structured branches incl. price history charts |
| learning-notes.json | 8 (+2 sub-nodes) + 1 sticky | Functional as subworkflow |
| price-checker.json | 13 + 2 stickies | Clean — appends price history on each check cycle |

**Total**: ~99 nodes across 5 workflows.

---

## Bug Fixes — DONE

**Route switch `/help` double-matches**: Added second condition to Route "agent" rule: `action != "chat"` AND `action != "help"`.




### C3. Whitelist node — intentionally deactivated

The Whitelist node in menu-handler exists but is disabled. This is the desired state: the Telegram bot token serves as the auth layer, and the node stays as scaffolding for future multi-user support. No action needed.

---

## Design Principles

Patterns that emerged organically. Codify these so future work follows them:

### 1. Config-driven registry
The Config code node is the single source of truth. All routing, help text, and dispatch derive from it. **Never hardcode** agent names, workflow IDs, or descriptions outside Config.

### 2. Subworkflows own their replies
Subworkflows (deal-finder, learning-notes) send their own Telegram messages. The hub's Format Skill Response node detects this (empty response) and does nothing.

**Corollary**: Subworkflows that return `{response, chatId}` instead of sending their own reply can do so, and the hub forwards it. Both patterns coexist.

### 3. Fail gracefully with continueOnFail
Both Execute Workflow nodes have `onError: continueOnFail`. Format Skill Response detects error payloads and replies "temporarily unavailable". This prevents error handler cascades.

**Rule**: Every Execute Workflow node calling a subworkflow should have `continueOnFail` and connect to a guard node.

---

## Feature Roadmap

### ~~F1. Price History~~ DONE

All phases implemented. See `docs/price-history-spec.md`.

### ~~F2. Dynamic Help + morning briefing hint~~ DONE

Config registry now includes `subCommands` arrays. Build Help iterates them dynamically — new commands auto-appear in `/help`. Daily briefing has a Help button in its second button row.

### F3. `/start` command (low priority)

Telegram bots conventionally respond to `/start` with a welcome message. Currently routes to AI Classifier which gives an unstructured LLM response. Fix: add `start` to built-in actions alongside `help`. Note: the AI already responds helpfully to `/help`, so this is cosmetic.

### F4. Threshold price alerts in daily briefing

price-checker already has `notify_mode: "threshold"` and `price_threshold` in the schema but no implementation. When a tracked item drops below threshold, highlight it in the daily briefing's price section and optionally send an immediate alert.

### F5. Weekly digest

Scheduled weekly summary: categories researched, price changes over the week, threshold hits. Complements the daily briefing with a higher-level view.

### F6. deal-finder modularization

At 52 nodes, deal-finder is the largest workflow. Branches are independent and spatially separated, but there is significant duplication in the Requirements CRUD operations. Goal: **zero duplication** by extracting natural module boundaries into subworkflows.

**Module boundaries**:
- **Requirements CRUD** (add / remove / pause / resume) — all share a Load → Find → Route pattern. HIGH duplication today. Extract to a single subworkflow with an `action` parameter.
- **Price Tracking** (track / untrack / tracked / history / plot) — operate on Tracked Prices + Price History tabs. Cohesive unit.
- **Deal Research** (digest) — Perplexity research loop, fully independent.

deal-finder becomes a thin router dispatching to these modules, similar to how menu-handler dispatches to deal-finder today.

**Shared Config pattern**: deal-finder passes `sheetId` to price-checker via `workflowInputs` (price-checker already accepts `input.sheetId`). daily-briefing calls price-checker without a sheetId — price-checker's own default serves as fallback. This eliminates the duplication risk where deal-finder and price-checker define `sheetId` independently.

### F7. Smart briefing enhancements

The daily briefing is the primary daily touchpoint — make it earn attention. Enrich the price section with intelligence from data that already exists:

- **Price highlights**: Flag items at their all-time low, significant drops (>10%), and threshold alerts (builds on F4)
- **Stale detection**: "Your 'laptop' requirement hasn't been researched in 14 days" (compare `last_researched` against today)
- **Trend summary**: "3 items dropped, 2 unchanged, 1 rose" — one-line overview before the detail

Implementation: Mostly expression work in daily-briefing + price-checker output formatting. Minimal new nodes.

### F8. Conversational deal management

Currently deal-finder requires exact command syntax (`/deals add phone 800CHF flagship camera`). The AI Classifier already routes free text to deal-finder. Enhancement: deal-finder accepts a `freeText` input and uses an LLM to parse intent + entities, then dispatches internally.

"I need a good camera under 1000 for wildlife photography" → LLM extracts `{action: "add", category: "camera", maxPrice: 1000, constraints: "wildlife photography"}` → routes to add branch.

This makes the assistant feel conversational rather than command-driven. The classifier already handles the routing; this adds NL understanding *within* deal-finder.

### F9. Reminders

New subworkflow + Config registry entry. "Remind me to check laptop prices Friday" → stores in a Google Sheet → scheduled check (every hour or at a set time) → sends Telegram message when due.

Simple implementation: Sheets-based store with columns (chatId, text, due_date, status). A lightweight scheduled workflow checks for due reminders. The AI Classifier routes "remind me..." messages to this agent.

### F10. Multi-user support

The whitelist node already exists as scaffolding. Enable it and isolate per-user state:

- Whitelist with real chat IDs
- Per-user tracked items (add `chatId` column to Tracked Prices / Requirements tabs, or per-user sheets)
- Conversation memory is already chatId-keyed (Postgres) — no changes needed
- price-checker needs to filter by user

This is the highest-effort feature but unlocks sharing the bot with family/friends.

---

## DX: Code Accessibility

This is a public DIY repo for education. A separate track of improvements focused on making the project approachable for newcomers who want to learn from or replicate it.

**DX1. Code node documentation** — Every Code node gets a 2-3 line header comment documenting inputs (what `$json` fields it expects), outputs (what it returns), and purpose. Currently Code nodes are the most opaque part of the workflows — you have to read the full JS to understand what a node does.

**DX2. Quick-start path** — The setup guide has 7 steps and assumes you want the full system. Add a "minimal setup" section: import menu-handler + one subworkflow (e.g., learning-notes, only 2 credentials needed). Get a working bot in 10 minutes, expand from there. Progressive adoption.

**DX3. Red sticky note standardization** — Red sticky notes (color 3) already mark "what to configure after import." Audit all workflows to ensure every configurable value (workflow IDs, sheet IDs, chat IDs, calendar emails) has a red sticky. Currently some workflows have them, others don't.

**DX4. Workflow README consistency** — Each workflow directory should have a README that follows the same pattern: What It Does (2-3 sentences), How to Set Up (numbered steps), What to Customize (bullet list). Standardize across all 5 workflows.

---

## Suggested Next Steps

Completed: B1-B3, C1-C4, F1, F2.

**Features** (in priority order):
1. **F4: Threshold price alerts** — leverage existing schema fields
2. **F7: Smart briefing enhancements** — enrich the daily touchpoint
3. **F5: Weekly digest** — scheduled summary
4. **F8: Conversational deal management** — NL understanding in deal-finder
5. **F6: deal-finder modularization** — prerequisite for scaling
6. **F9: Reminders** — new agent
7. **F10: Multi-user support** — architecture expansion
8. **F3: `/start` command** — cosmetic

**Accessibility** (parallel track):
1. **DX1: Code node documentation** — low effort, high readability impact
2. **DX3: Red sticky note audit** — consistency pass
3. **DX2: Quick-start path** — onboarding improvement
4. **DX4: Workflow README consistency** — doc standardization
