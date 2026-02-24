## Governor Limit Safe Batch Processing
> Design batch integrations that respect Salesforce API call, SOQL, and DML governor limits

### When to Use
- Batch jobs that insert, update, or query thousands of Salesforce records
- Integrations that run within Salesforce transaction boundaries (e.g., Apex callouts from triggers)
- You need to calculate safe batch sizes to avoid `System.LimitException`
- Composite or sub-flow designs that must stay within per-transaction limits

### Configuration / Code

**Key Governor Limits Reference**

| Limit | Synchronous | Asynchronous (Batch) | Notes |
|-------|-------------|---------------------|-------|
| SOQL queries | 100 | 200 | Per transaction |
| SOQL rows returned | 50,000 | 50,000 | Per transaction |
| DML statements | 150 | 150 | Per transaction |
| DML rows | 10,000 | 10,000 | Per transaction |
| Callouts | 100 | 100 | Per transaction |
| Callout timeout | 120s total | 120s total | Single callout max 60s |
| Heap size | 6 MB | 12 MB | Per transaction |
| CPU time | 10,000 ms | 60,000 ms | Per transaction |
| API calls/24hr | Varies by edition | Varies by edition | Enterprise: base 15,000 + per license |

**Batch Job with Safe Block Size**

```xml
<flow name="governor-safe-batch-flow">
    <!-- Fetch records to process -->
    <db:select config-ref="Database_Config">
        <db:sql>
            SELECT id, name, email, account_id, external_id
            FROM contacts_to_sync
            WHERE sync_status = 'PENDING'
            ORDER BY id
        </db:sql>
    </db:select>

    <batch:job jobName="sf-safe-batch"
        maxFailedRecords="100"
        blockSize="200">

        <batch:process-records>
            <batch:step name="validate-and-transform">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    FirstName: (payload.name splitBy " ")[0] default "",
    LastName: (payload.name splitBy " ")[-1] default payload.name,
    Email: payload.email,
    AccountId: payload.account_id,
    External_Id__c: payload.external_id
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </batch:step>

            <batch:step name="upsert-to-salesforce">
                <!-- Batch step processes blockSize records at a time.
                     With blockSize=200, each Salesforce create call
                     handles up to 200 records in a single DML operation,
                     staying well under the 10,000 DML rows limit. -->
                <batch:aggregator size="200">
                    <salesforce:upsert config-ref="Salesforce_Config"
                        objectType="Contact"
                        externalIdFieldName="External_Id__c">
                        <salesforce:records>#[payload]</salesforce:records>
                    </salesforce:upsert>
                </batch:aggregator>
            </batch:step>

            <batch:step name="update-source-status"
                acceptExpression="#[not vars.isFailedRecord]">
                <batch:aggregator size="200">
                    <db:bulk-update config-ref="Database_Config">
                        <db:sql>
                            UPDATE contacts_to_sync
                            SET sync_status = 'SYNCED', synced_at = CURRENT_TIMESTAMP
                            WHERE external_id = :external_id
                        </db:sql>
                    </db:bulk-update>
                </batch:aggregator>
            </batch:step>
        </batch:process-records>

        <batch:on-complete>
            <logger level="INFO"
                message='Batch complete. Total: #[payload.totalRecords], Success: #[payload.successfulRecords], Failed: #[payload.failedRecords]'/>
        </batch:on-complete>
    </batch:job>
</flow>
```

**Composite Request Builder (DataWeave) — Batch DML in One API Call**

```dataweave
%dw 2.0
output application/json

// Salesforce Composite API bundles up to 25 subrequests.
// Each subrequest can create/update up to 200 records (sObject Collections).
// This gives you 25 × 200 = 5,000 records in ONE API call.

var records = vars.recordBatch
var batchesOf200 = records divideBy 200
---
{
    allOrNone: false,
    compositeRequest: batchesOf200 map ((batch, idx) -> {
        method: "POST",
        url: "/services/data/v59.0/composite/sobjects",
        referenceId: "batch_$(idx)",
        body: {
            allOrNone: false,
            records: batch map (r) -> {
                attributes: { "type": "Contact" },
                FirstName: r.firstName,
                LastName: r.lastName,
                Email: r.email,
                External_Id__c: r.externalId
            }
        }
    })
}
```

