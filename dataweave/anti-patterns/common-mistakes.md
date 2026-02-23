# DataWeave Anti-Patterns & Common Mistakes

> The top mistakes we see in DataWeave code reviews — and how to fix them.

Every anti-pattern below includes the **bad code**, an explanation of **why it's wrong**, and the **correct approach**.

---

## Table of Contents

1. [Not using `default` for nullable fields](#1-not-using-default-for-nullable-fields)
2. [Using `if/else` where `default` suffices](#2-using-ifelse-where-default-suffices)
3. [Hardcoding values that should be variables](#3-hardcoding-values-that-should-be-variables)
4. [Using `map` when you need `flatMap`](#4-using-map-when-you-need-flatmap)
5. [Rebuilding entire objects to change one field](#5-rebuilding-entire-objects-to-change-one-field)
6. [Not handling repeating XML elements](#6-not-handling-repeating-xml-elements)
7. [String concatenation instead of interpolation](#7-string-concatenation-instead-of-interpolation)
8. [Ignoring type coercion on CSV/XML fields](#8-ignoring-type-coercion-on-csvxml-fields)
9. [Writing recursive functions without @TailRec](#9-writing-recursive-functions-without-tailrec)
10. [Using `reduce` when a simpler function exists](#10-using-reduce-when-a-simpler-function-exists)
11. [Not stripping nulls before downstream processing](#11-not-stripping-nulls-before-downstream-processing)
12. [Mixing DW 1.0 and DW 2.0 syntax](#12-mixing-dw-10-and-dw-20-syntax)

---

## 1. Not using `default` for nullable fields

### Bad
```dwl
{
    name: payload.customer.name,
    email: payload.customer.email,
    city: payload.customer.address.city
}
```
If `customer`, `address`, or `city` is null, the entire expression fails or produces unexpected nulls downstream.

### Good
```dwl
{
    name: payload.customer.name default "Unknown",
    email: payload.customer.email default "noreply@example.com",
    city: payload.customer.address.city default "N/A"
}
```

### Why it matters
Integration payloads are inherently unreliable. Optional fields, null records, and missing nested objects are the norm. Always provide sensible defaults.

---

## 2. Using `if/else` where `default` suffices

### Bad
```dwl
{
    phone: if (payload.phone != null) payload.phone else "N/A"
}
```

### Good
```dwl
{
    phone: payload.phone default "N/A"
}
```

### Why it matters
`default` is cleaner, shorter, and handles the entire null chain. The `if/else` version is verbose and doesn't protect against deeply nested nulls.

---

## 3. Hardcoding values that should be variables

### Bad
```dwl
%dw 2.0
output application/json
---
payload map (item) -> {
    price: item.amount * 1.0875,
    shipping: if (item.amount > 100) 0 else 9.99,
    status: if (item.type == "ELECTRONICS") "priority" else "standard"
}
```

### Good
```dwl
%dw 2.0
output application/json
var TAX_RATE = 0.0875
var FREE_SHIPPING_THRESHOLD = 100
var SHIPPING_COST = 9.99
var PRIORITY_CATEGORIES = ["ELECTRONICS", "MEDICAL"]
---
payload map (item) -> {
    price: item.amount * (1 + TAX_RATE),
    shipping: if (item.amount > FREE_SHIPPING_THRESHOLD) 0 else SHIPPING_COST,
    status: if (PRIORITY_CATEGORIES contains item.type) "priority" else "standard"
}
```

### Why it matters
Magic numbers and strings are hard to maintain, easy to mistype, and impossible to override per-environment. Use variables at the top, or better yet, externalize to properties.

---

## 4. Using `map` when you need `flatMap`

### Bad
```dwl
// Produces nested arrays: [[items], [items], [items]]
payload.orders map (order) ->
    order.lineItems map (item) -> {
        orderId: order.id,
        sku: item.sku
    }
```

### Good
```dwl
// Produces flat array: [item, item, item, ...]
payload.orders flatMap (order) ->
    order.lineItems map (item) -> {
        orderId: order.id,
        sku: item.sku
    }
```

### Why it matters
Nested arrays cause problems in downstream processing — database inserts, CSV output, and batch operations all expect flat arrays. Use `flatMap` (or `flatten` after `map`) when you're mapping over nested structures.

---

## 5. Rebuilding entire objects to change one field

### Bad
```dwl
// Manually copy every field just to update one
{
    id: payload.id,
    name: payload.name,
    email: payload.email,
    phone: payload.phone,
    address: payload.address,
    status: "active"    // <-- the only change
}
```

### Good
```dwl
// Use ++ to override specific fields
payload ++ {status: "active"}

// Or use update for nested fields
payload update {
    case .customer.address.city -> "New City"
}
```

### Why it matters
Manual rebuilding is fragile — when the source adds new fields, your mapping silently drops them. Using `++` or `update` preserves all existing fields while changing only what you need.

---

## 6. Not handling repeating XML elements

### Bad
```dwl
// Only gets the FIRST Item element
payload.Order.Items.Item
```

### Good
```dwl
// Gets ALL Item elements as an array
payload.Order.Items.*Item
```

### Why it matters
In XML, `payload.Order.Items.Item` returns only the first match when multiple `<Item>` elements exist. The `.*Item` selector returns all matches as an array. This is one of the most common XML-related bugs in MuleSoft projects.

### Extra safety
```dwl
// Handle both single and multiple items
var items = payload.Order.Items.*Item default []
```

---

## 7. String concatenation instead of interpolation

### Bad
```dwl
"Order " ++ order.id ++ " for customer " ++ order.customer ++ " total: $" ++ (order.total as String)
```

### Good
```dwl
"Order $(order.id) for customer $(order.customer) total: \$$(order.total)"
```

### Why it matters
String interpolation with `$(...)` is cleaner, easier to read, and less error-prone than chaining `++` operators. It also handles type coercion automatically for most types.

---

## 8. Ignoring type coercion on CSV/XML fields

### Bad
```dwl
// CSV fields are ALL strings — arithmetic fails or produces wrong results
{
    total: row.price * row.quantity,    // string * string!
    isActive: row.active               // "true" (string, not boolean)
}
```

### Good
```dwl
{
    total: (row.price as Number) * (row.quantity as Number),
    isActive: row.active as Boolean
}
```

### Why it matters
CSV and XML values are always strings. DataWeave may silently coerce in some cases but fail in others. Always explicitly cast to the expected type. This also applies to XML attributes (`item.@quantity as Number`).

---

## 9. Writing recursive functions without @TailRec

### Bad
```dwl
// Will overflow the stack on deep structures (~256+ levels)
fun flatten(tree) =
    [tree] ++ (tree.children flatMap (child) -> flatten(child))
```

### Good
```dwl
@TailRec()
fun flatten(queue: Array, acc: Array = []): Array =
    if (isEmpty(queue)) acc
    else do {
        var current = queue[0]
        var rest = queue[1 to -1] default []
        ---
        flatten(rest ++ (current.children default []), acc << current)
    }
```

### Why it matters
Standard recursion in DataWeave has a limited call stack. For production data with unpredictable nesting depth, always use `@TailRec()` with an accumulator pattern. The recursive call must be the **last** expression in the function.

---

## 10. Using `reduce` when a simpler function exists

### Bad
```dwl
// Overcomplicated sum
payload.items reduce (item, acc = 0) -> acc + item.price

// Overcomplicated max
payload.items reduce (item, acc = payload.items[0]) ->
    if (item.price > acc.price) item else acc

// Overcomplicated distinct
payload reduce (item, acc = []) ->
    if (acc contains item) acc else acc << item
```

### Good
```dwl
// Use built-in functions
sum(payload.items.price)

payload.items maxBy $.price

payload distinctBy $
```

### Why it matters
DataWeave has rich built-in functions (`sum`, `avg`, `min`, `max`, `maxBy`, `minBy`, `distinctBy`, `groupBy`). Using `reduce` for operations that have dedicated functions makes code harder to read and maintain. Reserve `reduce` for complex accumulations that can't be expressed with simpler functions.

---

## 11. Not stripping nulls before downstream processing

### Bad
```dwl
// Sends null fields to API — may cause validation errors
{
    name: payload.name,
    middleName: payload.middleName,     // often null
    phone: payload.phone,               // often null
    fax: payload.fax                    // almost always null
}
```

### Good
```dwl
// Option A: Conditional field inclusion
{
    name: payload.name,
    (middleName: payload.middleName) if payload.middleName != null,
    (phone: payload.phone) if payload.phone != null,
    (fax: payload.fax) if payload.fax != null
}

// Option B: Strip nulls globally
{
    name: payload.name,
    middleName: payload.middleName,
    phone: payload.phone,
    fax: payload.fax
} filterObject (v, k) -> v != null
```

### Why it matters
Many REST APIs reject payloads with `null` fields. SOAP services may fail on missing elements. Database inserts may set columns to NULL when you wanted to skip them. Be intentional about which fields you include.

---

## 12. Mixing DW 1.0 and DW 2.0 syntax

### Bad (DW 1.0 syntax in a DW 2.0 file)
```dwl
%dw 2.0
output application/json
---
// DW 1.0 used 'when' / 'otherwise' and different operators
payload.name when payload.name != null otherwise "default"
```

### Good (DW 2.0 syntax)
```dwl
%dw 2.0
output application/json
---
payload.name default "default"

// Or with if/else
if (payload.name != null) payload.name else "default"
```

### Common DW 1.0 → 2.0 differences
| DW 1.0 | DW 2.0 |
|--------|--------|
| `when ... otherwise` | `if ... else` |
| `using (var = value)` | `var x = value` (in header) or `do { var x = ... }` |
| `as :object` | `as Object` |
| `as :string` | `as String` |
| `(payload[0])` | `payload[0]` |

See the full [DW 1.0 vs 2.0 Migration Guide](dw1-vs-dw2-migration.md) for more details.

---

## Summary Checklist

Before submitting a DataWeave PR, check:

- [ ] All nullable fields have `default` values
- [ ] No magic numbers — constants are `var` declarations
- [ ] XML repeating elements use `.*Element` not `.Element`
- [ ] CSV/XML values are explicitly cast to correct types
- [ ] String building uses `$(...)` interpolation, not `++` chains
- [ ] No unnecessary object rebuilds — use `++` or `update`
- [ ] Recursive functions use `@TailRec()` with accumulators
- [ ] `reduce` isn't used where `sum`, `max`, `groupBy`, etc. would work
- [ ] Null fields are stripped or conditionally included
- [ ] No DW 1.0 syntax in DW 2.0 files

---

[Back to all patterns](../README.md)
