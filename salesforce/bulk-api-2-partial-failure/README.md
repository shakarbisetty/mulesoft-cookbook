## Bulk API 2.0 Partial Failure Recovery
> Handle partial failures in Salesforce Bulk API 2.0 jobs with failed-record capture and targeted retry

### When to Use
- Loading more than 200 records into Salesforce (the threshold where Bulk API outperforms REST)
- You need to process millions of records without hitting API call governor limits
- Partial failures are expected (validation rules, duplicate rules, required fields) and you need to recover gracefully
- You want to avoid re-processing records that already succeeded

### Configuration / Code

**Bulk Create with Batch Size Configuration**

```xml
<flow name="bulk-api-2-ingest-flow">
    <scheduler>
        <scheduling-strategy>
            <cron expression="0 0 2 * * ?"/>  <!-- 2 AM daily -->
        </scheduling-strategy>
    </scheduler>

    <!-- Fetch source records -->
    <db:select config-ref="Database_Config">
        <db:sql>
            SELECT id, name, email, phone, external_id
            FROM pending_sf_sync
            WHERE sync_status = 'READY'
            ORDER BY id
            LIMIT 10000000
        </db:sql>
    </db:select>

    <set-variable variableName="totalRecords" value="#[sizeOf(payload)]"/>
    <logger level="INFO"
        message='Starting Bulk API 2.0 job: #[vars.totalRecords] records'/>

    <!-- Transform to Salesforce format -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (record) -> {
    Name: record.name,
    Email__c: record.email,
    Phone: record.phone,
    External_Id__c: record.external_id
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Salesforce Bulk API 2.0 Create -->
    <salesforce:create-job-and-upload-data config-ref="Salesforce_Config"
        objectType="Contact"
        operation="INSERT">
        <salesforce:create-job-request
            columnDelimiter="COMMA"
            contentType="CSV"
            lineEnding="LF"/>
    </salesforce:create-job-and-upload-data>

    <set-variable variableName="jobId" value="#[payload.id]"/>

    <!-- Poll for job completion -->
    <flow-ref name="poll-bulk-job-status"/>

    <!-- Process results -->
    <flow-ref name="handle-bulk-results"/>
</flow>
```

**Poll Bulk Job Status**

```xml
<flow name="poll-bulk-job-status">
    <set-variable variableName="jobComplete" value="#[false]"/>
    <set-variable variableName="pollCount" value="#[0]"/>

    <until-successful maxRetries="60" millisBetweenRetries="10000">
        <salesforce:get-job-info config-ref="Salesforce_Config"
            jobId="#[vars.jobId]"/>

        <choice>
            <when expression="#[payload.state == 'JobComplete']">
                <set-variable variableName="jobComplete" value="#[true]"/>
            </when>
            <when expression="#[payload.state == 'Failed']">
                <raise-error type="APP:BULK_JOB_FAILED"
                    description="#['Bulk job failed: ' ++ (payload.errorMessage default 'Unknown')]"/>
            </when>
            <when expression="#[payload.state == 'Aborted']">
                <raise-error type="APP:BULK_JOB_ABORTED"
                    description="Bulk job was aborted"/>
            </when>
            <otherwise>
                <logger level="DEBUG"
                    message='Job #[vars.jobId] state: #[payload.state], records processed: #[payload.numberRecordsProcessed]'/>
                <raise-error type="MULE:RETRY_EXHAUSTED"
                    description="Still in progress"/>
            </otherwise>
        </choice>
    </until-successful>
</flow>
```

**Handle Results and Extract Failed Records**

```xml
<flow name="handle-bulk-results">
    <!-- Get successful results -->
    <salesforce:get-job-successful-results config-ref="Salesforce_Config"
        jobId="#[vars.jobId]"/>
    <set-variable variableName="successCount"
        value="#[sizeOf(payload)]"/>

    <!-- Get failed results -->
    <salesforce:get-job-failed-results config-ref="Salesforce_Config"
        jobId="#[vars.jobId]"/>
    <set-variable variableName="failedRecords" value="#[payload]"/>
    <set-variable variableName="failedCount"
        value="#[sizeOf(vars.failedRecords)]"/>

    <logger level="INFO"
        message='Bulk job #[vars.jobId] complete. Success: #[vars.successCount], Failed: #[vars.failedCount]'/>

    <!-- Process failures if any -->
    <choice>
        <when expression="#[vars.failedCount > 0]">
            <flow-ref name="retry-failed-records"/>
        </when>
    </choice>
</flow>
```

