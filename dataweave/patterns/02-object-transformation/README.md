# 02 — Object Transformation

Objects are the backbone of integration payloads — JSON bodies, XML elements, database rows. These patterns cover the essential operations for reshaping, enriching, and cleaning object structures as data moves between systems.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Rename Keys | [`rename-keys.dwl`](rename-keys.dwl) | Beginner | Rename object keys to match a target schema |
| 2 | Remove Keys | [`remove-keys.dwl`](remove-keys.dwl) | Beginner | Strip sensitive or unwanted fields |
| 3 | Merge Objects | [`merge-objects.dwl`](merge-objects.dwl) | Intermediate | Combine multiple objects into one |
| 4 | Pluck Values | [`pluck-values.dwl`](pluck-values.dwl) | Intermediate | Extract keys/values from objects into arrays |
| 5 | Dynamic Keys | [`dynamic-keys.dwl`](dynamic-keys.dwl) | Advanced | Build objects with runtime-determined key names |
| 6 | Nested Object Update | [`nested-object-update.dwl`](nested-object-update.dwl) | Advanced | Update deeply nested fields without rebuilding |

---

## Core Functions Used

| Function | Purpose | Docs |
|----------|---------|------|
| `mapObject` | Transform each key-value pair | [mapObject](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-mapobject) |
| `filterObject` | Keep key-value pairs matching a condition | [filterObject](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-filterobject) |
| `pluck` | Convert object entries to an array | [pluck](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-pluck) |
| `valuesOf` | Extract all values as an array | [valuesOf](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-valuesof) |
| `keysOf` | Extract all keys as an array | [keysOf](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-keysof) |
| `++` | Merge/concatenate objects | [++](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-plusplus) |
| `-` | Remove a key from an object | [-](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-remove) |
| `update` | Modify nested fields by path | [update](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-update) |

---

## Tips

- **`mapObject` vs `map`:** Use `map` for arrays, `mapObject` for objects. They look similar but operate on different types.
- **Key collisions with `++`:** When merging objects, the right-hand side wins. `{a: 1} ++ {a: 2}` produces `{a: 2}`.
- **Dynamic keys syntax:** Wrap the key expression in parentheses: `{(myVar): value}`. Without parens, DataWeave treats it as a literal key name.
- **`update` vs manual rebuild:** The `update` operator is cleaner for deep nesting (3+ levels). For shallow objects, explicit mapping is often more readable.
- **`pluck` parameter order:** The callback is `(value, key, index)` — value comes first, which is the opposite of `mapObject`.

---

[Back to all patterns](../../README.md)
