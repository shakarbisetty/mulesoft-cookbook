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
- [MEL to DataWeave 2.0](#mel-to-dataweave-20)
- [Mule 3 Context → Mule 4 Context](#mule-3-context--mule-4-context)
- [MUnit 1 → MUnit 2](#munit-1--munit-2)
- [DW 1.0 Operators Deep Dive](#dw-10-operators-deep-dive)
- [Complex Migration Examples](#complex-migration-examples)
- [DW 1.0 Libraries → DW 2.0 Modules](#dw-10-libraries--dw-20-modules)
- [Performance Differences](#performance-differences)
- [Gotchas & Breaking Changes](#gotchas--breaking-changes)
- [Automated Migration Tips](#automated-migration-tips)
- [Extended Migration Checklist](#extended-migration-checklist)

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

## MEL to DataWeave 2.0

Many Mule 3 applications use MEL (Mule Expression Language) for simple expressions. In Mule 4, **MEL is completely removed** — all expressions must be DataWeave 2.0.

### Common MEL → DW 2.0 Mappings

| MEL Expression | DataWeave 2.0 Equivalent | Context |
|---|---|---|
| `#[payload]` | `payload` | Direct payload access |
| `#[payload.field]` | `payload.field` | Field access |
| `#[payload.items[0]]` | `payload.items[0]` | Array index |
| `#[message.inboundProperties['Content-Type']]` | `attributes.headers.'content-type'` | HTTP header |
| `#[message.inboundProperties.http.query.params.id]` | `attributes.queryParams.id` | Query parameter |
| `#[message.inboundProperties.http.uri.params.id]` | `attributes.uriParams.id` | URI parameter |
| `#[message.inboundProperties.http.method]` | `attributes.method` | HTTP method |
| `#[message.inboundProperties.http.request.uri]` | `attributes.requestUri` | Request URI |
| `#[message.outboundProperties['Content-Type']]` | *(set in HTTP response config)* | Response header |
| `#[flowVars.myVar]` | `vars.myVar` | Flow variable |
| `#[flowVars['my-var']]` | `vars.'my-var'` | Flow var (special chars) |
| `#[sessionVars.token]` | *(removed — use Object Store or vars)* | Session variable |
| `#[recordVars.counter]` | *(removed — use vars in batch)* | Batch record var |
| `#[message.id]` | `correlationId` | Message ID |
| `#[server.dateTime]` | `now()` | Current timestamp |
| `#[server.dateTime.format('yyyy-MM-dd')]` | `now() as String {format: "yyyy-MM-dd"}` | Formatted date |
| `#[System.getenv('MY_VAR')]` | `Mule::p('my.property')` or `p('my.property')` | Environment variable |
| `#[app.registry.myBean]` | *(use Java module or Spring injection)* | Spring beans |
| `#[exception.message]` | `error.description` | Error message |
| `#[exception.causeException]` | `error.cause` | Error cause |
| `#[exception.cause.class.name]` | `error.errorType.identifier` | Error type |

### MEL String Operations → DW 2.0

| MEL | DW 2.0 |
|---|---|
| `#[payload.toUpperCase()]` | `upper(payload)` |
| `#[payload.toLowerCase()]` | `lower(payload)` |
| `#[payload.trim()]` | `trim(payload)` |
| `#[payload.length()]` | `sizeOf(payload)` |
| `#[payload.substring(0, 5)]` | `payload[0 to 4]` |
| `#[payload.contains('search')]` | `payload contains "search"` |
| `#[payload.replace('old', 'new')]` | `payload replace "old" with "new"` |
| `#[payload.startsWith('prefix')]` | `payload startsWith "prefix"` |
| `#[payload.isEmpty()]` | `isEmpty(payload)` |
| `#[payload + ' ' + vars.name]` | `"$(payload) $(vars.name)"` |

### MEL Conditional Logic → DW 2.0

```
// MEL — ternary in a choice router or expression
#[payload.amount > 1000 ? 'priority' : 'standard']

// DW 2.0
if (payload.amount > 1000) "priority" else "standard"
```

```
// MEL — null check
#[payload.name != null ? payload.name : 'Unknown']

// DW 2.0
payload.name default "Unknown"
```

### MEL Collection Operations → DW 2.0

```
// MEL — iterate with for-each (typically in flow, not expression)
#[payload.size()]

// DW 2.0
sizeOf(payload)
```

```
// MEL — check if list contains value
#[payload.contains('item')]

// DW 2.0
payload contains "item"
```

### MEL Java Interop → DW 2.0

```
// MEL — call Java static method
#[java.util.UUID.randomUUID().toString()]

// DW 2.0 — using Java module
import java!java::util::UUID
---
UUID::randomUUID() as String
```

```
// MEL — instantiate Java class
#[new java.text.SimpleDateFormat('yyyy-MM-dd').format(new java.util.Date())]

// DW 2.0 — native date handling
now() as String {format: "yyyy-MM-dd"}
```

---

## Mule 3 Context → Mule 4 Context

The Mule message structure changed significantly between Mule 3 and Mule 4. This affects every DW expression that accesses context.

### Message Structure Change

```
Mule 3 Message:                      Mule 4 Message:
├── payload                          ├── payload
├── inboundProperties                ├── attributes (replaces inbound)
│   ├── http.method                  │   ├── method
│   ├── http.query.params            │   ├── queryParams
│   ├── http.uri.params              │   ├── uriParams
│   ├── Content-Type                 │   ├── headers
│   └── custom-header                │   ├── requestUri
├── outboundProperties               │   └── requestPath
│   ├── Content-Type                 └── (no outbound — set in response)
│   └── custom-header
├── flowVars                         vars
├── sessionVars                      (removed — use Object Store)
├── recordVars (batch)               (removed — use vars)
├── exception                        error
│   ├── message                      │   ├── description
│   ├── causeException               │   ├── cause
│   └── class                        │   ├── errorType
└── attachments                      │   └── childErrors
                                     └── (attachments via DataWeave)
```

### HTTP Listener — Attributes Mapping

| Mule 3 (`inboundProperties`) | Mule 4 (`attributes`) |
|---|---|
| `message.inboundProperties['http.method']` | `attributes.method` |
| `message.inboundProperties['http.request.uri']` | `attributes.requestUri` |
| `message.inboundProperties['http.query.params']` | `attributes.queryParams` |
| `message.inboundProperties['http.uri.params']` | `attributes.uriParams` |
| `message.inboundProperties['Content-Type']` | `attributes.headers.'content-type'` |
| `message.inboundProperties['http.status']` | `attributes.statusCode` (on HTTP requester) |

### HTTP Requester — Response Attributes

| Mule 3 | Mule 4 |
|---|---|
| `message.inboundProperties['http.status']` | `attributes.statusCode` |
| `message.inboundProperties['http.reason']` | `attributes.reasonPhrase` |
| `message.inboundProperties['Content-Type']` | `attributes.headers.'content-type'` |

### Database Connector

| Mule 3 | Mule 4 |
|---|---|
| `payload` (single row as Map) | `payload` (always a List of Maps) |
| `message.inboundProperties['updateCount']` | Use `sizeOf(payload)` or check target attributes |

### File Connector

| Mule 3 | Mule 4 |
|---|---|
| `message.inboundProperties['originalFilename']` | `attributes.fileName` |
| `message.inboundProperties['directory']` | `attributes.directory` |
| `message.inboundProperties['fileSize']` | `attributes.size` |

### Setting Variables

```xml
<!-- Mule 3 -->
<set-variable variableName="orderId" value="#[payload.id]" />
<set-variable variableName="count" value="#[flowVars.count + 1]" />

<!-- Mule 4 -->
<set-variable variableName="orderId" value="#[payload.id]" />
<set-variable variableName="count" value="#[vars.count + 1]" />
```

### Error Handling Context

```dwl
// Mule 3 — in catch-exception-strategy
%dw 1.0
%output application/json
---
{
    error: exception.message,
    cause: exception.causeException.message
}

// Mule 4 — in error-handler/on-error-propagate
%dw 2.0
output application/json
---
{
    error: error.description,
    errorType: error.errorType.identifier,
    cause: error.cause.description default "N/A"
}
```

---

## MUnit 1 → MUnit 2

MUnit tests must be rewritten for Mule 4. The XML schema, assertion syntax, and mocking approach all changed.

### Test Structure

```xml
<!-- MUnit 1 (Mule 3) -->
<munit:config name="test-suite" />
<munit:test name="my-test" description="Test something">
    <munit:set payload="#['test payload']" />
    <flow-ref name="my-flow" />
    <munit:assert-on-equals expectedValue="#['expected']" actualValue="#[payload]" />
</munit:test>

<!-- MUnit 2 (Mule 4) -->
<munit:config name="test-suite" />
<munit:test name="my-test" description="Test something">
    <munit:behavior>
        <munit:set-event>
            <munit:payload value="#['test payload']" />
        </munit:set-event>
    </munit:behavior>
    <munit:execution>
        <flow-ref name="my-flow" />
    </munit:execution>
    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload]"
            is="#[MunitTools::equalTo('expected')]" />
    </munit:validation>
</munit:test>
```

### Key MUnit Changes

| MUnit 1 | MUnit 2 | Notes |
|---|---|---|
| `<munit:set payload="..." />` | `<munit:set-event><munit:payload value="..." /></munit:set-event>` | Payload setting restructured |
| `<munit:set-property propertyName="x" value="v" />` | `<munit:set-event><munit:attributes value="..." /></munit:set-event>` | Inbound properties → attributes |
| `<munit:set flowVars="..." />` | `<munit:set-event><munit:variables><munit:variable key="x" value="v" /></munit:variables></munit:set-event>` | Variables structure |
| `<munit:assert-on-equals>` | `<munit-tools:assert-that is="#[MunitTools::equalTo()]" />` | Hamcrest-style matchers |
| `<munit:assert-true>` | `<munit-tools:assert-that is="#[MunitTools::equalTo(true)]" />` | Boolean assertion |
| `<munit:assert-not-null>` | `<munit-tools:assert-that is="#[MunitTools::notNullValue()]" />` | Null assertion |
| `<mock:when messageProcessor="...">` | `<munit-tools:mock-when processor="...">` | Mock syntax |

### Assertion Matchers (MUnit 2)

```xml
<!-- Equals -->
<munit-tools:assert-that expression="#[payload]"
    is="#[MunitTools::equalTo('expected')]" />

<!-- Contains string -->
<munit-tools:assert-that expression="#[payload]"
    is="#[MunitTools::containsString('partial')]" />

<!-- Greater than -->
<munit-tools:assert-that expression="#[payload.count]"
    is="#[MunitTools::greaterThan(5)]" />

<!-- Collection size -->
<munit-tools:assert-that expression="#[sizeOf(payload)]"
    is="#[MunitTools::equalTo(3)]" />

<!-- Not null -->
<munit-tools:assert-that expression="#[payload.id]"
    is="#[MunitTools::notNullValue()]" />

<!-- Matches regex -->
<munit-tools:assert-that expression="#[payload.email]"
    is="#[MunitTools::matchesRegex('.*@.*\\.com')]" />
```

### Setting DW Payload in MUnit 2

```xml
<munit:set-event>
    <munit:payload value='#[%dw 2.0 output application/json --- { "name": "Alice", "age": 30 }]' />
    <munit:attributes value='#[%dw 2.0 output application/java --- { "method": "GET", "queryParams": {"page": "1"} }]' />
    <munit:variables>
        <munit:variable key="correlationId" value="#[uuid()]" />
    </munit:variables>
</munit:set-event>
```

---

## DW 1.0 Operators Deep Dive

Every operator that changed behavior or syntax between DW 1.0 and 2.0.

### map

```dwl
// DW 1.0 — double parens required for named params
payload map ((item, index) -> { name: item.name, position: index })

// DW 2.0 — single parens
payload map (item, index) -> { name: item.name, position: index }

// DW 2.0 — using $ and $$
payload map { name: $.name, position: $$ }
```

### mapObject

```dwl
// DW 1.0
payload mapObject ((value, key) -> { (upper key): value })

// DW 2.0
payload mapObject (value, key) -> { (upper(key as String)): value }
// Note: key is now a Key type, not String — explicit cast may be needed
```

### filter

```dwl
// DW 1.0
payload filter ((item) -> item.active == true)

// DW 2.0
payload filter (item) -> item.active == true
// or shorthand:
payload filter $.active
```

### reduce

```dwl
// DW 1.0
payload reduce ((item, acc = 0) -> acc + item.amount)

// DW 2.0
payload reduce (item, acc = 0) -> acc + item.amount
// Same logic, just remove outer parens
```

### groupBy

```dwl
// DW 1.0
payload groupBy $.department

// DW 2.0 — same syntax, but return type changed
payload groupBy $.department
// DW 2.0 returns Object with key-value pairs
// Keys are the grouped field values
```

### orderBy

```dwl
// DW 1.0
payload orderBy $.name

// DW 2.0 — same syntax
payload orderBy $.name

// DW 2.0 — descending
payload orderBy -$.age
// or
(payload orderBy $.age)[-1 to 0]
```

### pluck

```dwl
// DW 1.0 — returns array of values
payload pluck ((value, key) -> { key: key, value: value })

// DW 2.0 — same behavior
payload pluck (value, key) -> { key: key as String, value: value }
// Note: key is Key type in 2.0, may need `as String`
```

### sizeOf

```dwl
// DW 1.0 — works on strings, arrays, objects
sizeOf "hello"          // 5
sizeOf [1, 2, 3]        // 3
sizeOf {a: 1, b: 2}     // 2

// DW 2.0 — same for arrays/strings, but objects require keysOf/valuesOf
sizeOf("hello")         // 5
sizeOf([1, 2, 3])       // 3
sizeOf({a: 1, b: 2})    // 2 (works, but counts key-value pairs)
```

### match (Pattern Matching — New in DW 2.0)

DW 2.0 introduced `match` with typed patterns:

```dwl
// Type-based dispatch — no DW 1.0 equivalent
payload match {
    case is String -> "It's a string: $(payload)"
    case is Number -> "It's a number: $(payload)"
    case is Array -> "It's an array with $(sizeOf(payload)) items"
    case is Object -> "It's an object"
    else -> "Unknown type"
}

// Value matching
payload.status match {
    case "ACTIVE" -> { active: true }
    case "INACTIVE" -> { active: false }
    case status if status startsWith "PENDING" -> { active: false, pending: true }
    else -> { active: false }
}
```

---

## Complex Migration Examples

Real-world transformations showing the full migration process, not just syntax swaps.

### Example 1: Multi-Level XML Transform with Namespaces

```dwl
// DW 1.0 (Mule 3)
%dw 1.0
%output application/xml
%namespace ord http://example.com/orders
%namespace cust http://example.com/customers
%var today = now as :string {format: "yyyy-MM-dd"}
%function formatCurrency(amount)
    amount as :string {format: "#,##0.00"}
---
{
    ord#OrderResponse @(timestamp: today): {
        ord#Header: {
            ord#OrderId: payload.orderId,
            ord#Status: "CONFIRMED" when payload.items != null otherwise "EMPTY"
        },
        (payload.items map ((item) ->
            ord#LineItem @(lineNum: $$+1): {
                ord#Product: item.sku,
                ord#Description: item.name when item.name != null otherwise "N/A",
                ord#Quantity: item.qty,
                ord#UnitPrice: formatCurrency(item.price),
                ord#LineTotal: formatCurrency(item.price * item.qty),
                cust#BuyerRef: flowVars.buyerReference when flowVars.buyerReference != null otherwise ""
            }
        ))
    }
}

// DW 2.0 (Mule 4)
%dw 2.0
output application/xml
ns ord http://example.com/orders
ns cust http://example.com/customers
var today = now() as String {format: "yyyy-MM-dd"}

fun formatCurrency(amount: Number): String =
    amount as String {format: "#,##0.00"}
---
{
    ord#OrderResponse @(timestamp: today): {
        ord#Header: {
            ord#OrderId: payload.orderId,
            ord#Status: if (payload.items != null) "CONFIRMED" else "EMPTY"
        },
        (payload.items map (item, idx) -> {
            ord#LineItem @(lineNum: idx + 1): {
                ord#Product: item.sku,
                ord#Description: item.name default "N/A",
                ord#Quantity: item.qty,
                ord#UnitPrice: formatCurrency(item.price),
                ord#LineTotal: formatCurrency(item.price * item.qty),
                cust#BuyerRef: vars.buyerReference default ""
            }
        })
    }
}
```

**Key changes:** `%namespace` → `ns`, `%function` → `fun`, `%var` → `var`, `when/otherwise` → `if/else` and `default`, `flowVars` → `vars`, `now` → `now()`, `:string` → `String`, lambda parens simplified, `$$` → explicit index var.

### Example 2: Batch Aggregation with Error Handling

```dwl
// DW 1.0 (Mule 3) — in batch commit scope
%dw 1.0
%output application/json
%var successRecords = payload filter ((record) -> record.recordVars.processingStatus == "SUCCESS")
%var failedRecords = payload filter ((record) -> record.recordVars.processingStatus == "FAILED")
---
{
    batchId: flowVars.batchId,
    timestamp: now as :string {format: "yyyy-MM-dd'T'HH:mm:ss"},
    summary: {
        total: sizeOf payload,
        success: sizeOf successRecords,
        failed: sizeOf failedRecords
    },
    successRecords: successRecords map ((rec) -> {
        id: rec.payload.id,
        status: "processed"
    }),
    failedRecords: failedRecords map ((rec) -> {
        id: rec.payload.id,
        error: rec.recordVars.errorMessage when rec.recordVars.errorMessage != null otherwise "Unknown error"
    })
}

// DW 2.0 (Mule 4) — in batch aggregator
%dw 2.0
output application/json
import partition from dw::core::Arrays
var partitioned = payload partition (record) -> record.vars.processingStatus == "SUCCESS"
---
{
    batchId: vars.batchId,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"},
    summary: {
        total: sizeOf(payload),
        success: sizeOf(partitioned.success),
        failed: sizeOf(partitioned.failure)
    },
    successRecords: partitioned.success map (rec) -> {
        id: rec.payload.id,
        status: "processed"
    },
    failedRecords: partitioned.failure map (rec) -> {
        id: rec.payload.id,
        error: rec.vars.errorMessage default "Unknown error"
    }
}
```

**Key changes:** `recordVars` → `vars`, `flowVars` → `vars`, imported `partition` from built-in module, used `default` instead of `when/otherwise`, lambda simplified.

### Example 3: Error Response Builder with Context

```dwl
// DW 1.0 (Mule 3) — in catch-exception-strategy
%dw 1.0
%output application/json
%var statusMap = {
    "MULE:CLIENT_SECURITY": 401,
    "MULE:SECURITY": 403,
    "MULE:EXPRESSION": 400,
    "MULE:TRANSFORMATION": 400,
    "MULE:CONNECTIVITY": 503
}
---
{
    error: {
        code: statusMap[exception.cause.class.simpleName] when statusMap[exception.cause.class.simpleName] != null otherwise 500,
        message: exception.message,
        correlationId: message.id,
        timestamp: now as :string,
        path: message.inboundProperties['http.request.uri']
    }
}

// DW 2.0 (Mule 4) — in error-handler on-error-propagate
%dw 2.0
output application/json
var statusMap = {
    "HTTP:UNAUTHORIZED": 401,
    "HTTP:FORBIDDEN": 403,
    "HTTP:BAD_REQUEST": 400,
    "MULE:EXPRESSION": 400,
    "HTTP:CONNECTIVITY": 503,
    "HTTP:TIMEOUT": 504
}
---
{
    error: {
        code: statusMap[error.errorType.identifier] default 500,
        message: error.description,
        errorType: error.errorType.identifier,
        correlationId: correlationId,
        timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"},
        path: attributes.requestUri default "N/A"
    }
}
```

### Example 4: Salesforce Bulk Query Result Processing

```dwl
// DW 1.0 (Mule 3)
%dw 1.0
%output application/json
%function cleanPhone(phone)
    phone replace /[^0-9]/ with "" when phone != null otherwise null
%function formatAddress(acct)
    (acct.BillingStreet when acct.BillingStreet != null otherwise "") ++
    (", " ++ acct.BillingCity when acct.BillingCity != null otherwise "") ++
    (", " ++ acct.BillingState when acct.BillingState != null otherwise "") ++
    (" " ++ acct.BillingPostalCode when acct.BillingPostalCode != null otherwise "")
---
payload map ((acct) -> {
    accountId: acct.Id,
    name: acct.Name,
    phone: cleanPhone(acct.Phone),
    address: formatAddress(acct),
    tier: "Enterprise" when acct.AnnualRevenue > 1000000
        otherwise "Mid-Market" when acct.AnnualRevenue > 100000
        otherwise "SMB",
    contacts: acct.Contacts.records map ((c) -> {
        name: c.FirstName ++ " " ++ c.LastName,
        email: c.Email
    }) when acct.Contacts != null otherwise []
})

// DW 2.0 (Mule 4)
%dw 2.0
output application/json

fun cleanPhone(phone: String): String =
    phone replace /[^0-9]/ with ""

fun formatAddress(acct: Object): String =
    [
        acct.BillingStreet,
        acct.BillingCity,
        acct.BillingState,
        acct.BillingPostalCode
    ] filter ($ != null) joinBy ", "
---
payload map (acct) -> {
    accountId: acct.Id,
    name: acct.Name,
    phone: if (acct.Phone != null) cleanPhone(acct.Phone) else null,
    address: formatAddress(acct),
    tier: if (acct.AnnualRevenue > 1000000) "Enterprise"
          else if (acct.AnnualRevenue > 100000) "Mid-Market"
          else "SMB",
    contacts: (acct.Contacts.records default []) map (c) -> {
        name: "$(c.FirstName) $(c.LastName)",
        email: c.Email
    }
}
```

**Key improvement in 2.0:** `formatAddress` uses filter + joinBy instead of nested null checks — cleaner and more maintainable.

### Example 5: API Response with Pagination Metadata

```dwl
// DW 1.0 (Mule 3)
%dw 1.0
%output application/json
%var page = message.inboundProperties['http.query.params'].page as :number when message.inboundProperties['http.query.params'].page != null otherwise 1
%var pageSize = message.inboundProperties['http.query.params'].size as :number when message.inboundProperties['http.query.params'].size != null otherwise 20
%var totalRecords = flowVars.totalCount as :number
%var totalPages = (totalRecords / pageSize) as :number {class: "java.lang.Integer"} + (1 when (totalRecords mod pageSize) > 0 otherwise 0)
---
{
    data: payload,
    meta: {
        page: page,
        pageSize: pageSize,
        totalRecords: totalRecords,
        totalPages: totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1
    },
    links: {
        self: "/api/v1/orders?page=" ++ page ++ "&size=" ++ pageSize,
        next: "/api/v1/orders?page=" ++ (page + 1) ++ "&size=" ++ pageSize when page < totalPages otherwise null,
        prev: "/api/v1/orders?page=" ++ (page - 1) ++ "&size=" ++ pageSize when page > 1 otherwise null
    }
}

// DW 2.0 (Mule 4)
%dw 2.0
output application/json
var page = (attributes.queryParams.page default "1") as Number
var pageSize = (attributes.queryParams.size default "20") as Number
var totalRecords = vars.totalCount as Number
var totalPages = ceil(totalRecords / pageSize)
---
{
    data: payload,
    meta: {
        page: page,
        pageSize: pageSize,
        totalRecords: totalRecords,
        totalPages: totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1
    },
    links: {
        self: "/api/v1/orders?page=$(page)&size=$(pageSize)",
        next: if (page < totalPages) "/api/v1/orders?page=$(page + 1)&size=$(pageSize)" else null,
        prev: if (page > 1) "/api/v1/orders?page=$(page - 1)&size=$(pageSize)" else null
    }
}
```

**Key improvements in 2.0:** `attributes.queryParams` replaces `inboundProperties`, `default` for null safety, `ceil()` for pagination math, string interpolation for URL building, `vars` replaces `flowVars`.

---

## DW 1.0 Libraries → DW 2.0 Modules

Functions that required manual implementation in DW 1.0 are now available as built-in DW 2.0 modules.

### dw::core::Strings

```dwl
import * from dw::core::Strings
```

| Function | Description | DW 1.0 Equivalent |
|----------|-------------|-------------------|
| `camelize("my_field")` | → `"myField"` | Manual regex replace |
| `capitalize("hello")` | → `"Hello"` | Manual `upper(s[0]) ++ s[1 to -1]` |
| `charCode("A")` | → `65` | No equivalent |
| `charCodeAt("ABC", 1)` | → `66` | No equivalent |
| `dasherize("myField")` | → `"my-field"` | Manual regex replace |
| `fromCharCode(65)` | → `"A"` | No equivalent |
| `isAlpha("abc")` | → `true` | Manual regex check |
| `isAlphanumeric("abc123")` | → `true` | Manual regex check |
| `isLowerCase("abc")` | → `true` | Manual check |
| `isNumeric("123")` | → `true` | Manual regex check |
| `isUpperCase("ABC")` | → `true` | Manual check |
| `isWhitespace("  ")` | → `true` | Manual check |
| `leftPad("5", 3, "0")` | → `"005"` | Manual implementation |
| `ordinalize(1)` | → `"1st"` | No equivalent |
| `pluralize("box")` | → `"boxes"` | No equivalent |
| `repeat("ab", 3)` | → `"ababab"` | Manual loop |
| `rightPad("5", 3, "0")` | → `"500"` | Manual implementation |
| `singularize("boxes")` | → `"box"` | No equivalent |
| `underscore("myField")` | → `"my_field"` | Manual regex replace |
| `unwrap("'hello'", "'")` | → `"hello"` | Manual substring |
| `wrapIfMissing("hello", "'")` | → `"'hello'"` | Manual check + concat |
| `wrapWith("hello", "'")` | → `"'hello'"` | Manual concat |

### dw::core::Arrays

```dwl
import * from dw::core::Arrays
```

| Function | Description | DW 1.0 Equivalent |
|----------|-------------|-------------------|
| `countBy([1,2,3], (x) -> x > 1)` | → `2` | Manual reduce |
| `divideBy([1,2,3,4,5], 2)` | → `[[1,2],[3,4],[5]]` | Manual reduce |
| `drop([1,2,3,4], 2)` | → `[3,4]` | Manual slice |
| `dropWhile([1,2,3,4], (x) -> x < 3)` | → `[3,4]` | Manual implementation |
| `every([2,4,6], (x) -> isEven(x))` | → `true` | Manual reduce |
| `indexOf([1,2,3], 2)` | → `1` | Manual implementation |
| `join(left, right, (l) -> l.id, (r) -> r.id)` | SQL-like join | Manual implementation |
| `leftJoin(...)` | Left outer join | Manual implementation |
| `outerJoin(...)` | Full outer join | Manual implementation |
| `partition([1,2,3], (x) -> x > 1)` | Split by predicate | Manual filter × 2 |
| `some([1,2,3], (x) -> x > 2)` | → `true` | Manual implementation |
| `sumBy([{a:1},{a:2}], (x) -> x.a)` | → `3` | Manual reduce |
| `take([1,2,3,4], 2)` | → `[1,2]` | Manual slice |
| `takeWhile([1,2,3,4], (x) -> x < 3)` | → `[1,2]` | Manual implementation |

### dw::core::Objects

```dwl
import * from dw::core::Objects
```

| Function | Description | DW 1.0 Equivalent |
|----------|-------------|-------------------|
| `entrySet({a: 1})` | → `[{key: "a", value: 1}]` | Manual mapObject |
| `keySet({a: 1})` | → `["a"]` | `payload pluck $$` |
| `mergeWith({a: 1}, {b: 2})` | → `{a: 1, b: 2}` | `++` (shallow only) |
| `nameSet({a: 1})` | → `["a"]` | Manual pluck |
| `valueSet({a: 1})` | → `[1]` | `payload pluck $` |
| `someEntry(obj, condition)` | Check if any entry matches | Manual pluck + filter |
| `everyEntry(obj, condition)` | Check if all entries match | Manual pluck + reduce |
| `divideBy({a:1,b:2,c:3}, 2)` | Split object into chunks | Manual implementation |

### dw::Runtime

```dwl
import * from dw::Runtime
```

| Function | Description | DW 1.0 Equivalent |
|----------|-------------|-------------------|
| `try(() -> expression)` | Try/catch returning {success, result, error} | No equivalent |
| `fail("message")` | Throw error | No equivalent |
| `failIf(value, condition)` | Conditional error | No equivalent |
| `wait(expression, timeout)` | Add timeout | No equivalent |
| `orelse(expression, fallback)` | Fallback on error | No equivalent |
| `prop("property.name")` | Read system property | No equivalent |

---

## Performance Differences

### What's Faster in DW 2.0

| Feature | DW 1.0 | DW 2.0 | Impact |
|---------|--------|--------|--------|
| **Lazy evaluation** | Eager — everything evaluated | Lazy — values evaluated when needed | Large payloads use less memory |
| **Streaming** | Full payload in memory | Streaming support for JSON/XML/CSV | Process GB-sized files |
| **Tail recursion** | No optimization | `@TailRec` annotation | No stack overflow on deep recursion |
| **Type system** | Runtime type checks | Compile-time type inference | Faster execution, earlier errors |
| **Module loading** | All functions loaded | Import only what you use | Reduced overhead |
| **String interpolation** | Concatenation with `++` | Native `$(...)` interpolation | Slightly faster string building |

### Streaming in DW 2.0

DW 2.0 supports streaming for large payloads. Enable it with:

```dwl
%dw 2.0
output application/json deferred=true
---
// This transform streams — doesn't load entire payload into memory
payload map (item) -> {
    id: item.id,
    name: item.name
}
```

**When to use streaming:**
- Input payload > 10 MB
- Processing millions of records
- Memory-constrained environments

**When NOT to use streaming:**
- You need `sizeOf(payload)` (requires full load)
- You need `groupBy` (requires full dataset)
- You need `orderBy` (requires full dataset)
- You access the same data multiple times

### Tail Recursion

```dwl
// DW 2.0 — annotate recursive functions to prevent stack overflow
%dw 2.0
output application/json

@TailRec()
fun flatten(items: Array, acc: Array = []): Array =
    if (isEmpty(items)) acc
    else if (items[0] is Array) flatten(items[0] ++ items[1 to -1], acc)
    else flatten(items[1 to -1] default [], acc << items[0])
---
flatten([[1, [2, 3]], [4, [5, [6]]]])
// Works on deeply nested arrays without stack overflow
```

---

## Gotchas & Breaking Changes

Non-obvious differences that cause bugs during migration.

### 1. `sizeOf` on Null

```dwl
// DW 1.0 — sizeOf null returns 0
sizeOf null   // 0

// DW 2.0 — sizeOf null throws error
sizeOf(null)  // ERROR: Cannot call sizeOf on null
// Fix:
sizeOf(payload default [])
```

### 2. `match` Keyword Changed

```dwl
// DW 1.0 — match was for regex matching
"abc123" match /([a-z]+)([0-9]+)/
// Returns: ["abc123", "abc", "123"]

// DW 2.0 — match is for pattern matching
// Use `scan` for regex capture groups
"abc123" scan /([a-z]+)([0-9]+)/
// Returns: [["abc123", "abc", "123"]]

// DW 2.0 — match is for type/value pattern matching
payload match {
    case is String -> "string"
    case is Number -> "number"
    else -> "other"
}
```

### 3. `null` vs `Null` Type

```dwl
// DW 1.0
payload is :null   // type check

// DW 2.0
payload is Null    // Capital N
// or just:
payload == null    // equality check (preferred)
```

### 4. Number Precision

```dwl
// DW 1.0 — limited precision
1.1 + 2.2   // might produce 3.3000000000000003

// DW 2.0 — uses BigDecimal internally
1.1 + 2.2   // 3.3 (exact)

// BUT: conversion to Java Double can still lose precision
(1.1 + 2.2) as String   // "3.3" (correct)
```

### 5. Object Key Order

```dwl
// DW 1.0 — object key order not guaranteed
// DW 2.0 — object key order is preserved (insertion order)

// This means: in DW 2.0, the output field order matches your transform order
{
    z: 1,
    a: 2,
    m: 3
}
// Output will be: {"z": 1, "a": 2, "m": 3} — guaranteed
```

### 6. `mapObject` Key Type

```dwl
// DW 1.0 — key is a String
payload mapObject ((value, key) -> { (key): value })

// DW 2.0 — key is a Key type (not String)
payload mapObject (value, key) -> { (key): value }
// If you need the key as String:
payload mapObject (value, key) -> { (key as String): value }
```

### 7. `splitBy` on Empty String

```dwl
// DW 1.0
"" splitBy ","   // [""]

// DW 2.0
"" splitBy ","   // [""]  (same, but check your assumptions)
// "a,,b" splitBy ","
// DW 1.0: ["a", "", "b"]
// DW 2.0: ["a", "", "b"]  (same)
```

### 8. Boolean Coercion

```dwl
// DW 1.0 — "true"/"false" strings auto-coerce
payload.active   // might auto-coerce in some contexts

// DW 2.0 — explicit coercion required
payload.active as Boolean   // explicit
// "true" as Boolean → true
// "false" as Boolean → false
// "yes" as Boolean → ERROR (not auto-coerced)
```

### 9. XML Repeating Elements

```dwl
// Both versions — but a common migration bug:
// XML with single element: payload.root.item returns the element
// XML with multiple elements: payload.root.*item returns all

// DW 2.0 best practice — always use .* for potentially repeating elements
payload.root.*item default []
// This works whether there's 0, 1, or many items
```

### 10. `now` vs `now()`

```dwl
// DW 1.0
now   // keyword, no parentheses

// DW 2.0
now()   // function call, requires parentheses
// Forgetting () is a common migration bug — DW 2.0 treats `now` as a variable name
```

---

## Automated Migration Tips

### Find-and-Replace Patterns

Use these regex patterns for bulk conversion. Run in order.

| # | Find (Regex) | Replace | Notes |
|---|---|---|---|
| 1 | `^%dw 1\.0` | `%dw 2.0` | Version declaration |
| 2 | `^%output ` | `output ` | Output declaration |
| 3 | `^%var ` | `var ` | Variable declarations |
| 4 | `^%namespace (\w+) (.+)` | `ns $1 $2` | Namespace declarations |
| 5 | `^%function (\w+)\(` | `fun $1(` | Function declarations (add `=` manually) |
| 6 | `:string` | `String` | Type names |
| 7 | `:number` | `Number` | Type names |
| 8 | `:boolean` | `Boolean` | Type names |
| 9 | `:object` | `Object` | Type names |
| 10 | `:array` | `Array` | Type names |
| 11 | `:date\b` | `Date` | Type names (word boundary to avoid `:datetime`) |
| 12 | `:datetime` | `DateTime` | Type names |
| 13 | `:null` | `Null` | Type names |
| 14 | `\bnow\b(?!\()` | `now()` | `now` → `now()` (only if not already `now()`) |

### What Can't Be Auto-Replaced (Manual Review Required)

| Pattern | Why Manual |
|---------|-----------|
| `when ... otherwise` → `if ... else` | Word order reversal, complex nesting |
| `using (x = val)` → `do { var x = val --- }` | Structural rewrite |
| `((param) ->` → `(param) ->` | Need to verify not nested parens |
| `flowVars.x` → `vars.x` | Verify context is correct |
| `message.inboundProperties` → `attributes` | Sub-property mapping varies |
| `exception.message` → `error.description` | Property names differ |
| `%function name(args) body` → `fun name(args) = body` | Need `=` and possibly type annotations |

### Anypoint Studio Migration Assistant

Anypoint Studio includes a built-in migration tool:

1. **File > Import > Mule > Mule Project from Mule 3**
2. Studio converts Mule 3 XML configs to Mule 4 format
3. DataWeave transforms are **partially** migrated — review each one
4. The assistant handles: `%dw 1.0` → `%dw 2.0`, `%output` → `output`, type name casing
5. The assistant does **NOT** handle: `when/otherwise`, `using`, MEL expressions, context variables
6. Always test every transform after migration

---

## Extended Migration Checklist

Comprehensive checklist covering syntax, context, testing, and connectors.

### Syntax Migration
- [ ] `%dw 1.0` → `%dw 2.0`
- [ ] `%output` → `output`
- [ ] `%var` → `var`
- [ ] `%function name(args) body` → `fun name(args): Type = body`
- [ ] `%namespace prefix uri` → `ns prefix uri`
- [ ] `when X otherwise Y` → `if (X) ... else Y`
- [ ] `using (x = val)` → `do { var x = val --- }`
- [ ] Type names: `:string` → `String`, `:number` → `Number`, etc.
- [ ] `as :type` → `as Type`
- [ ] `is :type` → `is Type`
- [ ] Lambda: `((item) ->` → `(item) ->`
- [ ] `now` → `now()`
- [ ] String interpolation: `"x" ++ var` → `"x $(var)"`

### Context Variables
- [ ] `flowVars.x` → `vars.x`
- [ ] `sessionVars.x` → *(removed — use Object Store or vars)*
- [ ] `recordVars.x` → *(removed — use vars in batch)*
- [ ] `message.inboundProperties['http.method']` → `attributes.method`
- [ ] `message.inboundProperties['http.query.params']` → `attributes.queryParams`
- [ ] `message.inboundProperties['http.uri.params']` → `attributes.uriParams`
- [ ] `message.inboundProperties['Content-Type']` → `attributes.headers.'content-type'`
- [ ] `message.outboundProperties` → *(set in connector config)*
- [ ] `exception.message` → `error.description`
- [ ] `exception.causeException` → `error.cause`
- [ ] `message.id` → `correlationId`

### MEL Expressions
- [ ] Replace all `#[mel:expression]` with `#[dw:expression]`
- [ ] `#[payload.field]` → `#[payload.field]` (same, but now DW)
- [ ] `#[flowVars.x]` → `#[vars.x]`
- [ ] `#[server.dateTime]` → `#[now()]`
- [ ] Java interop: `#[new java.util.Date()]` → `#[now()]`
- [ ] Ternary: `#[x ? y : z]` → `#[if (x) y else z]`

### Testing (MUnit)
- [ ] Update MUnit XML schema to MUnit 2
- [ ] `<munit:assert-on-equals>` → `<munit-tools:assert-that is="#[MunitTools::equalTo()]" />`
- [ ] `<munit:set payload="...">` → `<munit:set-event><munit:payload>` structure
- [ ] `<mock:when messageProcessor>` → `<munit-tools:mock-when processor>`
- [ ] Update all DW expressions in tests to DW 2.0 syntax

### Built-in Modules
- [ ] Replace custom string functions with `import from dw::core::Strings`
- [ ] Replace custom array functions with `import from dw::core::Arrays`
- [ ] Replace custom object functions with `import from dw::core::Objects`
- [ ] Replace null-check wrappers with `default` and `try` from `dw::Runtime`

### Final Validation
- [ ] Run all MUnit tests
- [ ] Test with null/empty inputs (DW 2.0 is stricter)
- [ ] Verify XML namespace handling
- [ ] Verify date formatting patterns
- [ ] Check for `sizeOf(null)` — add `default []` guards
- [ ] Verify `match` usage — `match` for pattern matching, `scan` for regex

---

[Back to all patterns](../README.md)
