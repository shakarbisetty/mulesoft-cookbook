# DataWeave 1.0 → 2.0 Migration Guide

> A practical reference for migrating legacy DataWeave 1.0 transformations to DataWeave 2.0 syntax.

DataWeave 2.0 was introduced in Mule 4 and is **not backwards-compatible** with DW 1.0 (Mule 3). If you're migrating Mule 3 applications to Mule 4, every DataWeave transform needs updating. This guide covers every syntax change.

---

## Table of Contents

- [Version Declaration](#version-declaration)
- [Output Declaration](#output-declaration)
- [Variables](#variables)
- [Flow Control](#flow-control)
- [Functions](#functions)
- [Type System](#type-system)
- [Operators](#operators)
- [Selectors](#selectors)
- [Null Handling](#null-handling)
- [String Handling](#string-handling)
- [Date Handling](#date-handling)
- [XML Handling](#xml-handling)
- [Module System](#module-system)
- [Complete Before/After Example](#complete-beforeafter-example)
- [Migration Checklist](#migration-checklist)

---

## Version Declaration

| DW 1.0 | DW 2.0 |
|--------|--------|
| `%dw 1.0` | `%dw 2.0` |

This is the first line of every DataWeave file and **must** be updated.

---

## Output Declaration

| DW 1.0 | DW 2.0 |
|--------|--------|
| `%output application/json` | `output application/json` |
| `%output application/xml` | `output application/xml` |
| `%output application/csv` | `output application/csv` |

The `%` prefix is removed.

---

## Variables

### DW 1.0
```dwl
%dw 1.0
%output application/json
%var taxRate = 0.0875
%var greeting = "Hello"
---
```

### DW 2.0
```dwl
%dw 2.0
output application/json
var taxRate = 0.0875
var greeting = "Hello"
---
```

**Change:** Remove `%` prefix from `var` declarations.

### Using keyword (scoped variables)

| DW 1.0 | DW 2.0 |
|--------|--------|
| `using (x = value)` | `do { var x = value --- ... }` |

### DW 1.0
```dwl
payload map ((item) ->
    using (total = item.price * item.quantity)
    {
        name: item.name,
        total: total
    }
)
```

### DW 2.0
```dwl
payload map (item) -> do {
    var total = item.price * item.quantity
    ---
    {
        name: item.name,
        total: total
    }
}
```

---

## Flow Control

### when/otherwise → if/else

| DW 1.0 | DW 2.0 |
|--------|--------|
| `value when condition otherwise other` | `if (condition) value else other` |

### DW 1.0
```dwl
"active" when payload.status == true otherwise "inactive"
```

### DW 2.0
```dwl
if (payload.status == true) "active" else "inactive"
```

### Chained conditions

### DW 1.0
```dwl
"gold" when payload.score > 90
    otherwise "silver" when payload.score > 70
    otherwise "bronze" when payload.score > 50
    otherwise "none"
```

### DW 2.0
```dwl
if (payload.score > 90) "gold"
else if (payload.score > 70) "silver"
else if (payload.score > 50) "bronze"
else "none"
```

### Pattern matching

DW 2.0 introduces `match` with `case`:

```dwl
payload.status match {
    case "A" -> "Active"
    case "I" -> "Inactive"
    case "P" -> "Pending"
    else -> "Unknown"
}
```

---

## Functions

### DW 1.0
```dwl
%dw 1.0
%function calculateTax(amount, rate)
    amount * rate
```

### DW 2.0
```dwl
%dw 2.0
fun calculateTax(amount: Number, rate: Number): Number =
    amount * rate
```

**Changes:**
- `%function` → `fun`
- Type annotations supported (optional but recommended)
- Return type annotation supported
- `=` before function body

### Lambda syntax

| DW 1.0 | DW 2.0 |
|--------|--------|
| `((item) -> item.name)` | `(item) -> item.name` |

Double parentheses are no longer needed around lambda parameters.

---

## Type System

### Type names

| DW 1.0 | DW 2.0 |
|--------|--------|
| `:string` | `String` |
| `:number` | `Number` |
| `:boolean` | `Boolean` |
| `:object` | `Object` |
| `:array` | `Array` |
| `:date` | `Date` |
| `:datetime` | `DateTime` |
| `:regex` | `Regex` |
| `:null` | `Null` |

### Coercion

| DW 1.0 | DW 2.0 |
|--------|--------|
| `payload.value as :number` | `payload.value as Number` |
| `payload.date as :date` | `payload.date as Date` |
| `payload.name as :string` | `payload.name as String` |

### Type checking

| DW 1.0 | DW 2.0 |
|--------|--------|
| `payload is :string` | `payload is String` |
| `payload is :number` | `payload is Number` |

---

## Operators

### Null coalescing

| DW 1.0 | DW 2.0 |
|--------|--------|
| `payload.field when payload.field != null otherwise "default"` | `payload.field default "default"` |

### String concatenation

| DW 1.0 | DW 2.0 |
|--------|--------|
| `"Hello " ++ name` | `"Hello $(name)"` (interpolation) or `"Hello " ++ name` |

String interpolation with `$(...)` is new in DW 2.0 and is preferred.

### Object merge

Unchanged — `++` works the same in both versions.

---

## Selectors

### Multi-value selector

| DW 1.0 | DW 2.0 |
|--------|--------|
| `payload.items[*].name` | `payload.items.*name` or `payload.items.name` (auto-maps on arrays) |

### Index access

Unchanged — `payload[0]`, `payload[-1]`, `payload[0 to 2]` work the same.

### Descendants

Unchanged — `payload..fieldName` works the same.

---

## Null Handling

### DW 1.0
```dwl
payload.field when payload.field != null otherwise "fallback"
```

### DW 2.0
```dwl
payload.field default "fallback"
```

DW 2.0's `default` also handles null-safe navigation — if any intermediate object in the chain is null, it returns the default:
```dwl
payload.customer.address.city default "Unknown"
// Safe even if customer or address is null
```

---

## String Handling

### Interpolation (new in 2.0)

```dwl
// DW 1.0 — concatenation only
"Order " ++ payload.orderId ++ " total: " ++ (payload.total as :string)

// DW 2.0 — interpolation
"Order $(payload.orderId) total: $(payload.total)"
```

### Split/Join

| DW 1.0 | DW 2.0 |
|--------|--------|
| `"a,b,c" splitBy ","` | `"a,b,c" splitBy ","` (same) |
| `["a","b"] joinBy ","` | `["a","b"] joinBy ","` (same) |

---

## Date Handling

### Date literals

| DW 1.0 | DW 2.0 |
|--------|--------|
| `"2026-02-15" as :date` | `"2026-02-15" as Date` or `\|2026-02-15\|` |
| `now` | `now()` |

### Period literals

| DW 1.0 | DW 2.0 |
|--------|--------|
| Not directly supported | `\|P1Y2M3D\|`, `\|PT1H30M\|` |

### Date arithmetic

```dwl
// DW 2.0 — native period arithmetic
|2026-02-15| + |P7D|          // add 7 days
|2026-02-15| - |P1M|          // subtract 1 month
now() + |PT2H|                 // add 2 hours
```

---

## XML Handling

### Namespaces

| DW 1.0 | DW 2.0 |
|--------|--------|
| `%namespace soap http://...` | `ns soap http://...` |

### DW 1.0
```dwl
%namespace soap http://schemas.xmlsoap.org/soap/envelope/
```

### DW 2.0
```dwl
ns soap http://schemas.xmlsoap.org/soap/envelope/
```

### Attributes

Reading and writing attributes with `@` is the same in both versions:
```dwl
// Read attribute
payload.Order.@id

// Set attribute
{Order @(id: "123"): { ... }}
```

---

## Module System

### DW 1.0
DW 1.0 had limited module support.

### DW 2.0
DW 2.0 has a full module system:
```dwl
import * from dw::core::Strings
import * from dw::core::Arrays
import try from dw::Runtime
import modules::MyCustomModule
```

Many functions that required manual implementation in DW 1.0 are now built-in modules:
- `dw::core::Strings` — camelize, underscore, capitalize, pad, etc.
- `dw::core::Arrays` — divideBy, partition, join, etc.
- `dw::core::Objects` — mergeWith, entrySet, etc.
- `dw::Runtime` — try, fail, wait, etc.

---

## Complete Before/After Example

### DW 1.0 (Mule 3)
```dwl
%dw 1.0
%output application/json
%var taxRate = 0.0875
%function calcTotal(price, qty)
    price * qty * (1 + taxRate)
---
payload.orders map ((order) ->
    using (total = calcTotal(order.price, order.quantity))
    {
        orderId: order.id,
        customer: order.customerName when order.customerName != null otherwise "Unknown",
        total: total as :string {format: "#,##0.00"},
        status: "priority" when order.amount > 1000 otherwise "standard",
        date: order.orderDate as :date {format: "MM/dd/yyyy"} as :string {format: "yyyy-MM-dd"}
    }
)
```

### DW 2.0 (Mule 4)
```dwl
%dw 2.0
output application/json
var taxRate = 0.0875

fun calcTotal(price: Number, qty: Number): Number =
    price * qty * (1 + taxRate)
---
payload.orders map (order) -> do {
    var total = calcTotal(order.price, order.quantity)
    ---
    {
        orderId: order.id,
        customer: order.customerName default "Unknown",
        total: total as String {format: "#,##0.00"},
        status: if (order.amount > 1000) "priority" else "standard",
        date: (order.orderDate as Date {format: "MM/dd/yyyy"}) as String {format: "yyyy-MM-dd"}
    }
}
```

---

## Migration Checklist

When migrating a DW 1.0 file to DW 2.0:

- [ ] Change `%dw 1.0` to `%dw 2.0`
- [ ] Change `%output` to `output` (remove `%`)
- [ ] Change `%var` to `var` (remove `%`)
- [ ] Change `%function name(args)` to `fun name(args) =`
- [ ] Change `%namespace` to `ns`
- [ ] Change `when ... otherwise` to `if ... else`
- [ ] Change `using (var = value)` to `do { var x = value --- ... }`
- [ ] Change `:string`, `:number`, etc. to `String`, `Number`, etc.
- [ ] Change `as :type` to `as Type`
- [ ] Change `is :type` to `is Type`
- [ ] Remove double parentheses from lambda params: `((item) ->` to `(item) ->`
- [ ] Change `now` to `now()`
- [ ] Replace null checks with `default` where appropriate
- [ ] Use string interpolation `$(...)` instead of `++` chains
- [ ] Import built-in modules instead of custom implementations
- [ ] Test thoroughly — some edge cases behave differently

---

[Back to all patterns](../README.md)
