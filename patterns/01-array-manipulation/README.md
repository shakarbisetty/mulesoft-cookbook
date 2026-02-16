# 01 — Array Manipulation

The most fundamental DataWeave operations. Arrays are everywhere in integration — API responses, database query results, batch payloads, and message collections. Master these patterns and you'll handle 80% of everyday transformations.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Filter by Condition | [`filter-by-condition.dwl`](filter-by-condition.dwl) | Beginner | Filter array elements by a predicate |
| 2 | Map Transform | [`map-transform.dwl`](map-transform.dwl) | Beginner | Transform each element into a new shape |
| 3 | Flatten Nested Arrays | [`flatten-nested.dwl`](flatten-nested.dwl) | Intermediate | Flatten nested arrays into a single-level list |
| 4 | Group By Field | [`group-by-field.dwl`](group-by-field.dwl) | Intermediate | Group objects by a shared field value |
| 5 | Distinct By | [`distinct-by.dwl`](distinct-by.dwl) | Intermediate | Remove duplicates by a field or criteria |
| 6 | Order By | [`order-by.dwl`](order-by.dwl) | Beginner | Sort objects by one or more fields |
| 7 | Reduce / Accumulate | [`reduce-accumulate.dwl`](reduce-accumulate.dwl) | Advanced | Aggregate values into a single result |
| 8 | Zip Arrays | [`zip-arrays.dwl`](zip-arrays.dwl) | Intermediate | Combine two arrays element-wise |

---

## Core Functions Used

| Function | Purpose | Docs |
|----------|---------|------|
| `filter` | Keep elements matching a condition | [filter](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-filter) |
| `map` | Transform each element | [map](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-map) |
| `flatMap` | Map + flatten in one step | [flatMap](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-flatmap) |
| `flatten` | Collapse nested arrays | [flatten](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-flatten) |
| `groupBy` | Group by key/field | [groupBy](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-groupby) |
| `distinctBy` | Deduplicate by criteria | [distinctBy](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-distinctby) |
| `orderBy` | Sort ascending | [orderBy](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-orderby) |
| `reduce` | Accumulate to single value | [reduce](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-reduce) |
| `zip` | Pair elements by index | [zip](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-zip) |

---

## Tips

- **`filter` vs `map`:** Use `filter` to remove elements, `map` to transform them. Combine both: `payload filter $.active map {name: $.name}`.
- **`flatMap` vs `flatten` + `map`:** `flatMap` is cleaner when you need both — it maps and flattens in one pass.
- **`reduce` is powerful but complex:** If you only need a sum, use `sum(payload.amounts)` instead of reduce. Reserve reduce for accumulations that produce objects or complex types.
- **Sort stability:** `orderBy` is stable — elements with equal sort keys keep their original order.

---

[Back to all patterns](../../README.md)
