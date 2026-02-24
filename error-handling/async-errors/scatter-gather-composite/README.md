## Scatter-Gather Composite Error
> Catch MULE:COMPOSITE_ROUTING errors from scatter-gather and extract per-route successes and failures.

### When to Use
- Parallel calls where some routes may fail while others succeed
- You want partial results rather than all-or-nothing
- Reporting which backends succeeded and which failed

### Configuration / Code

```xml
<flow name="parallel-enrichment-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/customer-360"/>

    <try>
        <scatter-gather>
            <route>
                <http:request config-ref="CRM_Service" path="/customer" method="GET"/>
            </route>
            <route>
                <http:request config-ref="Billing_Service" path="/billing" method="GET"/>
            </route>
            <route>
                <http:request config-ref="Support_Service" path="/tickets" method="GET"/>
            </route>
        </scatter-gather>
        <error-handler>
            <on-error-continue type="MULE:COMPOSITE_ROUTING">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
var results = error.childErrors
---
{
    successes: results filter ($.error == null) map $.message.payload,
    failures: results filter ($.error != null) map {
        route: $$.index,
        error: $.error.errorType.identifier,
        message: $.error.description
    },
    partial: true
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. `scatter-gather` runs all routes in parallel
2. If ANY route fails, Mule throws `MULE:COMPOSITE_ROUTING`
3. `error.childErrors` contains results for ALL routes (successes and failures)
4. Filter to separate successful results from failed ones
5. Return a partial response with both

### Gotchas
- `error.childErrors` is only available for `MULE:COMPOSITE_ROUTING` — not other error types
- If ALL routes succeed, no error is thrown — handle the success case normally
- The `$.message.payload` of successful routes may be a stream — ensure repeatable streaming

### Related
- [Parallel For-Each Collection](../parallel-foreach-collection/) — similar pattern for collections
- [Partial Success 207](../../recovery/partial-success-207/) — returning HTTP 207
