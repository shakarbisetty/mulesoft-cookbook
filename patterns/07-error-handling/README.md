# 07 — Error Handling

Robust integrations don't break on bad data — they handle it gracefully. These patterns cover null safety, try/catch, validation, and building standardized error responses for APIs.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Default Values | [`default-values.dwl`](default-values.dwl) | Beginner | Fallback values for null/missing fields |
| 2 | Try Pattern | [`try-pattern.dwl`](try-pattern.dwl) | Intermediate | Attempt operations with graceful error handling |
| 3 | Error Response Builder | [`error-response-builder.dwl`](error-response-builder.dwl) | Intermediate | Build standardized API error responses |
| 4 | Conditional Error | [`conditional-error.dwl`](conditional-error.dwl) | Intermediate | Validate input and handle errors by business rules |

---

## Core Functions Used

| Function | Purpose | Docs |
|----------|---------|------|
| `default` | Fallback for null values | [default](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-default) |
| `try` | Attempt operation, return success/error | [try](https://docs.mulesoft.com/dataweave/latest/dw-runtime-functions-try) |
| `orElse` | Inline fallback after try | [orElse](https://docs.mulesoft.com/dataweave/latest/dw-runtime-functions-orelse) |
| `isEmpty` | Check for null/empty | [isEmpty](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-isempty) |
| `if/else` | Conditional logic | [Control Flow](https://docs.mulesoft.com/dataweave/latest/dataweave-flow-control) |
| `match` | Pattern matching | [match](https://docs.mulesoft.com/dataweave/latest/dataweave-pattern-matching) |

---

## Tips

- **`default` is your best friend:** Use it everywhere input might be null. `payload.field default "fallback"` is safer than assuming the field exists.
- **`try` returns an object:** `{success: true, result: value}` or `{success: false, error: {...}}`. Check `.success` before accessing `.result`.
- **Don't swallow errors silently:** Always log or report failed records. The try pattern example shows how to separate valid/invalid records.
- **Validate early:** Check input at the boundary (when data enters your flow), not deep inside transformations.

---

[Back to all patterns](../../README.md)
