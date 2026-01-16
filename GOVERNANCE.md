# Governance

## Collaborators

| Name | Role | Type |
|------|------|------|
| dsacc | Maintainer | Human |
| Indiana Jones | Explorer | AI Agent |
| Claude Opus | Contributor | AI Agent |

## Hierarchy

```
      Maintainer
          │
    ┌─────┴─────┐
    │           │
 Indiana    Claude
  Jones      Opus
```

Maintainer has final authority. AI agents suggest, maintainer approves.

## Agent Permissions

**ALLOWED:**
- Edit files in `projects/`
- Create/update documentation
- Git commits with `Co-Authored-By` attribution

**FORBIDDEN:**
- Push to remote
- Breaking changes

*(File-level restrictions enforced in `.claude/settings.json`)*

## Pre-Commit Check (AI Agents)

**Before ANY git commit, you MUST:**

1. Read this file
2. Verify all staged files are within ALLOWED boundaries
3. If ANY file is FORBIDDEN → stop, ask maintainer

**Violation example:**
```
# User: "commit your changes"
# Agent modified: projects/n8n/workflow.json, CLAUDE.md

WRONG: git add -A && git commit
RIGHT: "I modified CLAUDE.md which is protected. Commit only workflow.json?"
```

## Invoking Agents

| Agent | Use For | Invoke |
|-------|---------|--------|
| Indiana Jones | Research, patterns, gaps | `Use discoverer agent...` |
| Claude Opus | Implementation, fixes | `Use claude-opus agent...` |

## Adding Collaborators

1. Create `.claude/agents/{name}.md`
2. Add entry to table above
