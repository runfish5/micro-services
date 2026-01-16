---
schema_version: "1.0"
projects:
  smart-table-fill:
    version: "1.0.0"
    status: active
    updated: 2025-01-16
  inbox-attachment-organizer:
    version: "1.0.0"
    status: active
    updated: 2025-01-16
---

# AGENTS.md

## AI-EDITABLE ZONE
<!-- AI agents may freely update content below this line -->

### Project Status

| Project | Version | Status | Updated |
|---------|---------|--------|---------|
| smart-table-fill | 1.0.0 | active | 2025-01-16 |
| inbox-attachment-organizer | 1.0.0 | active | 2025-01-16 |

### Recent Changes

| Date | Project | Summary |
|------|---------|---------|
| 2025-01-16 | smart-table-fill | Rate-limited subworkflow |
| 2025-01-16 | inbox-attachment-organizer | ContactManager routing |

### Session Log
- 2025-01-16: Initial governance setup

<!-- END AI-EDITABLE ZONE -->

---

## HUMAN-ONLY ZONE
<!-- AI must NOT modify below. Read-only reference. -->

> **Note:** Permissions below are **enforced** in `.claude/settings.json`, not just advisory.
> File versions tracked in `.claude/deployments.yaml`.

### Protected Files
- `CLAUDE.md` - AI instructions (human-maintained)
- `AGENTS.md` HUMAN-ONLY zone - Governance rules
- `credentials-guide.md` - Security docs
- `.env*`, `*secret*`, `*credential*` - Secrets

### AI Permissions

| Action | Allowed |
|--------|---------|
| Read any file | Yes |
| Edit workflow JSON | Yes |
| Edit docs/*.md | Yes |
| Edit README.md (project) | Yes |
| Update AI-EDITABLE zone | Yes |
| Edit CLAUDE.md | No |
| Edit HUMAN-ONLY zone | No |
| Delete files | No |
| Git push | No |
