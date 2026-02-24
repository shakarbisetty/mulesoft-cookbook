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

### Batch OOM Debugging

When your batch job crashes with `OutOfMemoryError`, use this step-by-step approach:

#### Memory Math Formula

```
Memory per block = blockSize × avgRecordSize × 2 (input + output buffers)
                   × numThreads × DW overhead (1.5-3x)

Example:
  blockSize = 200
  avgRecordSize = 50 KB
  numThreads = 4 (cpu.light pool for standard batch steps)
  DW overhead = 2x (conservative)

  200 × 50KB × 2 × 4 × 2 = 160 MB per batch execution
```

#### Memory Budget by vCore

| vCore | Heap | Safe Batch Budget | Max blockSize (50KB records) |
|-------|------|-------------------|------------------------------|
| 0.1 | 256 MB | ~80 MB | 25 |
| 0.2 | 512 MB | ~200 MB | 60 |
| 0.5 | 1 GB | ~500 MB | 150 |
| 1.0 | 1.5 GB | ~800 MB | 250 |
| 2.0 | 3.5 GB | ~2 GB | 600 |

#### Temp File Accumulation

Batch jobs write temporary files to `${java.io.tmpdir}/mule-batch/`. If a batch job crashes mid-processing, temp files are NOT cleaned up.

```bash
# Check temp file accumulation (on-prem / RTF)
du -sh /tmp/mule-batch/
ls -la /tmp/mule-batch/ | wc -l

# Cleanup stale temp files (only when no batch jobs are running)
find /tmp/mule-batch/ -mtime +1 -delete
```

On CloudHub 2.0, temp files consume container disk. If the container fills up, the pod restarts.

#### Heap Dump Analysis for Batch OOM

```bash
# Enable heap dump on OOM (add to JVM args)
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/tmp/batch-heap.hprof

# What to look for in Eclipse MAT:
# 1. Open Dominator Tree → sort by Retained Heap
# 2. Look for: org.mule.runtime.module.extension.internal.runtime.source.poll
#    → large byte[] arrays = your batch records in memory
# 3. Check: number of retained objects × avg size = total batch memory
# 4. Fix: reduce blockSize until total fits in safe budget above
```

#### Quick Fixes (Fastest to Slowest)

1. **Reduce blockSize** — immediate, no code change needed
2. **Enable streaming** — `repeatableFileStoreStream` for large payloads
3. **Increase vCore** — throws money at the problem but works
4. **Chunk input** — split source query into smaller ranges (e.g., by date)
5. **Simplify transforms** — DW overhead drops from 3x to 1.5x with simpler expressions

### Related
- [Aggregator Commit Sizing](../aggregator-commit-sizing/) — batch aggregator tuning
- [Max Failed Records](../max-failed-records/) — error thresholds
