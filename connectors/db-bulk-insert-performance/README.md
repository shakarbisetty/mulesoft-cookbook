## Database Bulk Insert Performance

> Batch size tuning, parameterized bulk inserts, and per-record error handling for high-volume database writes in Mule 4.

### When to Use

- Inserting thousands of records per transaction from API payloads, file ingestion, or queue consumption
- Current database writes are slow because they execute one INSERT per record
- Need per-record error tracking without rolling back the entire batch
- Migrating data between systems where throughput matters more than latency

### The Problem

Mule 4's `db:insert` executes a single row at a time by default. Wrapping it in a `foreach` loop for 10,000 records means 10,000 round trips to the database. Using `db:bulk-insert` solves this but introduces new challenges: finding the optimal batch size, handling partial failures, and avoiding memory issues when the input payload is large.

### Configuration

#### Basic Bulk Insert

```xml
<flow name="db-bulk-insert-basic-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/orders/bulk"
        allowedMethods="POST" />

    <ee:transform doc:name="Prepare Bulk Payload">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload.orders map {
    customer_id: $.customerId,
    order_total: $.orderTotal as Number,
    status: $.status default "PENDING",
    created_at: now() as String {format: "yyyy-MM-dd HH:mm:ss"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <db:bulk-insert config-ref="Database_Config" doc:name="Bulk Insert Orders">
        <db:sql><![CDATA[INSERT INTO orders (customer_id, order_total, status, created_at)
VALUES (:customer_id, :order_total, :status, :created_at)]]></db:sql>
    </db:bulk-insert>

    <ee:transform doc:name="Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    inserted: sizeOf(payload),
    status: "success"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Chunked Bulk Insert with Optimal Batch Size

```xml
<flow name="db-bulk-insert-chunked-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/data/import"
        allowedMethods="POST" />

    <set-variable variableName="totalRecords" value="#[sizeOf(payload)]" />
    <set-variable variableName="batchSize" value="${db.bulk.batchSize}" />
    <set-variable variableName="successCount" value="#[0]" />
    <set-variable variableName="errorRecords" value="#[[]]" />

    <!-- Split into chunks -->
    <ee:transform doc:name="Chunk Records">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
var batchSize = vars.batchSize as Number
---
payload divideBy batchSize]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <foreach doc:name="Process Each Chunk" collection="#[payload]">
        <try doc:name="Insert Chunk">
            <ee:transform doc:name="Map to DB Columns">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload map {
    id: $.id,
    name: $.name,
    email: $.email,
    department: $.department,
    created_at: now() as String {format: "yyyy-MM-dd HH:mm:ss"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <db:bulk-insert config-ref="Database_Write_Config"
                doc:name="Insert Chunk">
                <db:sql><![CDATA[INSERT INTO employees (id, name, email, department, created_at)
VALUES (:id, :name, :email, :department, :created_at)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    email = VALUES(email),
    department = VALUES(department)]]></db:sql>
            </db:bulk-insert>

            <set-variable variableName="successCount"
                value="#[vars.successCount + sizeOf(payload)]" />

            <error-handler>
                <on-error-continue type="DB:BAD_SQL_SYNTAX, DB:QUERY_EXECUTION">
                    <logger level="WARN"
                        message="Chunk #[vars.counter] failed: #[error.description]. Falling back to row-by-row." />
                    <!-- Fallback: insert row by row to identify bad records -->
                    <flow-ref name="db-row-by-row-fallback-subflow" />
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>

    <ee:transform doc:name="Build Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    totalSubmitted: vars.totalRecords,
    successfullyInserted: vars.successCount,
    failedRecords: vars.errorRecords,
    failedCount: sizeOf(vars.errorRecords)
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>

<sub-flow name="db-row-by-row-fallback-subflow">
    <foreach doc:name="Insert Row by Row" collection="#[payload]">
        <try doc:name="Single Row Insert">
            <db:insert config-ref="Database_Write_Config"
                doc:name="Insert Single Row">
                <db:sql><![CDATA[INSERT INTO employees (id, name, email, department, created_at)
VALUES (:id, :name, :email, :department, :created_at)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    email = VALUES(email),
    department = VALUES(department)]]></db:sql>
                <db:input-parameters><![CDATA[#[payload]]]></db:input-parameters>
            </db:insert>

            <set-variable variableName="successCount"
                value="#[vars.successCount + 1]" />

            <error-handler>
                <on-error-continue type="ANY">
                    <set-variable variableName="errorRecords"
                        value="#[vars.errorRecords ++ [{
                            record: payload,
                            error: error.description
                        }]]" />
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>
</sub-flow>
```

#### Batch Job for File-Based Bulk Insert

```xml
<flow name="db-bulk-insert-batch-flow">
    <file:listener config-ref="File_Config"
        directory="${file.inbound.dir}"
        autoDelete="true">
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS" />
        </scheduling-strategy>
        <file:matcher filenamePattern="*.csv" />
    </file:listener>

    <batch:job jobName="csv-to-db-batch"
        blockSize="${db.bulk.batchSize}"
        maxFailedRecords="-1">
        <batch:process-records>
            <batch:step name="validate-and-insert"
                acceptPolicy="ALL">
                <ee:transform doc:name="Validate Record">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
{
    id: payload.id as Number,
    name: trim(payload.name),
    email: lower(trim(payload.email)),
    amount: payload.amount as Number {format: "#.##"},
    valid: (payload.email contains "@") and (payload.amount as Number > 0)
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <validation:is-true
                    expression="#[payload.valid]"
                    message="Invalid record: missing email or non-positive amount" />

                <db:insert config-ref="Database_Write_Config"
                    doc:name="Insert Record">
                    <db:sql><![CDATA[INSERT INTO transactions (id, name, email, amount)
VALUES (:id, :name, :email, :amount)]]></db:sql>
                    <db:input-parameters><![CDATA[#[{
    id: payload.id,
    name: payload.name,
    email: payload.email,
    amount: payload.amount
}]]]></db:input-parameters>
                </db:insert>
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <logger level="INFO"
                message="Batch complete. Total: #[payload.totalRecords], Successful: #[payload.successfulRecords], Failed: #[payload.failedRecords]" />
        </batch:on-complete>
    </batch:job>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/java

