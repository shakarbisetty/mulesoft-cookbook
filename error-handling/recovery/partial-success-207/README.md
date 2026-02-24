## Partial Success with HTTP 207
> Return HTTP 207 Multi-Status with per-item results so callers know exactly what succeeded and failed.

### When to Use
- Bulk operations where some items succeed and others fail
- Clients need to know which specific items failed and why
- The standard HTTP 200/400/500 status codes are insufficient

### Configuration / Code

```xml
<flow name="bulk-upsert-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/bulk-upsert" method="POST"/>
    <set-variable variableName="results" value="#[[]]"/>

    <foreach collection="#[payload.records]">
        <try>
            <flow-ref name="upsert-single-record"/>
            <set-variable variableName="results"
                          value="#[vars.results ++ [{id: payload.id, status: 200, message: 'Success'}]]"/>
            <error-handler>
                <on-error-continue type="ANY">
                    <set-variable variableName="results"
                                  value="#[vars.results ++ [{id: payload.id, status: 422, message: error.description}]]"/>
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var successes = vars.results filter $.status == 200
var failures = vars.results filter $.status != 200
---
{
    summary: {
        total: sizeOf(vars.results),
        succeeded: sizeOf(successes),
        failed: sizeOf(failures)
    },
    results: vars.results
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <set-variable variableName="httpStatus"
                  value="#[if (sizeOf(vars.results filter $.status != 200) > 0) '207' else '200']"/>
</flow>
```

### How It Works
1. Process each record individually with try/catch
2. Collect per-item results (success or error) in a variable
3. Return HTTP 207 if there are mixed results, 200 if all succeeded
4. Response includes summary counts and per-item status

### Gotchas
- Not all HTTP clients handle 207 — document it in your API spec
- 207 means "look at the body" — callers MUST inspect per-item results
- Consider pagination if the results array is very large
- Use 200 if all succeed, 400 if all fail, 207 only for mixed results

### Related
- [Bulk Per-Record Validation](../../validation/bulk-per-record-validation/) — validate before processing
- [Parallel For-Each Collection](../../async-errors/parallel-foreach-collection/) — parallel variant
