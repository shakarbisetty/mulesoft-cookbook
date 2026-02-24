## Batch Step Error Handling
> Configure maxFailedRecords and acceptExpression on batch steps; use on-complete for reporting.

### When to Use
- Batch jobs processing thousands of records where some failures are acceptable
- You need to report success/failure counts at the end
- Failed records should be logged but not stop the batch

### Configuration / Code

```xml
<batch:job jobName="order-import-batch" maxFailedRecords="100">
    <batch:process-records>
        <batch:step name="validate-step">
            <flow-ref name="validate-record"/>
        </batch:step>

        <batch:step name="transform-step" acceptExpression="#[vars.isValid == true]">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.id,
    amount: payload.total as Number,
    customer: payload.customerName
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </batch:step>

        <batch:step name="upsert-step" acceptPolicy="ONLY_FAILURES"
                    acceptExpression="#[vars.canRetry == true]">
            <logger level="WARN" message="Retrying failed record: #[payload.id]"/>
            <flow-ref name="retry-upsert"/>
        </batch:step>
    </batch:process-records>

    <batch:on-complete>
        <logger level="INFO" message="Batch complete: #[payload.processedRecords] processed, #[payload.successfulRecords] succeeded, #[payload.failedRecords] failed"/>
        <choice>
            <when expression="#[payload.failedRecords > 0]">
                <flow-ref name="send-failure-report"/>
            </when>
        </choice>
    </batch:on-complete>
</batch:job>
```

### How It Works
1. `maxFailedRecords="100"` — batch continues until 100 records fail, then aborts
2. `acceptExpression` filters which records enter each step
3. `acceptPolicy="ONLY_FAILURES"` routes only failed records (retry step)
4. `on-complete` runs after all records, providing counts

### Gotchas
- `maxFailedRecords="-1"` means unlimited failures (never abort)
- `maxFailedRecords="0"` aborts on the first failure
- `on-complete` always runs, even if the batch aborted — use `payload.loadedRecords` to check
- Batch variables are per-record, not shared across records

### Related
- [Parallel For-Each Collection](../parallel-foreach-collection/) — non-batch parallel processing
- [Max Failed Records](../../performance/batch/max-failed-records/) — performance implications
