## Async Scope Error Handling
> Errors inside async scope do not propagate to the caller — use try scope inside async to catch them.

### When to Use
- You use async scope for fire-and-forget operations
- You need to capture errors from async processing without breaking the main flow
- Logging or notification of async failures is required

### Configuration / Code

```xml
<flow name="order-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>

    <!-- Main processing -->
    <flow-ref name="create-order"/>

    <!-- Fire-and-forget notification (errors here must NOT affect the response) -->
    <async>
        <try>
            <http:request config-ref="Notification_Service" path="/notify" method="POST"/>
            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="ERROR" message="Async notification failed: #[error.description]"/>
                </on-error-continue>
            </error-handler>
        </try>
    </async>

    <set-payload value='{"status":"created"}' mimeType="application/json"/>
</flow>
```

### How It Works
1. The `async` scope runs its contents on a separate thread
2. The main flow continues immediately without waiting
3. If the async operation fails, the error is silently dropped (not propagated)
4. Wrapping in `try` with `on-error-continue` lets you log or alert on failures

### Gotchas
- Without a try scope, async errors vanish silently — you will not know they happened
- Variables set in the main flow are copied into async (snapshot), not shared
- Async scope has its own `maxConcurrency` — uncontrolled async can exhaust threads

### Related
- [Fire and Forget Capture](../fire-and-forget-capture/) — VM-based async with error handling
- [Async Back-Pressure](../../../performance/threading/async-back-pressure/) — controlling async concurrency
