## Salesforce Bulk API v2 Optimization

> Memory-safe bulk queries and upserts with streaming, chunking large datasets, and monitoring job completion for Mule 4.

### When to Use

- Extracting or loading more than 10,000 records to/from Salesforce in a single operation
- Current Salesforce integration hits heap memory limits on CloudHub when processing large result sets
- Need to migrate data between Salesforce orgs or between Salesforce and an external database
- SOQL queries against large objects (e.g., Task, Event, CaseComment) that exceed REST API query limits

### The Problem

The Salesforce REST API returns results in pages of 2,000 records, requiring multiple round trips and holding the entire dataset in memory. For datasets over 50,000 records, this causes `OutOfMemoryError` on CloudHub workers. Bulk API v2 handles the heavy lifting server-side, returning results as a CSV stream that Mule can process without loading everything into memory.

### Configuration

#### Bulk Query with Streaming

```xml
<salesforce:config name="Salesforce_Config" doc:name="Salesforce Config">
    <salesforce:oauth-user-pass-connection
        consumerKey="${sf.consumerKey}"
        consumerSecret="${sf.consumerSecret}"
        username="${sf.username}"
        password="${sf.password}"
        securityToken="${sf.securityToken}" />
</salesforce:config>

<flow name="sf-bulk-query-streaming-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sf/bulk-export"
        allowedMethods="POST" />

    <!-- Create bulk query job -->
    <salesforce:query config-ref="Salesforce_Config"
        doc:name="Bulk Query">
        <salesforce:salesforce-query><![CDATA[SELECT Id, Name, Industry, AnnualRevenue,
    BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
    Phone, Website, NumberOfEmployees, OwnerId, CreatedDate, LastModifiedDate
FROM Account
WHERE LastModifiedDate >= :lastSync]]></salesforce:salesforce-query>
        <salesforce:parameters><![CDATA[#[{
    lastSync: payload.lastSyncDate default "2024-01-01T00:00:00Z"
}]]]></salesforce:parameters>
    </salesforce:query>

    <!-- Stream results through batch processing -->
    <batch:job jobName="sf-bulk-export-batch"
        blockSize="500"
        maxFailedRecords="100">
        <batch:process-records>
            <batch:step name="transform-and-load">
                <ee:transform doc:name="Map to Target Format">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    sfId: payload.Id,
    name: payload.Name,
    industry: payload.Industry,
    revenue: payload.AnnualRevenue as Number default 0,
    address: {
        street: payload.BillingStreet,
        city: payload.BillingCity,
        state: payload.BillingState,
        zip: payload.BillingPostalCode,
        country: payload.BillingCountry
    },
    phone: payload.Phone,
    website: payload.Website,
    employees: payload.NumberOfEmployees as Number default 0,
    lastModified: payload.LastModifiedDate
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <db:insert config-ref="Database_Config"
                    doc:name="Upsert to DB">
                    <db:sql><![CDATA[INSERT INTO accounts (sf_id, name, industry, revenue, city, state, country, last_modified)
VALUES (:sfId, :name, :industry, :revenue, :city, :state, :country, :lastModified)
ON DUPLICATE KEY UPDATE
    name = VALUES(name), industry = VALUES(industry),
    revenue = VALUES(revenue), last_modified = VALUES(last_modified)]]></db:sql>
                    <db:input-parameters><![CDATA[#[{
    sfId: payload.sfId,
    name: payload.name,
    industry: payload.industry,
    revenue: payload.revenue,
    city: payload.address.city,
    state: payload.address.state,
    country: payload.address.country,
    lastModified: payload.lastModified
}]]]></db:input-parameters>
                </db:insert>
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <logger level="INFO"
                message="Bulk export complete. Total: #[payload.totalRecords], Success: #[payload.successfulRecords], Failed: #[payload.failedRecords]" />
        </batch:on-complete>
    </batch:job>
</flow>
```

#### Bulk Upsert with Chunking

