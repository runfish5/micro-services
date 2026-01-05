# n8n Troubleshooting

## Subworkflows: Must Republish After Changes

When working with subworkflows, **saving is not enough** - you must republish.

**Fix**: Executions → Copy to Editor → Publish

---

## Can't Publish Workflow (No Visible Errors)

Publish button doesn't work, but no fields are red and no error messages appear.

**Fix**: Executions → Copy to Editor → Publish

---

## LLM Structured Output Errors

Error: "Model output doesn't fit required format" or empty error `{}` in error handler.

**Cause**: The LLM failed to return valid JSON matching the required schema. Smaller or older models struggle with structured output.

**Fix**: Use a model with better structured output support:
- **OpenAI gpt-oss-120b** - Best open-source model for structured output (as of Jan 2026)
- Simplify the schema if possible (fewer required fields, simpler nesting)