**Parse Bulk API Failed Results (DataWeave)**

```dataweave
%dw 2.0
output application/json

// Bulk API 2.0 returns failed results as CSV with sf__Error and sf__Id columns
var failedResults = payload

---
failedResults map (record) -> {
    sfId: record.sf__Id,
    error: record.sf__Error,
    errorCategory: if (record.sf__Error contains "DUPLICATE")
            "DUPLICATE_VALUE"
        else if (record.sf__Error contains "REQUIRED_FIELD_MISSING")
            "VALIDATION"
        else if (record.sf__Error contains "FIELD_CUSTOM_VALIDATION_EXCEPTION")
            "VALIDATION"
        else if (record.sf__Error contains "STORAGE_LIMIT_EXCEEDED")
            "LIMIT"
        else
            "OTHER",
    retryable: !(
        (record.sf__Error contains "DUPLICATE") or
        (record.sf__Error contains "STORAGE_LIMIT_EXCEEDED")
    ),
    originalData: record - "sf__Id" - "sf__Error"
}
```

**Retry Failed Records Individually**

```xml
<flow name="retry-failed-records">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
vars.failedRecords
    filter (r) -> !(r.sf__Error contains "DUPLICATE")
    map (r) -> r - "sf__Id" - "sf__Error"
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="retryableCount" value="#[sizeOf(payload)]"/>

    <choice>
        <when expression="#[vars.retryableCount > 0]">
            <foreach batchSize="1">
                <try>
                    <salesforce:create config-ref="Salesforce_Config"
                        type="Contact">
                        <salesforce:records>#[[payload]]</salesforce:records>
                    </salesforce:create>
                    <logger level="DEBUG" message="Retry succeeded for record"/>
                </try>
                <error-handler>
                    <on-error-continue>
                        <!-- Log permanently failed record -->
                        <db:insert config-ref="Database_Config">
                            <db:sql>
                                INSERT INTO sf_sync_dead_letter
                                (record_data, error_message, job_id, created_at)
                                VALUES (:data, :error, :jobId, CURRENT_TIMESTAMP)
                            </db:sql>
                            <db:input-parameters>#[{
                                data: write(payload, "application/json"),
                                error: error.description,
                                jobId: vars.jobId
                            }]</db:input-parameters>
                        </db:insert>
                    </on-error-continue>
                </error-handler>
            </foreach>
        </when>
    </choice>

    <logger level="INFO"
        message='Retry complete. #[vars.retryableCount] records attempted individually.'/>
</flow>
```

### How It Works
1. A scheduler triggers the bulk load flow at the configured time (off-peak recommended)
2. Source records are fetched from the database and transformed to the Salesforce object schema
3. The Salesforce connector submits a Bulk API 2.0 job, uploading records as CSV
4. The flow polls the job status every 10 seconds (up to 10 minutes) until it completes or fails
5. On completion, successful and failed result sets are retrieved separately
6. Failed records are categorized by error type using DataWeave
7. Retryable failures (not duplicates or limit errors) are retried one at a time via the standard REST API
8. Permanently failed records are written to a dead-letter table for investigation

### Gotchas
- **10-minute job timeout**: Bulk API 2.0 jobs time out after 10 minutes of inactivity (not total processing time). If Salesforce is under load, jobs may fail silently. Set polling intervals short enough to detect this
- **150 MB file size limit**: A single Bulk API 2.0 upload cannot exceed 150 MB. For larger datasets, split into multiple jobs
- **Polling interval**: Too frequent polling wastes API calls. Too infrequent means you miss failures. 10-second intervals work for most use cases
- **CSV column ordering**: Bulk API 2.0 CSV columns must match the object field API names exactly. DataWeave `output application/csv` handles this but verify field names match your org
- **Serial vs parallel mode**: Parallel mode (default) is faster but can cause lock contention on related records. Use serial mode when updating records that share parent lookups
- **Record order not preserved**: Bulk API does not guarantee processing order. If insertion order matters (parent before child), use separate jobs with dependencies

### Related
- [Governor Limit Safe Batch](../governor-limit-safe-batch/)
- [Data Migration Strategies](../data-migration-strategies/)
- [Composite API Patterns](../composite-api-patterns/)
- [Dead Letter Queues](../../error-handling/dead-letter-queues/)
