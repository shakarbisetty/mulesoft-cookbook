## Metaspace Monitoring
> Monitor and limit metaspace for class loading.

### When to Use
- Mule applications on CloudHub experiencing memory issues
- Tuning JVM for production workloads
- Preventing OutOfMemoryError under load

### Configuration / Code

```
# JVM args for CloudHub (set in Runtime Manager > Settings > JVM Arguments)
# Set metaspace limits
-XX:MetaspaceSize=128m
-XX:MaxMetaspaceSize=256m

# Monitor metaspace (JMX)
# Check java.lang:type=MemoryPool,name="Metaspace"
```

### How It Works
1. Metaspace stores class metadata (loaded classes, method data)
2. `-XX:MetaspaceSize` triggers GC when metaspace reaches this threshold
3. `-XX:MaxMetaspaceSize` is the hard limit — triggers OOM if exceeded
4. Unbounded metaspace growth usually indicates class loader leaks

### Gotchas
- Default `MaxMetaspaceSize` is unlimited — set it explicitly to prevent runaway growth
- Hot-deploying apps repeatedly can leak class loaders (common in Studio, not CloudHub)
- Mule connectors with dynamic class generation may increase metaspace usage
- Monitor in Anypoint Monitoring under JVM metrics

### Related
- [Heap Sizing vCore](../heap-sizing-vcore/) — heap tuning
- [Memory Leak Detection](../memory-leak-detection/) — diagnosing leaks
