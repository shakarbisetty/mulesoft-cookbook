## On-Error-Continue vs On-Error-Propagate
> Decision matrix for when to swallow errors vs propagate them up the call chain.

### When to Use
- You need to decide how each error type should be handled in your flow
- Some errors should be logged and swallowed (non-critical), others must bubble up
- You want to return a response to the client even when sub-flows fail

### Configuration / Code

**on-error-continue — swallows the error, flow execution continues:**

```xml
<flow name="order-processing-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>

    <try>
        <!-- Non-critical: notification failure should not break the order -->
        <http:request config-ref="Notification_Service" path="/notify" method="POST"/>
        <error-handler>
            <on-error-continue type="HTTP:CONNECTIVITY, HTTP:TIMEOUT">
                <logger level="WARN"
                        message="Notification failed, continuing: #[error.description]"/>
            </on-error-continue>
        </error-handler>
    </try>

    <!-- This still executes even if notification failed -->
    <set-payload value='{"status": "order created"}'/>
</flow>
```

**on-error-propagate — re-throws the error, stops flow execution:**

```xml
<flow name="payment-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/payments"/>

    <try>
        <!-- Critical: payment failure must stop everything -->
        <http:request config-ref="Payment_Gateway" path="/charge" method="POST"/>
        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                        message="Payment failed: #[error.description]"/>
                <set-variable variableName="httpStatus" value="502"/>
                <set-payload value='{"error": "Payment processing failed"}'/>
            </on-error-propagate>
        </error-handler>
    </try>

    <!-- This does NOT execute if payment failed -->
    <set-payload value='{"status": "payment confirmed"}'/>
</flow>
```

### Decision Matrix

| Scenario | Use | Why |
|----------|-----|-----|
| Non-critical side effect (notifications, logging) | `on-error-continue` | Main flow should complete |
| Critical dependency (payment, auth) | `on-error-propagate` | Cannot continue without it |
| Validation errors in try scope | `on-error-continue` | Return validation details to client |
| Database write failure | `on-error-propagate` | Data integrity requires stopping |
| Enrichment from optional service | `on-error-continue` | Return partial data over no data |

### How It Works
1. `on-error-continue`: catches the error, executes its body, then resumes the flow after the try scope as if no error occurred. The event payload is whatever the handler sets.
2. `on-error-propagate`: catches the error, executes its body, then re-throws so the parent error handler (or caller) handles it. Flow execution stops.

### Gotchas
- `on-error-continue` inside a `try` scope resumes after the `try`, not after the failed component
- If you use `on-error-continue` at the flow level (not inside try), the HTTP listener returns 200 by default — set `httpStatus` explicitly
- `on-error-propagate` at the flow level triggers the global error handler if one is configured
- Both can coexist in the same error-handler block — Mule evaluates them top-to-bottom

### Related
- [Default Error Handler](../default-error-handler/) — global catch-all pattern
- [Layered Error Handling](../layered-error-handling/) — combining try + flow + global
- [Selective Rollback](../../transactions/selective-rollback/) — continue vs propagate within transactions
