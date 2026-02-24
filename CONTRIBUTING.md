# Contributing to MuleSoft Cookbook

Thank you for your interest in contributing! This guide explains how to add new patterns and recipes.

---

## Adding a DataWeave Pattern

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
- Place the file in the correct category folder under `dataweave/patterns/`
- Update the category's `README.md` to include the new pattern

---

## Adding a Mule Recipe

### 1. Follow the Recipe Template

Each recipe is a folder with a `README.md`:

```markdown
## Recipe Name
> One-line description of what this recipe does.

### When to Use
- Bullet points of use cases

### Configuration / Code

\```xml
<!-- Realistic Mule 4 XML config -->
<flow name="example-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/example"/>
    <!-- Your pattern here -->
</flow>
\```

### How It Works
1. Step-by-step explanation
2. What each component does
3. How data flows through

### Gotchas
- Common mistakes and edge cases
- Performance considerations
- Platform-specific notes (CloudHub vs on-prem)

### Related
- [Related Recipe](../related-recipe/) — brief description
```

### 2. Requirements for Every Recipe

- **Realistic code** — production-grade Mule 4 XML, not toy examples
- **Complete XML** — include required attributes (`config-ref`, `path`, etc.)
- **When to Use** — at least 2 clear use cases
- **Gotchas** — at least 2 practical warnings
- **Related** — cross-link to 2+ related recipes in the cookbook
- **Folder naming** — use **kebab-case**: `circuit-breaker-object-store/`

### 3. File Placement

Place recipes in the correct section and category:

```
error-handling/retry/my-new-recipe/README.md
performance/caching/my-new-recipe/README.md
api-management/security/my-new-recipe/README.md
```

---

## Pull Request Requirements

1. **One pattern/recipe per PR** (or a small batch of related ones)
2. Every file must include working, production-grade code
3. **Update the section README** to list the new pattern/recipe
4. **Update the root README** if adding to a new section
5. **Test your code** — verify it works in Anypoint Studio or the DataWeave Playground

---

## Code Style

- **DW 2.0 only** — no DW 1.0 syntax (except in the migration guide)
- **Mule 4 only** — no Mule 3 XML
- **kebab-case filenames** — `my-pattern-name.dwl`, `my-recipe-name/`
- **Consistent indentation** — 4 spaces (no tabs)
- **MIME types** — always specify input and output MIME types
- **Comments** — use `//` for inline comments, `/** */` for header blocks

---

## Questions?

Open an [issue](https://github.com/shakarbisetty/mulesoft-cookbook/issues) and we'll help you get started.
