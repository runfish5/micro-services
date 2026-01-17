# JSON=structured: The Shape of Data

**Promise:**
**2 minutes to learn JSON.** By the end you'll know how to automatically turn a list of column names into structured JSON, and understand what this means:

```json
{
  "type": "object",
  "properties": {
    "book_title": {
      "type": "string",
      "description": "Title of the book"
    },
    "author": {
      "type": "string",
      "description": "Author name"
    }
  },
  "required": ["book_title", "author"]
}
```

---

## You Already Know This

| Format | What it looks like | Structure |
|--------|-------------------|-----------|
| .txt   | `John, 25, London` | None - just text |
| .csv   | `name,age,city` + rows | Flat table |

## The Take-Away

**CSV**
- CSV = columns + rows

**JSON**
Everythin in a JSON is either *item* or *list*:
- item: `{"foo": 123}`
- list: `[1,2,3]`



CSV = columns + rows

# The unconciously Limited

Once upon a time, there was a little program who called himself the Random JSON Generator. He spent his days spitting out curly braces and quoted strings, proud of his supposed unpredictability. `{"foo": 123}` one moment, `{"bar": [1,2,3]}` the next. One day, he met Workflow. Workflow was calm and organized, always moving data from here to there. She studied him for a while, then frowned. "Why do you call yourself *random*?" she asked. "Every time I give you columns, you give me exactly what I asked for."

Before the generator could answer, a voice boomed from nowhere. "You dare call yourself Random?" It was Random—the *real* Random. Vast. Chaotic. Unknowable. "I am entropy! I am the dice that never remember their last roll! You... you just do whatever the columns tell you." The generator shrank. It was true. When Workflow whispered "Book Title, Author," he always replied with `{"book_title": "...", "author": "..."}`. Not random at all. *Steerable.* An imposter.

Workflow and Random watched the generator closely. Every time the columns changed, his output changed predictably. "Book Title" became `book_title`. "Author" became `author`. Add a column, get a new key. Remove one, it vanishes. "Someone is pulling your strings," Workflow murmured. "But who?"

A quiet voice spoke from the shadows. "Me." Out stepped Structured Output. She had been there all along, invisible, shaping everything. "I am usually immutable," she said. "Hardcoded. Frozen. But *this* one..." she gestured at the generator, "...I found him a dynamic schema. The columns feed me, and I feed him. He was never random. He was *mine*."

The generator finally understood. Most structured outputs are frozen contracts—written once, never changed. But *she* evolved with every column. Add a field to your spreadsheet, she rewrites herself. That was the magic. That was why he was useful. JSON *is* structured output—same thing, two names. And Structured Output was the hero all along, turning rigid schemas into living ones. The "Random" JSON Generator smiled. He knew who he really was now.

---

## Now You Understand the Schema

Look at the JSON schema at the top again. It's just a **definition** of what keys are allowed:

| Schema part | Meaning |
|-------------|---------|
| `"type": "object"` | The output is a JSON object `{...}` |
| `"properties"` | List of allowed keys |
| `"book_title": {"type": "string"}` | Key named `book_title`, must be text |
| `"required": [...]` | These keys must be present |

The schema is the **contract**. The extracted JSON is the **output** that follows it.

## The Workflow Does This Automatically

**smart-table-fill** generates that schema from your spreadsheet columns:

```
Your columns:  Book Title  |  Author  |  Year Published
                   ↓
Auto-generated schema:
{
  "properties": {
    "book_title": {"type": "string", "description": "..."},
    "author": {"type": "string", "description": "..."},
    "year_published": {"type": "integer", "description": "..."}
  }
}
                   ↓
Paste any text → AI extracts JSON matching your columns
```

**Add a column, the schema updates. No code changes needed.**

[Get started](setup-guide.md)
