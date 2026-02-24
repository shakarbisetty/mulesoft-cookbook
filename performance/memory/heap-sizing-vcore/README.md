## Heap Sizing per vCore
> Map JVM heap settings to CloudHub worker sizes.

### When to Use
- Mule applications on CloudHub experiencing memory issues
- Tuning JVM for production workloads
- Preventing OutOfMemoryError under load

### Configuration / Code

```
# JVM args for CloudHub (set in Runtime Manager > Settings > JVM Arguments)
# 0.1 vCore (256 MB heap — default)
-Xms256m -Xmx256m

# 0.5 vCore (512 MB heap)
-Xms512m -Xmx512m

# 1.0 vCore (1 GB heap)
-Xms1g -Xmx1g

# 4.0 vCore (4 GB heap)
-Xms4g -Xmx4g
```

| vCore | Default Heap | Recommended Heap | Notes |
|-------|-------------|-----------------|-------|
| 0.1 | 256 MB | 256 MB | Cannot increase — fixed |
| 0.5 | 512 MB | 512 MB | Set -Xms = -Xmx |
| 1.0 | ~768 MB | 1 GB | Increase for heavy transforms |
| 2.0 | ~1.5 GB | 2 GB | Good for batch processing |
| 4.0 | ~3 GB | 4 GB | Maximum available |

### How It Works
1. `-Xms` sets initial heap; `-Xmx` sets maximum heap
2. Setting both equal avoids heap expansion overhead
3. CloudHub allocates total RAM per vCore; heap is a portion of that

### Gotchas
- Never set `-Xmx` higher than 80% of total worker RAM — leave room for OS, metaspace, native memory
- CloudHub 2.0 uses container limits — exceeding causes OOMKill (different from Java OOM)
- Non-heap memory (metaspace, thread stacks, NIO buffers) is NOT counted in `-Xmx`

### Related
- [G1GC Tuning](../g1gc-tuning/) — garbage collector optimization
- [vCore Sizing Matrix](../../cloudhub/vcore-sizing-matrix/) — choosing the right vCore
- [Threshold Per vCore](../../streaming/threshold-per-vcore/) — streaming buffer sizing
