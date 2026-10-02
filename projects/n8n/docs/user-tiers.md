# User tiers: who a feature is for

**This is a capability and audience model.** It decides what the lab *offers* a reader, never what
it *permits*. There is no authorization boundary here: one operator, one n8n instance, one set of
credentials. **A tier is not a control. Never present it as one.**

(The shape is borrowed from PromptPotter's `docs/operations/access-model.md`. That model names
security boundaries enforced by code; this one does not.)

| Tier | Profile | Acts on | On a defect, they can |
|------|---------|---------|----------------------|
| **T3 — maintainer** | `codes: true` | workflow JSON, republish, the n8n API key | fix it |
| **T2 — operator** | `codes: false`, `configures: true` | Config nodes, sheets, credentials | report it, or change a setting |
| **T1 — recipient** | neither | the Telegram surface | read it, and tap what is offered |

**Current profile: T3 (`codes: true`)**, the only occupant. The rules below are therefore
unexercised, and worth writing anyway: the repo is public, and T2 is who imports it.

## Rules

1. **A tier gates the ACTION, never the INFORMATION.** T1 still sees that something is broken:
   they get a different button, not a shorter briefing. Hiding the fact makes the lab
   untrustworthy to exactly the people who cannot fix it themselves.
2. **Most of the lab is tierless and should stay that way.** The converter, the invoice OCR, the
   calendar digest serve everyone identically. Naming a tier is the exception and owes a reason
   in the project's own docs.
3. **Unset fails to the lowest tier.** No profile → T1 → information, no actions.

**One definition per feature.** Anything that varies by tier says so in exactly one place: a
Config-node value in a controlled vocabulary, the way `payment_method` (16, live) and
`upkeep_action_mode` (10, proposed) do. Never a condition scattered across nodes.

**Delegation is attenuation (roadmap, nothing implements it).** An assistant agent acting for a
reader would hold `grant ∩ that reader's tier`, never more: a T1 reader's agent may draft a GitHub
issue, but cannot push a workflow. One level, no re-delegation. A future feature must build that
clamp before claiming otherwise.

Worked example: `projects/n8n/10_error-handler/docs/upkeep-tasks-spec.md` § Who this is for.
