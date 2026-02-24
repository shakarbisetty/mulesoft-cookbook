## Batch Job Testing
> Test batch jobs with mocked data sources, validate step processing counts, and assert on-complete behavior.

### When to Use
- You have batch jobs processing large datasets from databases, files, or queues
- You need to verify record-level processing logic without connecting to real data sources
- You want to assert that on-complete aggregates (successful, failed, skipped counts) are correct
- You need regression tests for batch steps that apply business rules per record

### Configuration / Code

**MUnit test — mock batch source and validate step counts:**

```xml
<munit:test name="batch-order-processing-test"
            description="Verify batch processes all records and counts match">

    <!-- Mock the database source that feeds the batch -->
    <munit:behavior>
        <munit-tools:mock-when processor="db:select">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Fetch Pending Orders"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value="#[output application/java --- readUrl('classpath://test-data/batch-orders.json', 'application/json')]"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Mock the HTTP call in the process step -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Call Fulfillment API"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {"status": "fulfilled"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Mock the update step so no real DB writes occur -->
        <munit-tools:mock-when processor="db:update">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Update Order Status"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#[1]"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="batch-order-processing-flow"/>
    </munit:execution>

    <munit:validation>
        <!-- Assert the batch job result payload -->
        <munit-tools:assert-that
            expression="#[payload.processedRecords]"
            is="#[MunitTools::equalTo(50)]"/>
        <munit-tools:assert-that
            expression="#[payload.successfulRecords]"
            is="#[MunitTools::equalTo(48)]"/>
        <munit-tools:assert-that
            expression="#[payload.failedRecords]"
            is="#[MunitTools::equalTo(2)]"/>
    </munit:validation>
</munit:test>
```

**DataWeave test data factory — `src/test/resources/test-data/batch-orders.json`:**

```json
[
  {"orderId": "ORD-001", "customerId": "C-100", "amount": 250.00, "status": "PENDING"},
  {"orderId": "ORD-002", "customerId": "C-101", "amount": 75.50, "status": "PENDING"},
  {"orderId": "ORD-003", "customerId": "C-102", "amount": 0.00, "status": "PENDING"},
  {"orderId": "ORD-004", "customerId": "C-103", "amount": 1200.00, "status": "PENDING"}
]
```

**DataWeave factory for generating larger batch datasets — `src/test/resources/dwl/batch-data-factory.dwl`:**

```dataweave
%dw 2.0
output application/json

fun generateOrders(count: Number) =
    (1 to count) map {
        orderId: "ORD-" ++ ($ as String {format: "000"}),
        customerId: "C-" ++ (100 + $) as String,
        amount: randomInt(10000) / 100,
        status: "PENDING",
        createdAt: now() - |P$(randomInt(30))D|
    }
---
generateOrders(50)
```

**Batch flow under test — key structure:**

```xml
<batch:job name="batch-order-processing-job" maxFailedRecords="5">
    <batch:process-records>
        <batch:step name="validate-step">
            <validation:is-true
                expression="#[payload.amount > 0]"
                message="Order amount must be positive"/>
        </batch:step>
        <batch:step name="fulfill-step" acceptExpression="#[vars.previousStepSuccess]">
            <http:request config-ref="Fulfillment_Config"
                          method="POST" path="/fulfill"
                          doc:name="Call Fulfillment API">
                <http:body>#[output application/json --- payload]</http:body>
            </http:request>
        </batch:step>
        <batch:step name="update-step">
            <db:update config-ref="Database_Config" doc:name="Update Order Status">
                <db:sql>UPDATE orders SET status = 'FULFILLED' WHERE order_id = :orderId</db:sql>
                <db:input-parameters>#[{orderId: payload.orderId}]</db:input-parameters>
            </db:update>
        </batch:step>
    </batch:process-records>
    <batch:on-complete>
        <logger level="INFO"
                message="Batch complete: #[payload.processedRecords] processed, #[payload.failedRecords] failed"/>
    </batch:on-complete>
</batch:job>
```

### How It Works
1. The MUnit test mocks the database `SELECT` that feeds records into the batch job, returning a fixed JSON dataset from test resources
2. Each batch step's external calls (HTTP, DB) are mocked with `mock-when` to isolate the test from real services
3. The `flow-ref` triggers the batch job flow, which runs through all steps using mocked data
4. After batch completion, the `on-complete` payload contains processing statistics
5. Assertions verify the expected counts: total processed, successful, and failed records
6. The DataWeave factory generates deterministic test datasets of any size

### Gotchas
- **Batch threading in MUnit**: Batch jobs run in separate threads. MUnit may need an increased timeout (`<munit:test ... timeout="60000">`) to wait for completion
- **Async completion timing**: The batch `on-complete` block runs asynchronously. Use `munit-tools:sleep` or increase test timeout if assertions fire before batch finishes
- **maxFailedRecords in tests**: If your batch sets `maxFailedRecords="0"`, a single mocked failure stops the entire job. Set a realistic threshold in test configurations
- **Batch block size**: Default block size is 100. If your test data is smaller than the block size, all records process in one thread, which may mask concurrency bugs
- **Payload after batch**: The payload available after `flow-ref` to a batch job is the on-complete summary, not the individual record payloads

### Related
- [Coverage Enforcement in CI/CD](../coverage-enforcement-cicd/)
- [Mock Data Generation](../mock-data-generation/)
- [Error Scenario Testing](../error-scenario-testing/)
- [Batch Block Size Optimization](../../../performance/batch/block-size-optimization/) (if available)
