## Batch Block Size Optimization
> Tune blockSize to balance memory consumption vs processing throughput.

### When to Use
- Batch jobs processing large datasets where memory or speed needs tuning
- Default blockSize (100) is not optimal for your payload sizes

### Configuration / Code

```xml
<batch:job jobName="order-import" blockSize="200">
    <batch:process-records>
        <batch:step name="transform">
            <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
                <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json --- payload]]></ee:set-payload></ee:message>
            </ee:transform>
        </batch:step>
    </batch:process-records>
</batch:job>
```

**Sizing guide:**
| Record Size | Recommended blockSize | Memory per Block |
|-------------|----------------------|------------------|
| < 1 KB | 500–1000 | < 1 MB |
| 1–10 KB | 100–200 | 1–2 MB |
| 10–100 KB | 20–50 | 2–5 MB |
| > 100 KB | 10–20 | 1–2 MB |

### How It Works
1. Mule loads `blockSize` records into memory at a time
2. Each block is processed through all batch steps before the next block loads
3. Larger blocks = fewer disk I/O operations but more memory per block

### Gotchas
- Too-large blockSize causes OOM; too-small causes excessive disk I/O
- blockSize applies to the input phase — the aggregator has its own `size` parameter
- Monitor `heap.used` during batch runs to find the sweet spot

### Related
- [Aggregator Commit Sizing](../aggregator-commit-sizing/) — batch aggregator tuning
- [Max Failed Records](../max-failed-records/) — error thresholds
