# 09 — Advanced Patterns

For when the basics aren't enough. These patterns cover recursion, custom functions, multi-level grouping, dynamic schemas, and tail-recursive optimization — the tools you need for complex enterprise transformations.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Recursive Transform | [`recursive-transform.dwl`](recursive-transform.dwl) | Advanced | Recursively traverse and transform nested structures |
| 2 | Custom Functions | [`custom-functions.dwl`](custom-functions.dwl) | Advanced | Define reusable functions, lambdas, higher-order functions |
| 3 | Multi-Level GroupBy | [`multi-level-groupby.dwl`](multi-level-groupby.dwl) | Advanced | Nested groupBy for hierarchical aggregation |
| 4 | Dynamic Schema | [`dynamic-schema.dwl`](dynamic-schema.dwl) | Advanced | Configuration-driven field mapping |
| 5 | Tail Recursion | [`tail-recursion.dwl`](tail-recursion.dwl) | Advanced | Stack-safe recursion with @TailRec |

---

## Core Concepts

| Concept | Syntax | Use Case |
|---------|--------|----------|
| Named function | `fun name(params): Type = body` | Reusable logic |
| Lambda | `(params) -> body` | Inline functions, callbacks |
| Pattern matching | `data match { case ... }` | Type-based branching |
| @TailRec | `@TailRec() fun name(...)` | Stack-safe recursion |
| `do { }` | `do { var x = ... --- expr }` | Scoped variables |
| Higher-order fn | `fun apply(fn: (T) -> R)` | Functions as parameters |

---

## Tips

- **Recursion depth:** Standard recursion overflows around ~256 levels. Use `@TailRec()` for deeper structures.
- **@TailRec requirement:** The recursive call must be the **last** expression. No operations after it.
- **`do { }` blocks:** Use them to scope local variables inside map, reduce, or other expressions.
- **Dynamic schemas:** Config-driven mapping is powerful but harder to debug. Log intermediate results during development.
- **Test complex patterns:** Always test with edge cases — empty arrays, null fields, single-element inputs, deeply nested data.

---

[Back to all patterns](../../README.md)
