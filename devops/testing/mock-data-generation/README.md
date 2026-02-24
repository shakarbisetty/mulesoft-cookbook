## Mock Data Generation
> DataWeave factories for realistic, deterministic test data and shared test resource libraries.

### When to Use
- You need consistent, reproducible test data across multiple MUnit tests
- You want to generate large datasets without maintaining massive JSON fixtures
- You need realistic data shapes (names, IDs, dates, addresses) that match production schemas
- You want a shared test-data module reusable across multiple Mule applications

### Configuration / Code

**Shared test data module — `src/test/resources/dwl/test-data.dwl`:**

```dataweave
%dw 2.0

// Deterministic pseudo-random using seed-based approach
fun seededValue(seed: Number, options: Array): String =
    options[seed mod sizeOf(options)]

// Name generators
var firstNames = ["James", "Maria", "David", "Sarah", "Michael", "Emma", "Robert", "Lisa", "William", "Anna"]
var lastNames = ["Smith", "Garcia", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson", "Taylor"]
var cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Antonio", "Dallas", "San Jose"]
var states = ["NY", "CA", "IL", "TX", "AZ", "TX", "TX", "CA"]
var streets = ["Main St", "Oak Ave", "Elm Dr", "Park Blvd", "Cedar Ln", "Pine Rd", "Maple Way", "First St"]

fun generatePerson(seed: Number) = {
    firstName: seededValue(seed, firstNames),
    lastName: seededValue(seed + 3, lastNames),
    email: lower(seededValue(seed, firstNames)) ++ "." ++ lower(seededValue(seed + 3, lastNames)) ++ "@example.com",
    phone: "+1-555-" ++ ((seed * 137 mod 900) + 100) as String ++ "-" ++ ((seed * 251 mod 9000) + 1000) as String
}

fun generateAddress(seed: Number) = {
    street: ((seed * 47 mod 9000) + 1000) as String ++ " " ++ seededValue(seed, streets),
    city: seededValue(seed + 1, cities),
    state: seededValue(seed + 1, states),
    zip: ((seed * 173 mod 90000) + 10000) as String
}

fun generateOrder(seed: Number) = {
    orderId: "ORD-" ++ ((seed * 31 mod 900000) + 100000) as String,
    customer: generatePerson(seed),
    shippingAddress: generateAddress(seed),
    items: (1 to ((seed mod 4) + 1)) map {
        sku: "SKU-" ++ ((seed * $ * 97 mod 90000) + 10000) as String,
        quantity: (seed * $ mod 10) + 1,
        unitPrice: ((seed * $ * 53 mod 10000) / 100) as Number {class: "java.math.BigDecimal"}
    },
    createdAt: |2025-01-01T00:00:00Z| + |P$(seed mod 365)D|,
    status: seededValue(seed, ["PENDING", "PROCESSING", "SHIPPED", "DELIVERED"])
}

fun generateId(prefix: String, seed: Number): String =
    prefix ++ "-" ++ ((seed * 31337 mod 9000000) + 1000000) as String

fun generateDate(seed: Number, baseDate: Date = |2025-01-01|): Date =
    baseDate + |P$(seed mod 365)D|

fun generateAmount(seed: Number, max: Number = 10000): Number =
    (seed * 7919 mod (max * 100)) / 100
```

**Using the shared module in MUnit tests:**

```xml
<munit:test name="order-processing-with-generated-data"
            description="Test order processing with factory-generated data">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Validate Payment"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {"approved": true}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value="#[output application/json --- readUrl('classpath://dwl/test-data.dwl').generateOrder(42)]"/>
        <flow-ref name="process-order-flow"/>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('PROCESSED')]"/>
    </munit:validation>
</munit:test>
```

**Bulk test data generation — `src/test/resources/dwl/bulk-test-data.dwl`:**

```dataweave
%dw 2.0
import * from dwl::test-data
output application/json

// Generate 500 deterministic orders for load/batch testing
---
(1 to 500) map generateOrder($)
```

**Parameterized test with generated data:**

```xml
<munit:test name="order-validation-parameterized"
            description="Test validation rules against multiple generated orders">

    <munit:execution>
        <set-variable variableName="testOrders"
                      value="#[output application/java --- (1 to 20) map readUrl('classpath://dwl/test-data.dwl').generateOrder($)]"/>

        <foreach collection="#[vars.testOrders]">
            <flow-ref name="validate-order-subflow"/>
        </foreach>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[vars.testOrders]"
            is="#[MunitTools::hasSize(MunitTools::equalTo(20))]"/>
    </munit:validation>
</munit:test>
```

**Date-safe test data — avoiding flaky time-dependent tests:**

```dataweave
%dw 2.0
output application/json

// BAD: test breaks when date changes
// var testDate = now()

// GOOD: fixed reference date for deterministic tests
var referenceDate = |2025-06-15T10:00:00Z|

fun generateTimeSensitiveOrder(seed: Number) = {
    orderId: "ORD-" ++ seed as String,
    createdAt: referenceDate - |P$(seed)D|,
    expiresAt: referenceDate + |P30D|,
    isExpired: (referenceDate + |P30D|) < referenceDate  // Always false in test context
}
---
{
    recentOrder: generateTimeSensitiveOrder(1),
    oldOrder: generateTimeSensitiveOrder(180),
    orders: (1 to 10) map generateTimeSensitiveOrder($)
}
```

### How It Works
1. The `test-data.dwl` module defines reusable generator functions that accept a numeric seed for determinism
2. Each generator (`generatePerson`, `generateAddress`, `generateOrder`) produces a complete, realistic data structure
3. The seed-based approach means `generateOrder(42)` always returns the exact same order, making tests fully reproducible
4. MUnit tests import the module via `readUrl('classpath://dwl/test-data.dwl')` and call generator functions directly
5. Bulk generation uses range expressions (`1 to 500`) mapped over generators for batch/load test scenarios
6. Date-sensitive data uses fixed reference dates instead of `now()` to prevent time-dependent test flakiness

### Gotchas
- **Deterministic test data (use seeds)**: Never use `random()` or `now()` in test data generators. Tests must produce identical results on every run. Use numeric seeds and modular arithmetic for pseudo-randomness
- **Date-dependent tests**: Tests that compare against `now()` break overnight. Always use fixed reference dates in test data and mock the current time if the flow uses it
- **DataWeave module loading**: `readUrl('classpath://...')` loads the module fresh each time. For performance in loops, load once into a variable before iterating
- **Type coercion in assertions**: Generated numbers may be `Integer` while flow output is `BigDecimal`. Use `MunitTools::closeTo()` for numeric comparisons or ensure consistent types
- **Test data file size**: Committed JSON fixtures over 1MB slow down builds. Use DataWeave generators for large datasets instead of static files
- **Shared module across projects**: To reuse `test-data.dwl` across multiple Mule apps, publish it as a custom Maven artifact or keep it in a shared test-resources JAR

### Related
- [Batch Job Testing](../batch-job-testing/)
- [Coverage Enforcement in CI/CD](../coverage-enforcement-cicd/)
- [Error Scenario Testing](../error-scenario-testing/)
