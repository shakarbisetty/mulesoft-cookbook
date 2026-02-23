# 06 — CSV Operations

File-based integrations are alive and well in enterprise environments. Batch imports, data exports, legacy system feeds, and reporting pipelines all rely on CSV, TSV, and other delimited formats. These patterns cover the essentials.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | CSV to JSON | [`csv-to-json.dwl`](csv-to-json.dwl) | Beginner | Parse CSV into JSON array of objects |
| 2 | JSON to CSV | [`json-to-csv.dwl`](json-to-csv.dwl) | Beginner | Convert JSON array to CSV with headers |
| 3 | Custom Separator | [`custom-separator.dwl`](custom-separator.dwl) | Intermediate | Handle pipe, tab, semicolon delimiters |

---

## CSV MIME Type Properties

| Property | Default | Description |
|----------|---------|-------------|
| `separator` | `,` | Column delimiter character |
| `header` | `true` | Whether first row is headers |
| `quoteChar` | `"` | Character used to quote values |
| `quoteValues` | `false` | Quote all output values |
| `escapeChar` | `\` | Escape character inside quotes |
| `bodyStartLineNumber` | `0` | Skip N lines before parsing |
| `streaming` | `false` | Enable streaming for large files |

---

## Tips

- **All CSV values are strings:** DataWeave parses CSV fields as strings. Cast explicitly: `row.price as Number`, `row.active as Boolean`.
- **Missing headers:** Use `header=false` and access columns as `row.column_0`, `row.column_1`, etc.
- **Large files:** Add `streaming=true` to the input directive for memory-efficient processing of large CSVs.
- **Quoting:** Values containing the separator character are automatically quoted on output. Use `quoteValues=true` to quote everything.

---

[Back to all patterns](../../README.md)
