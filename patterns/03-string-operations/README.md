# 03 — String Operations

Strings are the universal data type in integration. Whether you're parsing log lines, reformatting identifiers, building URLs, or converting between naming conventions, these patterns have you covered.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Split and Join | [`split-join.dwl`](split-join.dwl) | Beginner | Split strings by delimiter, join arrays into strings |
| 2 | Regex Match/Replace | [`regex-match-replace.dwl`](regex-match-replace.dwl) | Intermediate | Pattern matching, capture groups, find-and-replace |
| 3 | Case Conversion | [`camel-to-snake.dwl`](camel-to-snake.dwl) | Intermediate | Convert between camelCase, snake_case, PascalCase, kebab-case |
| 4 | Template Strings | [`template-strings.dwl`](template-strings.dwl) | Beginner | String interpolation with `$(...)` syntax |
| 5 | String Padding | [`string-padding.dwl`](string-padding.dwl) | Intermediate | Pad strings to fixed width (left/right) |

---

## Core Functions Used

| Function | Purpose | Docs |
|----------|---------|------|
| `splitBy` | Split string into array | [splitBy](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-splitby) |
| `joinBy` | Join array into string | [joinBy](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-joinby) |
| `match` | Regex match with capture groups | [match](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-match) |
| `matches` | Boolean regex test | [matches](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-matches) |
| `scan` | Find all regex matches | [scan](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-scan) |
| `replace` | String or regex replacement | [replace](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-replace) |
| `upper` / `lower` | Case conversion | [upper](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-upper) |
| `trim` | Strip leading/trailing whitespace | [trim](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-trim) |
| `sizeOf` | String length | [sizeOf](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-sizeof) |

---

## Tips

- **`splitBy` vs `splitBy` with regex:** `splitBy ","` splits by literal comma. `splitBy /[,;|]/` splits by any of those delimiters.
- **`match` vs `scan`:** `match` returns the first match. `scan` returns all matches as an array of arrays.
- **String interpolation:** Always use `$(expression)` inside double-quoted strings — it's cleaner than `++` concatenation.
- **DW Strings module:** `import * from dw::core::Strings` gives you `camelize`, `underscore`, `capitalize`, `pluralize`, and more.

---

[Back to all patterns](../../README.md)
