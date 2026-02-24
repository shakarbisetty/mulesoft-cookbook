## Streaming Threshold Per vCore
> Calculate optimal buffer sizes based on CloudHub worker memory (0.1 to 4 vCore).

### When to Use
- Deploying to CloudHub with different worker sizes across environments
- You want a formula-based approach to buffer sizing
- Avoiding OOM by right-sizing buffers to available heap

### Configuration / Code

**CloudHub vCore Memory Map:**

| vCore | Total RAM | Heap (-Xmx) | Safe Buffer Budget (20%) |
|-------|-----------|-------------|--------------------------|
| 0.1 | 500 MB | 256 MB | 50 MB |
| 0.5 | 1 GB | 512 MB | 100 MB |
| 1.0 | 1.5 GB | 1 GB | 200 MB |
| 2.0 | 3.5 GB | 2 GB | 400 MB |
| 4.0 | 7.5 GB | 4 GB | 800 MB |

**Formula:**
```
maxInMemorySize = (heap * 0.20) / maxConcurrency
```

**Example for 1 vCore, maxConcurrency=10:**
```
maxInMemorySize = (1024 MB * 0.20) / 10 = ~20 MB per request
```

```xml
<!-- 1 vCore config -->
<flow name="api-flow" maxConcurrency="10">
    <http:listener config-ref="HTTP_Listener" path="/api/data">
        <repeatable-file-store-stream
            inMemorySize="2"
            maxInMemorySize="20"
            bufferUnit="MB"/>
    </http:listener>
</flow>
```

### How It Works
1. Reserve 20% of heap for streaming buffers (remaining 80% for app logic + GC)
2. Divide the budget by maxConcurrency to get per-request allocation
3. Set `inMemorySize` to 10% of `maxInMemorySize` for the initial allocation
4. Anything beyond `maxInMemorySize` spills to file store

### Gotchas
- The 20% rule is conservative; tune based on your app's actual heap usage
- `maxConcurrency` is a cap, not the average — size for peak concurrent requests
- CloudHub 2.0 vCore sizes differ slightly from CH1 — verify in the docs
- Monitor `heap.used` in Anypoint Monitoring to validate your calculations

### Related
- [Repeatable File Store](../repeatable-file-store/) — file store configuration
- [Heap Sizing vCore](../../memory/heap-sizing-vcore/) — JVM heap tuning
- [vCore Sizing Matrix](../../cloudhub/vcore-sizing-matrix/) — choosing worker size
