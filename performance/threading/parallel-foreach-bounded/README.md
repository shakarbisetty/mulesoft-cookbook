## Parallel For-Each with Bounded Concurrency
> Process collections in parallel with controlled thread count to avoid OOM.

### When to Use
- Processing arrays where each item is independent
- You want parallelism but not unlimited thread usage
- Downstream APIs have connection limits

### Configuration / Code

```xml
<parallel-for-each collection="#[payload.items]" maxConcurrency="4" timeout="30000">
    <http:request config-ref="Backend_API" path="/process" method="POST">
        <http:body>#[write(payload, "application/json")]</http:body>
    </http:request>
</parallel-for-each>
```

### How It Works
1. `maxConcurrency="4"` processes 4 items at a time in parallel
2. Remaining items queue until a slot opens
3. `timeout` is the max time to wait for ALL items to complete
4. Results are collected in order (matching input array index)

### Gotchas
- Each parallel item gets a copy of the event — memory multiplied by maxConcurrency
- `timeout` is total, not per-item — 4 items × 30s each could exceed a 30s timeout
- Variables set inside parallel-for-each are NOT visible outside (scoped per item)
- Errors in any item cause MULE:COMPOSITE_ROUTING (unless caught with try)

### Related
- [Scatter-Gather Composite](../../../error-handling/async-errors/scatter-gather-composite/) — parallel routes
- [Async Back-Pressure](../async-back-pressure/) — async alternatives
