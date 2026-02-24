## Parallel For-Each Error Collection
> Process items in parallel, collect per-item errors without stopping the batch, return a summary.

### When to Use
- Processing a list of records where individual failures should not stop the batch
- You want a summary of which items succeeded and which failed
- Parallel processing is needed for performance

### Configuration / Code

```xml
<flow name="bulk-update-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/bulk-update" method="POST"/>
    <set-variable variableName="errors" value="#[[]]"/>
    <set-variable variableName="successes" value="#[[]]"/>

    <parallel-for-each collection="#[payload.records]" maxConcurrency="4" timeout="30000">
        <try>
            <http:request config-ref="Backend_API" path="/update" method="PUT">
                <http:body>#[write(payload, "application/json")]</http:body>
            </http:request>
            <error-handler>
                <on-error-continue type="ANY">
                    <set-variable variableName="errors"
                                  value="#[vars.errors ++ [{index: vars.counter, id: payload.id, error: error.description}]]"/>
                </on-error-continue>
            </error-handler>
        </try>
    </parallel-for-each>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    processed: sizeOf(payload),
    succeeded: sizeOf(payload) - sizeOf(vars.errors),
    failed: sizeOf(vars.errors),
    errors: vars.errors
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. `parallel-for-each` processes items concurrently up to `maxConcurrency`
2. Each item is wrapped in `try` with `on-error-continue` to swallow individual failures
3. Failures are appended to an `errors` variable
4. After all items complete, a summary is returned

### Gotchas
- Variables in parallel-for-each are not thread-safe — the error list may have race conditions; use the result collection instead for precise tracking
- `maxConcurrency` controls parallel threads; set it to match backend capacity
- `timeout` is per-item, not total

### Related
- [Scatter-Gather Composite](../scatter-gather-composite/) — parallel routes with error aggregation
- [Batch Step Errors](../batch-step-errors/) — batch processing error handling
- [Bulk Per-Record Validation](../../validation/bulk-per-record-validation/) — validation per record