**SOQL Pagination to Stay Under Row Limits**

```xml
<flow name="paginated-soql-query-flow">
    <set-variable variableName="allRecords" value="#[[]]"/>
    <set-variable variableName="hasMore" value="#[true]"/>
    <set-variable variableName="lastId" value="#['000000000000000']"/>

    <until-successful maxRetries="500" millisBetweenRetries="0">
        <choice>
            <when expression="#[vars.hasMore]">
                <!-- Query 2000 rows at a time (under 50K limit) -->
                <salesforce:query config-ref="Salesforce_Config">
                    <salesforce:salesforce-query>
                        SELECT Id, Name, Email, AccountId
                        FROM Contact
                        WHERE Id > ':lastId'
                        ORDER BY Id ASC
                        LIMIT 2000
                    </salesforce:salesforce-query>
                    <salesforce:parameters>#[{
                        lastId: vars.lastId
                    }]</salesforce:parameters>
                </salesforce:query>

                <set-variable variableName="allRecords"
                    value="#[vars.allRecords ++ payload]"/>
                <set-variable variableName="hasMore"
                    value="#[sizeOf(payload) == 2000]"/>
                <set-variable variableName="lastId"
                    value="#[if (sizeOf(payload) > 0) payload[-1].Id else vars.lastId]"/>

                <choice>
                    <when expression="#[vars.hasMore]">
                        <raise-error type="MULE:RETRY_EXHAUSTED"/>
                    </when>
                </choice>
            </when>
        </choice>
    </until-successful>
</flow>
```

### How It Works
1. The batch job is configured with `blockSize="200"`, meaning Mule processes records in groups of 200
2. Each batch step's aggregator collects records up to the configured size before making a single Salesforce API call
3. With 200 records per DML call, you stay well under the 10,000 DML rows per transaction limit
4. The Composite API approach further reduces API call consumption by bundling multiple operations into one HTTP round-trip
5. SOQL pagination uses the keyset pattern (`WHERE Id > :lastId ORDER BY Id LIMIT 2000`) to avoid OFFSET performance degradation and stay under the 50,000-row query limit
6. Failed records are tracked by the batch framework and excluded from the status-update step via `acceptExpression`
7. The `on-complete` callback provides aggregate metrics for monitoring

### Gotchas
- **Mixed DML errors**: You cannot perform DML on setup objects (e.g., User, Group) and non-setup objects in the same transaction. Separate these into different batch steps or flows
- **Test context limits differ**: Apex test methods have the same governor limits as production, but test data volumes are often smaller, masking issues that surface at scale
- **API call budget**: Each Salesforce connector operation consumes at least one API call. A batch job processing 1 million records in blocks of 200 uses 5,000 API calls. Monitor your 24-hour API usage
- **Block size tuning**: Too small = too many API calls. Too large = risk hitting heap or DML limits. Start with 200 for standard objects, reduce to 50 for objects with complex triggers/validation rules
- **Locking conflicts**: Large batch updates on records with shared parent lookups can cause `UNABLE_TO_LOCK_ROW`. Use serial mode or add retry logic at the step level
- **Bulk API vs Composite**: For very large volumes (100K+), Bulk API 2.0 is more efficient than Composite because it bypasses per-transaction limits entirely. Use Composite for smaller, mixed-operation batches

### Related
- [Bulk API 2.0 Partial Failure](../bulk-api-2-partial-failure/)
- [Composite API Patterns](../composite-api-patterns/)
- [Data Migration Strategies](../data-migration-strategies/)
- [Batch Block Size Optimization](../../performance/batch/block-size-optimization/)
