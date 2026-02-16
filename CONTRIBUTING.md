# Contributing to DataWeave Patterns

Thank you for your interest in contributing! This guide explains how to add new patterns and submit pull requests.

---

## Adding a New Pattern

### 1. Follow the DWL Template

Every `.dwl` file **must** follow this exact template:

```dwl
/**
 * Pattern: [Pattern Name]
 * Category: [Category Name]
 * Difficulty: [Beginner | Intermediate | Advanced]
 *
 * Description: [One or two sentences explaining what this pattern does and when to use it.]
 *
 * Input (application/json):
 * [Realistic example input data]
 *
 * Output (application/json):
 * [Expected output that matches what the code produces]
 */
%dw 2.0
output application/json
---
// Your DataWeave 2.0 code here

// Alternative syntax (if applicable):
// payload map { ... }
```

### 2. Requirements for Every Pattern

- **Header comment** with all required fields (Pattern, Category, Difficulty, Description, Input, Output)
- **Realistic data** — use names, orders, products, dates, etc. Never use `foo`, `bar`, or `test123`
- **Output must match** — the expected output in the comment must be exactly what the code produces
- **Valid DW 2.0 syntax** — include `%dw 2.0` and the appropriate `output` MIME type
- **Alternative syntax** shown where applicable (e.g., shorthand `$` notation vs. named parameters)
- **Accurate difficulty level**:
  - **Beginner** — single core function, straightforward usage
  - **Intermediate** — combines functions, requires some DW knowledge
  - **Advanced** — recursion, custom types, complex transformations

### 3. File Naming

- Use **kebab-case** for all filenames: `filter-by-condition.dwl`, `group-by-field.dwl`
- Place the file in the correct category folder under `patterns/`
- Update the category's `README.md` to include the new pattern

---

## Pull Request Requirements

1. **One pattern per PR** (or a small batch of related patterns)
2. Every `.dwl` file must include:
   - Complete header comment with Input and Output examples
   - Working, tested DW 2.0 code
   - Alternative syntax where applicable
3. **Update the category README** (`patterns/XX-category/README.md`) to list the new pattern
4. **Update the root README** (`README.md`) table of contents if adding to a new category
5. **Test your code** — paste it into the [DataWeave Playground](https://developer.mulesoft.com/learn/dataweave/) and verify the output matches

---

## Code Style

- **DW 2.0 only** — no DW 1.0 syntax (except in the migration guide)
- **kebab-case filenames** — `my-pattern-name.dwl`
- **Consistent indentation** — 4 spaces (no tabs)
- **MIME types** — always specify input and output MIME types in comments and code
- **Comments** — use `//` for inline comments, `/** */` for header blocks

---

## Questions?

Open an [issue](https://github.com/weavepilot/dataweave-patterns/issues) and we'll help you get started.