// Chunk an array into batches of a given size
fun divideBy(arr: Array, size: Number): Array<Array> =
    if (sizeOf(arr) <= size) [arr]
    else [arr[0 to (size - 1)]] ++ divideBy(arr[size to -1], size)

// Sanitize strings for safe DB insertion
fun sanitize(val: String): String =
    trim(val) replace /['\\]/ with ""

// Map API payload to DB row format
fun toDbRow(record: Object): Object = {
    id: record.id,
    name: sanitize(record.name default ""),
    email: lower(trim(record.email default "")),
    amount: record.amount as Number default 0,
    created_at: now() as String {format: "yyyy-MM-dd HH:mm:ss"}
}
---
payload map toDbRow($)
```

### Gotchas

- **Optimal batch size is 500-2000 rows** — Below 500, the overhead of per-statement execution dominates. Above 2000, the database's undo/redo log grows large enough to cause lock contention. Test with your specific schema and data sizes, but 1000 is a reliable starting point for MySQL and PostgreSQL
- **`db:bulk-insert` fails atomically** — If one record in the bulk payload violates a constraint, the entire batch fails (depending on the database driver). The chunked approach with row-by-row fallback isolates bad records without losing the entire batch
- **Parameterized queries prevent SQL injection** — Never concatenate values into SQL strings. Always use `:paramName` bind variables. This also allows the database to cache the execution plan
- **`ON DUPLICATE KEY UPDATE` is MySQL-specific** — For PostgreSQL use `ON CONFLICT ... DO UPDATE`. For Oracle use `MERGE INTO`. For SQL Server use `MERGE ... WHEN MATCHED`
- **Memory with large payloads** — If the API receives 100,000 records in one POST, the entire payload sits in memory. Use streaming with `repeatable-in-memory-stream` or accept the file via multipart upload and process with batch jobs
- **Auto-increment gaps** — Bulk inserts with `ON DUPLICATE KEY UPDATE` on MySQL create auto-increment gaps. This is cosmetic but surprises teams that expect sequential IDs
- **Transaction isolation** — `db:bulk-insert` runs in a single transaction by default. For very large batches (10,000+ rows), this holds locks for too long. Chunking into 1000-row batches with separate transactions reduces lock contention

### Testing

```xml
<munit:test name="db-bulk-insert-chunked-test"
    description="Verify chunked bulk insert processes all records">

    <munit:behavior>
        <munit-tools:mock-when processor="db:bulk-insert">
            <munit-tools:then-return>
                <munit-tools:payload value="#[[1, 1, 1, 1, 1]]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- { "orders": (1 to 10) map { "customerId": $, "orderTotal": $ * 100, "status": "NEW" } }]' />
        <flow-ref name="db-bulk-insert-chunked-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.totalSubmitted]"
            is="#[MunitTools::equalTo(10)]" />
    </munit:validation>
</munit:test>
```

### Related

- [DB Connection Pool Tuning](../db-connection-pool-tuning/) — Pool sizing directly impacts bulk insert throughput
- [Database CDC](../database-cdc/) — Detecting the changes that bulk inserts create
