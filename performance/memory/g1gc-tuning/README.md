## G1GC Tuning for Mule 4
> Configure G1 garbage collector with pause-time targets.

### When to Use
- Mule applications on CloudHub experiencing memory issues
- Tuning JVM for production workloads
- Preventing OutOfMemoryError under load

### Configuration / Code

```
# JVM args for CloudHub (set in Runtime Manager > Settings > JVM Arguments)
# G1GC (default in Java 11+/Mule 4.4+)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=4m
-XX:InitiatingHeapOccupancyPercent=45
-XX:+ParallelRefProcEnabled

# For low-latency APIs (tighter pause target)
-XX:MaxGCPauseMillis=100
-XX:G1NewSizePercent=20
-XX:G1MaxNewSizePercent=40
```

### How It Works
1. G1GC divides the heap into regions and collects garbage incrementally
2. `MaxGCPauseMillis` is the target pause time — G1 adjusts its work to meet this
3. `G1HeapRegionSize` should be between 1 MB and 32 MB (auto-calculated if omitted)
4. `InitiatingHeapOccupancyPercent` triggers concurrent marking when heap is 45% full

### Gotchas
- `MaxGCPauseMillis` is a target, not a guarantee — spikes can exceed it
- Too-small pause targets cause more frequent GC cycles (lower throughput)
- Mule 4.4+ uses G1GC by default; Mule 4.3 and earlier use ParallelGC
- Enable `-XX:+PrintGCDetails -XX:+PrintGCDateStamps` during tuning to see GC behavior

### Related
- [Heap Sizing vCore](../heap-sizing-vcore/) — heap allocation
- [Memory Leak Detection](../memory-leak-detection/) — finding leaks
