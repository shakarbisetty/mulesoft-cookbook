# MEL to DataWeave 2.0 — Complete Migration Guide

> A dedicated guide for teams migrating Mule Expression Language (MEL) to DataWeave 2.0 in Mule 4.

MEL (Mule Expression Language) was the default expression language in Mule 3. In Mule 4, **MEL is completely removed** — all expressions must be written in DataWeave 2.0. This guide provides a comprehensive mapping for every common MEL pattern.

---

## Table of Contents

- [Why Migrate from MEL](#why-migrate-from-mel)
- [Quick Reference Table](#quick-reference-table)
- [Payload Access](#payload-access)
- [Context Variables](#context-variables)
- [HTTP Properties](#http-properties)
- [String Operations](#string-operations)
- [Number Operations](#number-operations)
- [Date & Time](#date--time)
- [Boolean & Conditional Logic](#boolean--conditional-logic)
- [Collection Operations](#collection-operations)
- [Null Handling](#null-handling)
- [Java Interop](#java-interop)
- [Groovy Script Migration](#groovy-script-migration)
- [Real-World Migration Examples](#real-world-migration-examples)
- [MEL Functions Quick Map](#mel-functions-quick-map)
- [Migration Checklist](#migration-checklist)

---

## Why Migrate from MEL

| Aspect | MEL (Mule 3) | DataWeave 2.0 (Mule 4) |
|--------|-------------|------------------------|
| **Status** | Deprecated, no updates | Actively developed |
| **Type Safety** | Runtime errors only | Compile-time type checking |
| **Null Handling** | Frequent NPEs | `default` operator, null-safe navigation |
| **Transformations** | Basic — complex transforms need Java/Groovy | Full transformation language |
| **Performance** | Java reflection overhead | Optimized engine with streaming |
| **Modules** | None | Rich module system (`dw::core::*`) |
| **Testing** | Hard to unit test | Full MUnit integration |

**Bottom line:** Every `#[mel:expression]` and `#[expression]` in Mule 3 must become a DataWeave expression in Mule 4. There is no compatibility layer.

---

## Quick Reference Table

The 40 most common MEL → DW 2.0 conversions.

| # | MEL Expression | DataWeave 2.0 |
|---|---|---|
| 1 | `#[payload]` | `payload` |
| 2 | `#[payload.name]` | `payload.name` |
| 3 | `#[payload.items[0]]` | `payload.items[0]` |
| 4 | `#[payload.size()]` | `sizeOf(payload)` |
| 5 | `#[payload.isEmpty()]` | `isEmpty(payload)` |
| 6 | `#[flowVars.orderId]` | `vars.orderId` |
| 7 | `#[flowVars['order-id']]` | `vars.'order-id'` |
| 8 | `#[sessionVars.token]` | *(removed — use vars or Object Store)* |
| 9 | `#[recordVars.count]` | *(removed — use vars in batch)* |
| 10 | `#[message.id]` | `correlationId` |
| 11 | `#[message.rootId]` | `correlationId` |
| 12 | `#[message.correlationId]` | `correlationId` |
| 13 | `#[message.inboundProperties['http.method']]` | `attributes.method` |
| 14 | `#[message.inboundProperties['http.status']]` | `attributes.statusCode` |
| 15 | `#[message.inboundProperties['http.request.uri']]` | `attributes.requestUri` |
| 16 | `#[message.inboundProperties['http.query.params']]` | `attributes.queryParams` |
| 17 | `#[message.inboundProperties['http.uri.params'].id]` | `attributes.uriParams.id` |
| 18 | `#[message.inboundProperties['Content-Type']]` | `attributes.headers.'content-type'` |
| 19 | `#[message.inboundProperties['Authorization']]` | `attributes.headers.authorization` |
| 20 | `#[message.outboundProperties['Content-Type']]` | *(set in HTTP response config)* |
| 21 | `#[exception.message]` | `error.description` |
| 22 | `#[exception.causeException.message]` | `error.cause.description` |
| 23 | `#[exception.cause.class.name]` | `error.errorType.identifier` |
| 24 | `#[server.dateTime]` | `now()` |
| 25 | `#[server.dateTime.format('yyyy-MM-dd')]` | `now() as String {format: "yyyy-MM-dd"}` |
| 26 | `#[server.nanoTime()]` | *(use `now()` with milliseconds)* |
| 27 | `#[java.util.UUID.randomUUID().toString()]` | `uuid()` |
| 28 | `#[System.getenv('VAR')]` | `p('property.name')` or `Mule::p('property.name')` |
| 29 | `#[app.name]` | `p('app.name')` |
| 30 | `#[mule.home]` | `p('mule.home')` |
| 31 | `#[null]` | `null` |
| 32 | `#[true]` / `#[false]` | `true` / `false` |
| 33 | `#['string literal']` | `"string literal"` |
| 34 | `#[123]` | `123` |
| 35 | `#[payload.amount > 1000]` | `payload.amount > 1000` |
| 36 | `#[payload.name == 'John']` | `payload.name == "John"` |
| 37 | `#[payload.name != null]` | `payload.name != null` or `! isEmpty(payload.name)` |
| 38 | `#[payload.amount > 100 && payload.active == true]` | `payload.amount > 100 and payload.active == true` |
| 39 | `#[payload.type == 'A' \|\| payload.type == 'B']` | `payload."type" == "A" or payload."type" == "B"` |
| 40 | `#[message.payloadAs(java.lang.String)]` | `payload as String` |

---

## Payload Access

### Simple Fields

```
// MEL
#[payload]
#[payload.name]
#[payload.address.city]

// DW 2.0 — identical syntax
payload
payload.name
payload.address.city
```

### Array Access

```
// MEL
#[payload.items[0]]
#[payload.items[payload.items.size() - 1]]
#[payload.items.size()]

// DW 2.0
payload.items[0]
payload.items[-1]         // last element — cleaner
sizeOf(payload.items)
```

### Dynamic Field Access

```
// MEL — using bracket notation
#[payload[flowVars.fieldName]]

// DW 2.0
payload[vars.fieldName]
```

### Type Casting

```
// MEL
#[payload.amount.toString()]
#[Integer.parseInt(payload.count)]
#[message.payloadAs(java.lang.String)]

// DW 2.0
payload.amount as String
payload.count as Number
payload as String
```

---

## Context Variables

### Flow Variables

```xml
<!-- Mule 3 — set a flow variable -->
<set-variable variableName="orderId" value="#[payload.id]" />
<!-- Read it -->
<logger message="#[flowVars.orderId]" />

<!-- Mule 4 — identical set-variable, different read syntax -->
<set-variable variableName="orderId" value="#[payload.id]" />
<!-- Read it -->
<logger message="#[vars.orderId]" />
```

### Session Variables (Removed)

```xml
<!-- Mule 3 -->
<set-session-variable variableName="token" value="#[payload.token]" />
<logger message="#[sessionVars.token]" />

<!-- Mule 4 — session variables don't exist -->
<!-- Option 1: Use flow variables (same flow only) -->
<set-variable variableName="token" value="#[payload.token]" />

<!-- Option 2: Use Object Store (persists across flows) -->
<os:store key="token" objectStore="myStore">
    <os:value>#[payload.token]</os:value>
</os:store>
```

### Record Variables in Batch (Removed)

```xml
<!-- Mule 3 — batch step -->
<set-variable variableName="retryCount" value="#[recordVars.retryCount + 1]" />

<!-- Mule 4 — batch step -->
<!-- recordVars no longer exists. Use vars within the batch scope. -->
<set-variable variableName="retryCount" value="#[vars.retryCount default 0 + 1]" />
```

### Property Placeholders

```
// MEL
#[app.registry['myProperty']]
#[System.getenv('MY_ENV_VAR')]
#['${my.config.property}']

// DW 2.0
p('my.config.property')
// or in inline expressions:
Mule::p('my.config.property')
```

---

## HTTP Properties

### Inbound (Request) Properties

```
// MEL — HTTP Listener request
#[message.inboundProperties['http.method']]           // GET, POST, etc.
#[message.inboundProperties['http.request.uri']]       // /api/v1/orders
#[message.inboundProperties['http.request.path']]      // /orders
#[message.inboundProperties['http.query.params'].page]  // ?page=1
#[message.inboundProperties['http.uri.params'].id]     // /orders/{id}
#[message.inboundProperties['Authorization']]          // Bearer xxx
#[message.inboundProperties['Content-Type']]           // application/json
#[message.inboundProperties['X-Custom-Header']]        // custom value

// DW 2.0 — HTTP Listener attributes
attributes.method                                       // GET, POST, etc.
attributes.requestUri                                   // /api/v1/orders
attributes.requestPath                                  // /orders
attributes.queryParams.page                             // ?page=1
attributes.uriParams.id                                 // /orders/{id}
attributes.headers.authorization                        // Bearer xxx
attributes.headers.'content-type'                       // application/json
attributes.headers.'x-custom-header'                    // custom value
```

**Important:** In Mule 4, HTTP header names in `attributes.headers` are **always lowercase**.

### Outbound (Response) Properties

```xml
<!-- Mule 3 — set response headers -->
<set-property propertyName="Content-Type" value="application/json" />
<set-property propertyName="X-Correlation-Id" value="#[message.id]" />

<!-- Mule 4 — no outbound properties. Set in HTTP Listener response config -->
<http:listener config-ref="HTTP_Config" path="/api/orders">
    <http:response statusCode="200">
        <http:headers>#[%dw 2.0 output application/java --- {
            "Content-Type": "application/json",
            "X-Correlation-Id": correlationId
        }]</http:headers>
    </http:response>
</http:listener>
```

### HTTP Requester Response

```
// MEL — after HTTP request
#[message.inboundProperties['http.status']]
#[message.inboundProperties['http.reason']]
#[message.inboundProperties['Content-Type']]

// DW 2.0 — HTTP requester response attributes
attributes.statusCode
attributes.reasonPhrase
attributes.headers.'content-type'
```

---

## String Operations

| MEL | DW 2.0 | Result |
|---|---|---|
| `#[payload.toUpperCase()]` | `upper(payload)` | `"HELLO"` |
| `#[payload.toLowerCase()]` | `lower(payload)` | `"hello"` |
| `#[payload.trim()]` | `trim(payload)` | `"hello"` |
| `#[payload.length()]` | `sizeOf(payload)` | `5` |
| `#[payload.substring(0, 5)]` | `payload[0 to 4]` | First 5 chars |
| `#[payload.substring(3)]` | `payload[3 to -1]` | From index 3 to end |
| `#[payload.indexOf("world")]` | *(use regex or find)* | Index of substring |
| `#[payload.contains("world")]` | `payload contains "world"` | `true`/`false` |
| `#[payload.startsWith("Hello")]` | `payload startsWith "Hello"` | `true`/`false` |
| `#[payload.endsWith("world")]` | `payload endsWith "world"` | `true`/`false` |
| `#[payload.replace("old", "new")]` | `payload replace "old" with "new"` | Replaced string |
| `#[payload.replaceAll("[0-9]", "")]` | `payload replace /[0-9]/ with ""` | Regex replace |
| `#[payload.split(",")]` | `payload splitBy ","` | Array of strings |
| `#[payload.isEmpty()]` | `isEmpty(payload)` | `true`/`false` |
| `#["Hello " + payload.name]` | `"Hello $(payload.name)"` | Interpolation |
| `#[payload + " " + flowVars.suffix]` | `"$(payload) $(vars.suffix)"` | Concatenation |

### String Formatting

```
// MEL
#[String.format("Order %s: $%.2f", payload.id, payload.total)]

// DW 2.0
"Order $(payload.id): \$$(payload.total as String {format: '#0.00'})"
```

---

## Number Operations

| MEL | DW 2.0 | Notes |
|---|---|---|
| `#[payload.amount + 100]` | `payload.amount + 100` | Same |
| `#[payload.amount * 0.1]` | `payload.amount * 0.1` | Same |
| `#[Math.round(payload.amount)]` | `round(payload.amount)` | Built-in |
| `#[Math.ceil(payload.amount)]` | `ceil(payload.amount)` | Built-in |
| `#[Math.floor(payload.amount)]` | `floor(payload.amount)` | Built-in |
| `#[Math.abs(payload.amount)]` | `abs(payload.amount)` | Built-in |
| `#[Math.max(a, b)]` | `max([a, b])` | Built-in |
| `#[Math.min(a, b)]` | `min([a, b])` | Built-in |
| `#[Math.random()]` | `random() as Number` | Built-in |
| `#[payload.amount % 10]` | `payload.amount mod 10` | `mod` not `%` |
| `#[Integer.parseInt(payload.count)]` | `payload.count as Number` | Type cast |

---

## Date & Time

| MEL | DW 2.0 |
|---|---|
| `#[server.dateTime]` | `now()` |
| `#[server.dateTime.format('yyyy-MM-dd')]` | `now() as String {format: "yyyy-MM-dd"}` |
| `#[server.dateTime.format("yyyy-MM-dd'T'HH:mm:ss")]` | `now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"}` |
| `#[new java.util.Date()]` | `now()` |
| `#[new java.util.Date().getTime()]` | `now() as Number` (epoch millis) |
| `#[org.apache.commons.lang3.time.DateUtils.addDays(new Date(), 7)]` | `now() + \|P7D\|` |
| `#[org.apache.commons.lang3.time.DateUtils.addHours(new Date(), 2)]` | `now() + \|PT2H\|` |

### Date Parsing

```
// MEL
#[new java.text.SimpleDateFormat('MM/dd/yyyy').parse(payload.date)]

// DW 2.0
payload.date as Date {format: "MM/dd/yyyy"}
```

### Date Comparison

```
// MEL
#[new java.text.SimpleDateFormat('yyyy-MM-dd').parse(payload.expiry).before(new java.util.Date())]

// DW 2.0
(payload.expiry as Date) < now()
```

---

## Boolean & Conditional Logic

### Ternary Operator

```
// MEL
#[payload.amount > 1000 ? 'priority' : 'standard']

// DW 2.0
if (payload.amount > 1000) "priority" else "standard"
```

### Complex Conditions

```
// MEL
#[payload.type == 'A' && payload.amount > 100 || payload.vip == true]

// DW 2.0
(payload."type" == "A" and payload.amount > 100) or payload.vip == true
```

**Note:** `type` is a reserved word in DW 2.0 — use quotes: `payload."type"`.

### Null Check

```
// MEL
#[payload.name != null ? payload.name : 'Unknown']
#[payload.name != null && !payload.name.isEmpty() ? payload.name : 'Unknown']

// DW 2.0
payload.name default "Unknown"
// or for empty string check:
if (! isEmpty(payload.name)) payload.name else "Unknown"
```

### Instanceof / Type Check

```
// MEL
#[payload instanceof java.lang.String]
#[payload instanceof java.util.List]
#[payload instanceof java.util.Map]

// DW 2.0
payload is String
payload is Array
payload is Object
```

---

## Collection Operations

### Array/List Operations

| MEL | DW 2.0 |
|---|---|
| `#[payload.size()]` | `sizeOf(payload)` |
| `#[payload.isEmpty()]` | `isEmpty(payload)` |
| `#[payload.contains('item')]` | `payload contains "item"` |
| `#[payload.get(0)]` | `payload[0]` |
| `#[payload.subList(0, 5)]` | `payload[0 to 4]` |
| `#[java.util.Collections.sort(payload)]` | `payload orderBy $` |
| `#[java.util.Collections.reverse(payload)]` | `payload[-1 to 0]` |

### Iterating

```
// MEL — typically done in a for-each scope, not in expression
// For transformation, MEL used custom Java or Groovy

// DW 2.0 — native transformation
payload map (item) -> {
    name: upper(item.name),
    total: item.price * item.qty
}
```

### Filtering

```
// MEL — typically filter with Java or choice router
#[payload.stream().filter(x -> x.active).collect(Collectors.toList())]

// DW 2.0
payload filter $.active == true
```

---

## Null Handling

One of the biggest improvements in DW 2.0 over MEL.

```
// MEL — verbose null checks everywhere
#[payload.customer != null ? (payload.customer.address != null ? payload.customer.address.city : 'N/A') : 'N/A']

// DW 2.0 — one-liner with default
payload.customer.address.city default "N/A"
```

```
// MEL — check multiple fields
#[payload.name != null && payload.email != null && payload.phone != null]

// DW 2.0
(payload.name?) and (payload.email?) and (payload.phone?)
// or
!isEmpty(payload.name) and !isEmpty(payload.email) and !isEmpty(payload.phone)
```

---

## Java Interop

### Static Method Calls

```
// MEL
#[java.util.UUID.randomUUID().toString()]
#[org.apache.commons.lang3.StringUtils.abbreviate(payload.desc, 50)]
#[org.apache.commons.codec.digest.DigestUtils.md5Hex(payload)]

// DW 2.0 — prefer native DW functions
uuid()                                                          // UUID
payload.desc[0 to 46] ++ "..."                                  // abbreviate
// For MD5, use dw::Crypto module:
import dw::Crypto
Crypto::hashWith(payload as Binary, "MD5")
```

### Instance Method Calls

```
// MEL — calling methods on Java objects
#[payload.getClass().getSimpleName()]
#[payload.toString()]

// DW 2.0 — use native type system
typeOf(payload)
payload as String
```

### Java Module (DW 2.0)

For Java calls that have no DW equivalent:

```dwl
%dw 2.0
import java!java::util::UUID
import java!java::net::URLEncoder
output application/json
---
{
    id: UUID::randomUUID() as String,
    encoded: URLEncoder::encode("hello world", "UTF-8")
}
```

---

## Groovy Script Migration

Mule 3 projects often use `<scripting:component>` with Groovy for complex logic. In Mule 4, replace with DataWeave.

### Simple Groovy → DataWeave

```groovy
// Groovy (Mule 3)
def result = []
payload.each { item ->
    if (item.active) {
        result.add([
            name: item.name.toUpperCase(),
            total: item.price * item.quantity
        ])
    }
}
return result
```

```dwl
// DW 2.0 (Mule 4)
%dw 2.0
output application/json
---
payload filter $.active map (item) -> {
    name: upper(item.name),
    total: item.price * item.quantity
}
```

### Groovy Map Manipulation → DataWeave

```groovy
// Groovy
def result = [:]
payload.each { key, value ->
    result[key.toUpperCase()] = value.trim()
}
return result
```

```dwl
// DW 2.0
%dw 2.0
output application/json
---
payload mapObject (value, key) -> {
    (upper(key as String)): trim(value)
}
```

### Groovy Aggregation → DataWeave

```groovy
// Groovy
def total = 0
def count = 0
payload.each { item ->
    total += item.amount
    count++
}
return [total: total, average: total / count]
```

```dwl
// DW 2.0
%dw 2.0
output application/json
---
{
    total: sum(payload.amount),
    average: avg(payload.amount)
}
```

### Groovy String Processing → DataWeave

```groovy
// Groovy — parse "KEY1=VAL1;KEY2=VAL2" into a map
def result = [:]
payload.split(";").each { pair ->
    def parts = pair.split("=")
    result[parts[0]] = parts[1]
}
return result
```

```dwl
// DW 2.0
%dw 2.0
output application/json
---
payload splitBy ";" reduce (pair, acc = {}) ->
    acc ++ do {
        var parts = pair splitBy "="
        ---
        { (parts[0]): parts[1] }
    }
```

---

## Real-World Migration Examples

### Example 1: Choice Router Conditions

```xml
<!-- Mule 3 — MEL in choice router -->
<choice>
    <when expression="#[payload.type == 'ORDER' &amp;&amp; payload.status == 'NEW']">
        <flow-ref name="processNewOrder" />
    </when>
    <when expression="#[payload.type == 'ORDER' &amp;&amp; payload.status == 'CANCEL']">
        <flow-ref name="processCancellation" />
    </when>
    <when expression="#[payload.type == 'RETURN']">
        <flow-ref name="processReturn" />
    </when>
    <otherwise>
        <flow-ref name="handleUnknown" />
    </otherwise>
</choice>

<!-- Mule 4 — DW in choice router -->
<choice>
    <when expression='#[payload."type" == "ORDER" and payload.status == "NEW"]'>
        <flow-ref name="processNewOrder" />
    </when>
    <when expression='#[payload."type" == "ORDER" and payload.status == "CANCEL"]'>
        <flow-ref name="processCancellation" />
    </when>
    <when expression='#[payload."type" == "RETURN"]'>
        <flow-ref name="processReturn" />
    </when>
    <otherwise>
        <flow-ref name="handleUnknown" />
    </otherwise>
</choice>
```

**Key changes:** `&&` → `and`, double quotes for strings, `type` quoted as reserved word.

### Example 2: Logger Expressions

```xml
<!-- Mule 3 -->
<logger message="Processing order #[payload.orderId] for customer #[flowVars.customerId]. Items: #[payload.items.size()]. Total: $#[payload.total]" level="INFO" />

<!-- Mule 4 -->
<logger message='#["Processing order $(payload.orderId) for customer $(vars.customerId). Items: $(sizeOf(payload.items)). Total: \$$(payload.total)"]' level="INFO" />
```

### Example 3: Set-Variable with Transformation

```xml
<!-- Mule 3 — MEL expression in set-variable -->
<set-variable variableName="customerIds"
    value="#[payload.collect{ it.customerId }.unique()]" />

<!-- Mule 4 — DataWeave expression -->
<set-variable variableName="customerIds"
    value="#[payload.customerId distinctBy $]" />
```

### Example 4: HTTP Request URL Building

```xml
<!-- Mule 3 -->
<http:request config-ref="HTTP_Config" path="/api/customers/#[flowVars.customerId]/orders" method="GET">
    <http:request-builder>
        <http:query-param paramName="status" value="#[flowVars.statusFilter]" />
        <http:query-param paramName="page" value="#[flowVars.page]" />
        <http:header headerName="Authorization" value="#['Bearer ' + flowVars.token]" />
    </http:request-builder>
</http:request>

<!-- Mule 4 -->
<http:request config-ref="HTTP_Config" path="#['/api/customers/$(vars.customerId)/orders']" method="GET">
    <http:query-params>#[%dw 2.0 output application/java --- {
        "status": vars.statusFilter,
        "page": vars.page as String
    }]</http:query-params>
    <http:headers>#[%dw 2.0 output application/java --- {
        "Authorization": "Bearer $(vars.token)"
    }]</http:headers>
</http:request>
```

### Example 5: Error Handling

```xml
<!-- Mule 3 -->
<catch-exception-strategy>
    <set-payload value='#[["error": exception.message, "code": 500, "timestamp": server.dateTime.format("yyyy-MM-dd HH:mm:ss"), "correlationId": message.id]]' />
    <set-property propertyName="http.status" value="#[500]" />
    <set-property propertyName="Content-Type" value="application/json" />
</catch-exception-strategy>

<!-- Mule 4 -->
<error-handler>
    <on-error-propagate type="ANY">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: error.description,
    errorType: error.errorType.identifier,
    code: 500,
    timestamp: now() as String {format: "yyyy-MM-dd HH:mm:ss"},
    correlationId: correlationId
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </on-error-propagate>
</error-handler>
```

### Example 6: Database Query Parameter Binding

```xml
<!-- Mule 3 -->
<db:select config-ref="DB_Config">
    <db:parameterized-query>
        SELECT * FROM orders WHERE customer_id = #[flowVars.customerId] AND status = #[payload.status]
    </db:parameterized-query>
</db:select>

<!-- Mule 4 -->
<db:select config-ref="DB_Config">
    <db:sql>SELECT * FROM orders WHERE customer_id = :customerId AND status = :status</db:sql>
    <db:input-parameters>#[%dw 2.0 output application/java --- {
        "customerId": vars.customerId,
        "status": payload.status
    }]</db:input-parameters>
</db:select>
```

### Example 7: For-Each with Counter

```xml
<!-- Mule 3 -->
<foreach collection="#[payload.items]" counterVariableName="counter">
    <logger message="Processing item #[counter]: #[payload.name]" />
    <set-variable variableName="total" value="#[flowVars.total + payload.amount]" />
</foreach>

<!-- Mule 4 — for-each syntax same, variable access different -->
<foreach collection="#[payload.items]" counterVariableName="counter">
    <logger message='#["Processing item $(vars.counter): $(payload.name)"]' />
    <set-variable variableName="total" value="#[vars.total + payload.amount]" />
</foreach>
```

### Example 8: Scatter-Gather Result Processing

```xml
<!-- Mule 3 — result is a MuleMessageCollection -->
<scatter-gather>
    <flow-ref name="getCustomerData" />
    <flow-ref name="getOrderHistory" />
    <flow-ref name="getPreferences" />
</scatter-gather>
<!-- MEL to combine results -->
<set-payload value="#[[
    'customer': message.payload[0].payload,
    'orders': message.payload[1].payload,
    'preferences': message.payload[2].payload
]]" />

<!-- Mule 4 — result is an Object with numeric keys -->
<scatter-gather>
    <route><flow-ref name="getCustomerData" /></route>
    <route><flow-ref name="getOrderHistory" /></route>
    <route><flow-ref name="getPreferences" /></route>
</scatter-gather>
<ee:transform>
    <ee:message>
        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    customer: payload."0".payload,
    orders: payload."1".payload,
    preferences: payload."2".payload
}]]></ee:set-payload>
    </ee:message>
</ee:transform>
```

### Example 9: File Connector Metadata

```
// MEL (Mule 3) — after reading a file
#[message.inboundProperties.originalFilename]
#[message.inboundProperties.directory]
#[message.inboundProperties.fileSize]
#[message.inboundProperties.timestamp]

// DW 2.0 (Mule 4) — file connector attributes
attributes.fileName
attributes.directory
attributes.size
attributes.timestamp
```

### Example 10: Watermark / Since Query

```xml
<!-- Mule 3 — using objectStore with MEL -->
<poll frequency="60000">
    <watermark variable="lastSync"
        default-expression="#[server.dateTime.format('yyyy-MM-dd HH:mm:ss')]"
        update-expression="#[server.dateTime.format('yyyy-MM-dd HH:mm:ss')]" />
    <db:select config-ref="DB_Config">
        <db:parameterized-query>
            SELECT * FROM orders WHERE updated_at > #[flowVars.lastSync]
        </db:parameterized-query>
    </db:select>
</poll>

<!-- Mule 4 — using scheduler + watermark -->
<flow name="pollOrders">
    <scheduler>
        <scheduling-strategy><fixed-frequency frequency="60000" /></scheduling-strategy>
    </scheduler>
    <os:retrieve key="lastSync" objectStore="syncStore" target="lastSync">
        <os:default-value>#[now() - |P1D| as String {format: "yyyy-MM-dd HH:mm:ss"}]</os:default-value>
    </os:retrieve>
    <db:select config-ref="DB_Config">
        <db:sql>SELECT * FROM orders WHERE updated_at > :lastSync</db:sql>
        <db:input-parameters>#[{ "lastSync": vars.lastSync }]</db:input-parameters>
    </db:select>
    <os:store key="lastSync" objectStore="syncStore">
        <os:value>#[now() as String {format: "yyyy-MM-dd HH:mm:ss"}]</os:value>
    </os:store>
</flow>
```

---

## MEL Functions Quick Map

Alphabetical reference for every common MEL function and its DW 2.0 equivalent.

| MEL Function | DW 2.0 Equivalent |
|---|---|
| `.contains()` | `contains` operator |
| `.endsWith()` | `endsWith` operator |
| `.equals()` | `==` operator |
| `.format()` | `as String {format: "..."}` |
| `.get(index)` | `[index]` |
| `.getClass()` | `typeOf()` |
| `.isEmpty()` | `isEmpty()` |
| `.length()` / `.size()` | `sizeOf()` |
| `.replace()` | `replace ... with` |
| `.split()` | `splitBy` |
| `.startsWith()` | `startsWith` operator |
| `.substring()` | `[start to end]` |
| `.toLowerCase()` | `lower()` |
| `.toString()` | `as String` |
| `.toUpperCase()` | `upper()` |
| `.trim()` | `trim()` |
| `Collections.sort()` | `orderBy` |
| `Integer.parseInt()` | `as Number` |
| `Math.abs()` | `abs()` |
| `Math.ceil()` | `ceil()` |
| `Math.floor()` | `floor()` |
| `Math.max()` | `max()` |
| `Math.min()` | `min()` |
| `Math.random()` | `random()` |
| `Math.round()` | `round()` |
| `String.format()` | String interpolation `$()` |
| `UUID.randomUUID()` | `uuid()` |

---

## Migration Checklist

### Pre-Migration
- [ ] Inventory all MEL expressions in the Mule 3 project (search for `#[`)
- [ ] Identify which expressions are simple (direct replacement) vs. complex (need rewrite)
- [ ] List all Groovy/Java scripting components that need DW replacement
- [ ] Document all `flowVars`, `sessionVars`, `recordVars` usage

### Expression Migration
- [ ] Replace all `#[flowVars.x]` with `#[vars.x]`
- [ ] Replace all `#[sessionVars.x]` with Object Store or vars
- [ ] Replace all `#[message.inboundProperties[...]]` with `#[attributes....]`
- [ ] Remove all `#[message.outboundProperties[...]]` — set in connector config
- [ ] Replace `#[exception.message]` with `#[error.description]`
- [ ] Replace `#[message.id]` with `#[correlationId]`
- [ ] Replace `#[server.dateTime]` with `#[now()]`
- [ ] Replace all Java interop with native DW functions

### Connector Updates
- [ ] HTTP Listener: response headers in config, not set-property
- [ ] HTTP Requester: query-params and headers as DW maps
- [ ] Database: named parameters (:param) instead of inline MEL
- [ ] File: attributes instead of inboundProperties

### Groovy Scripts
- [ ] Identify all `<scripting:component>` blocks
- [ ] Rewrite each as DataWeave transform or DW inline expression
- [ ] For truly complex Java logic, use Java module in DW

### Validation
- [ ] Write MUnit 2 tests for every migrated expression
- [ ] Test null/empty edge cases (DW 2.0 is stricter)
- [ ] Verify header access (lowercase in Mule 4)
- [ ] Test error handling paths
- [ ] Compare output of old and new transforms with same test data

---

**See also:**
- [DW 1.0 → 2.0 Syntax Migration Guide](dw1-vs-dw2-migration.md)
- [DataWeave Anti-Patterns](common-mistakes.md)
- [DataWeave Patterns Repository](../README.md)
