## Batch Job Concurrency
> Control maxConcurrency on batch steps to prevent overwhelming downstream systems.

### When to Use
- Batch steps calling rate-limited APIs
- Downstream systems with connection limits
- Preventing resource exhaustion during batch processing

### Configuration / Code

```xml
<batch:job jobName="api-sync-batch" blockSize="100">
    <batch:process-records>
        <batch:step name="call-api" maxConcurrency="4">
            <http:request config-ref="External_API" path="/sync" method="POST">
                <http:body>#[write(payload, "application/json")]</http:body>
            </http:request>
        </batch:step>
    </batch:process-records>
</batch:job>
```

### How It Works
1. `maxConcurrency` limits how many records in the block are processed in parallel
2. Default is the number of CPU cores; setting it lower protects backends
3. Each record in the block is independent — they can run on different threads

### Gotchas
- `maxConcurrency` is per batch step, not per job
- Setting it to 1 makes the step sequential — useful for ordering guarantees
- The batch job also has its own thread allocation — check schedulers-pools.conf

### Related
- [Block Size Optimization](../block-size-optimization/) — block-level tuning
- [Max Concurrency Flow](../../threading/max-concurrency-flow/) — flow-level concurrency
