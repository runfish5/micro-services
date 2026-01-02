# Observability Through LLM Confidence Estimates

> **WIP** - Work in progress note

## Why This Matters

For all LLM integrations, implementing confidence in the structured output separately is not strictly necessary—but it is the only way to have a certainty measure assigned to the LLM output.

LLMs produce outputs without inherent certainty indicators. By requesting a confidence score in the structured output schema, we get the model's self-assessed reliability for each response. This enables:

- Filtering low-confidence extractions
- Flagging uncertain outputs for human review
- Logging reliability metrics over time
- Making informed decisions about automation vs manual handling

## Interpretation Guidelines

| Score | Meaning | Action |
|-------|---------|--------|
| 0.9+ | High confidence | Auto-process |
| 0.7-0.9 | Moderate | Log for review |
| <0.7 | Low | Flag for human verification |

Thresholds are task-dependent. Adjust based on observed accuracy.

## Workflows Using This

| Workflow | Field | Purpose |
|----------|-------|---------|
| `any-file2json-converter` | `class_confidence` | Document vs style element classification |
| `smart-table-fill` | `confidence` | Data extraction reliability |
