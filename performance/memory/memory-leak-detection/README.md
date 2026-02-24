## Memory Leak Detection
> Capture and analyze heap dumps to find leaks.

### When to Use
- Mule applications on CloudHub experiencing memory issues
- Tuning JVM for production workloads
- Preventing OutOfMemoryError under load

### Configuration / Code

```
# JVM args for CloudHub (set in Runtime Manager > Settings > JVM Arguments)
# Enable heap dump on OOM
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/tmp/heapdump.hprof

# For proactive analysis (not production)
-XX:+HeapDumpOnOutOfMemoryError
-XX:OnOutOfMemoryError="kill -9 %p"
```

**Analysis workflow:**
1. Download heap dump from CloudHub Runtime Manager
2. Open in Eclipse MAT or VisualVM
3. Run "Leak Suspects" report
4. Look for growing object counts (compare two dumps taken minutes apart)
5. Check `Dominator Tree` for largest retained objects

### How It Works
1. `-XX:+HeapDumpOnOutOfMemoryError` automatically captures a heap dump when OOM occurs
2. The dump file contains all live objects, their references, and sizes
3. Compare two dumps to find objects that grow over time (leak candidates)

### Gotchas
- Heap dumps can be GBs — ensure `/tmp` has enough space (or use a different path)
- On CloudHub, request heap dump via Support or Runtime Manager diagnostics
- Production heap dumps contain all in-memory data — handle as sensitive
- Frequent full GC without OOM may indicate a slow leak — enable GC logging

### Related
- [Heap Sizing vCore](../heap-sizing-vcore/) — prevent OOM with proper sizing
- [Metaspace Monitoring](../metaspace-monitoring/) — non-heap memory leaks