```xml
<flow name="sf-bulk-upsert-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sf/bulk-import"
        allowedMethods="POST" />

    <set-variable variableName="totalRecords" value="#[sizeOf(payload)]" />

    <!-- Chunk into 10,000-record batches (Bulk API v2 limit per job) -->
    <ee:transform doc:name="Chunk Payload">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload divideBy 10000]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="jobResults" value="#[[]]" />

    <foreach doc:name="Process Each Chunk">
        <ee:transform doc:name="Map to Salesforce Fields">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload map {
    Name: $.name,
    Industry: $.industry,
    AnnualRevenue: $.revenue,
    BillingCity: $.address.city,
    BillingState: $.address.state,
    BillingCountry: $.address.country,
    Phone: $.phone,
    External_Id__c: $.externalId
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <salesforce:upsert-bulk config-ref="Salesforce_Config"
            doc:name="Bulk Upsert"
            objectType="Account"
            externalIdFieldName="External_Id__c" />

        <set-variable variableName="jobResults"
            value="#[vars.jobResults ++ [{
                chunk: vars.counter,
                jobId: payload.id default 'unknown',
                state: payload.state default 'unknown'
            }]]" />
    </foreach>

    <ee:transform doc:name="Summary Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    totalRecords: vars.totalRecords,
    chunks: sizeOf(vars.jobResults),
    jobs: vars.jobResults,
    status: "submitted"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Incremental Sync with Watermark

```xml
<flow name="sf-bulk-incremental-sync-flow">
    <scheduler doc:name="Daily Sync">
        <scheduling-strategy>
            <cron expression="0 0 2 * * ?" timeZone="UTC" />
        </scheduling-strategy>
    </scheduler>

    <os:retrieve key="sf_account_last_sync"
        objectStore="Watermark_Store"
        doc:name="Get Last Sync">
        <os:default-value><![CDATA[2024-01-01T00:00:00Z]]></os:default-value>
    </os:retrieve>

    <set-variable variableName="lastSync" value="#[payload]" />
    <set-variable variableName="syncStartTime"
        value="#[now() as String {format: \"yyyy-MM-dd'T'HH:mm:ss'Z'\"}]" />

    <salesforce:query config-ref="Salesforce_Config"
        doc:name="Incremental Query">
        <salesforce:salesforce-query><![CDATA[SELECT Id, Name, Industry, AnnualRevenue,
    LastModifiedDate
FROM Account
WHERE LastModifiedDate > :lastSync
ORDER BY LastModifiedDate ASC]]></salesforce:salesforce-query>
        <salesforce:parameters><![CDATA[#[{
    lastSync: vars.lastSync
}]]]></salesforce:parameters>
    </salesforce:query>

    <batch:job jobName="sf-incremental-sync"
        blockSize="200"
        maxFailedRecords="50">
        <batch:process-records>
            <batch:step name="sync-to-target">
                <http:request config-ref="Target_API"
                    method="PUT"
                    path="#['/api/accounts/' ++ payload.Id]">
                    <http:body><![CDATA[#[output application/json --- payload]]]></http:body>
                </http:request>
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <choice doc:name="Update Watermark on Success">
                <when expression="#[payload.failedRecords == 0]">
                    <os:store key="sf_account_last_sync"
                        objectStore="Watermark_Store">
                        <os:value><![CDATA[#[vars.syncStartTime]]]></os:value>
                    </os:store>
                </when>
                <otherwise>
                    <logger level="WARN"
                        message="Sync had #[payload.failedRecords] failures. Watermark NOT advanced." />
                </otherwise>
            </choice>
        </batch:on-complete>
    </batch:job>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Build SOQL WHERE clause for incremental sync
fun buildIncrementalFilter(lastSync: String, objectName: String): String =
    "SELECT Id, Name, LastModifiedDate FROM $(objectName) " ++
    "WHERE LastModifiedDate > $(lastSync) ORDER BY LastModifiedDate ASC"

// Estimate number of Bulk API jobs needed
fun estimateJobs(recordCount: Number, maxPerJob: Number = 10000): Number =
    ceil(recordCount / maxPerJob)

// Calculate optimal batch block size based on record complexity
fun optimalBlockSize(fieldsPerRecord: Number): Number =
    if (fieldsPerRecord <= 10) 500
    else if (fieldsPerRecord <= 30) 200
    else 100
---
{
    example: {
        query: buildIncrementalFilter("2025-01-01T00:00:00Z", "Account"),
        jobEstimate: estimateJobs(150000),
        blockSize: optimalBlockSize(25)
    }
}
```

### Gotchas

- **Bulk API v2 has a 150 MB file size limit per job** — If your 10,000 records exceed 150 MB of CSV, you need smaller chunks. Wide objects with many text fields hit this limit faster than you expect
- **Bulk API v2 daily limits** — Salesforce limits the number of bulk API batches per 24-hour rolling window. Enterprise Edition allows 15,000 batches/day. Check your org's limits in Setup > Company Information
- **Query results are CSV** — Bulk API v2 returns CSV, not JSON. The Salesforce connector handles this transparently, but if you use raw HTTP requests, you must parse CSV yourself
- **`NULL` values in Bulk API** — To set a field to null in a bulk upsert, you must include the field with value `#N/A` in the CSV. Omitting the field leaves the existing value unchanged. This is different from REST API behavior
- **Polymorphic lookup fields** — Bulk API v2 does not support polymorphic SOQL (e.g., `TYPEOF`). If you need to query fields like `WhoId` on Task that can reference Contact or Lead, use separate queries per object type
- **External ID field must be indexed** — The field used as `externalIdFieldName` in upsert must be marked as External ID in Salesforce, which automatically creates an index. Without this, upserts timeout on large datasets
- **No real-time status on CloudHub** — Bulk API jobs are asynchronous. The Salesforce connector waits for completion by default, but on CloudHub with short HTTP timeouts, long-running jobs may appear to fail. Use async processing with a callback pattern instead

### Testing

```xml
<munit:test name="sf-bulk-chunking-test"
    description="Verify large datasets are chunked correctly">

    <munit:behavior>
        <munit-tools:mock-when processor="salesforce:upsert-bulk">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{id: 'job-123', state: 'JobComplete'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/java --- (1 to 25000) map { name: "Account " ++ $, externalId: "EXT-" ++ $, industry: "Tech" }]' />
        <flow-ref name="sf-bulk-upsert-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.chunks]"
            is="#[MunitTools::equalTo(3)]" />
    </munit:validation>
</munit:test>
```

### Related

- [SF CDC Idempotent Processing](../sf-cdc-idempotent-processing/) — Real-time change capture as complement to bulk sync
- [SF Governor Limit Patterns](../sf-governor-limit-patterns/) — Avoiding API limit exhaustion during bulk operations
