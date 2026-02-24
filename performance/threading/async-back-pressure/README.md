## Async with Back-Pressure
> Offload non-critical work to async scope with maxConcurrency to prevent thread starvation.

### When to Use
- Fire-and-forget operations (notifications, logging, analytics)
- You want to limit how many async operations run simultaneously
- Preventing async work from consuming all available threads

### Configuration / Code

```xml
<flow name="api-with-async">
    <http:listener config-ref="HTTP_Listener" path="/api/events" method="POST"/>
    <flow-ref name="process-event"/>
    <async maxConcurrency="5">
        <http:request config-ref="Analytics_Service" path="/track" method="POST">
            <http:body>#[write(payload, "application/json")]</http:body>
        </http:request>
    </async>
    <set-payload value=accepted mimeType="application/json"/>
</flow>
```

### How It Works
1. `async` runs its contents on a separate thread, not blocking the main flow
2. `maxConcurrency="5"` limits to 5 concurrent async operations
3. When the limit is reached, new async operations wait for a slot
4. The main flow responds immediately without waiting for async completion

### Gotchas
- Without maxConcurrency, async has no limit — can exhaust the I/O thread pool
- Errors in async are silently dropped (use try inside async to catch them)
- Variables are copied (snapshot), not shared — changes inside async are invisible outside
- On CloudHub, async plus maxConcurrency is the simplest way to do bounded background work

### Related
- [Async Scope Errors](../../../error-handling/async-errors/async-scope-errors/) — error handling in async
- [Max Concurrency Flow](../max-concurrency-flow/) — flow-level concurrency
