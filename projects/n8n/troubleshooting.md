# n8n Troubleshooting

## Subworkflows Not Reflecting Changes

Execution behaves differently than when you tested? You tested the subworkflow directly, not via the parent - and forgot to republish.

**Fix**: Republish the subworkflow.


If publish button won't work (an error like *1 node has issues, fix them before publishing.*):

<img src="assets/trouble-shooting-publish-error1.png" width="300">

1. Go to Executions
2. Pick a successful run → Copy to Editor
3. Publish

This works because the execution data fills in whatever n8n thinks is missing.

---

## LLM Structured Output Errors

Error: "Model output doesn't fit required format" or empty error `{}` in error handler.

**Cause**: The LLM failed to return valid JSON matching the required schema. Smaller or older models struggle with structured output.

**Fix**: Use a model with better structured output support:
- **OpenAI gpt-oss-120b** - Best open-source model for structured output (as of Jan 2026)
- Simplify the schema if possible (fewer required fields, simpler nesting)
