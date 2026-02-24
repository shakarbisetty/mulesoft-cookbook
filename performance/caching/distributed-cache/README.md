## Distributed Cache Across Workers
> Enable distributed mode so all CloudHub workers share the same cache entries.

### When to Use
- Multi-worker deployments where cache consistency matters
- Avoiding redundant backend calls from different workers
- Reference data that should be identical across all instances

### Configuration / Code

```xml
<os:object-store name="distributed-cache-os"
                 persistent="true"
                 entryTtl="1800"
                 entryTtlUnit="SECONDS"/>

<ee:cache cachingStrategy-ref="distributed-cache-os"
          keyExpression="#[attributes.requestPath]">
    <http:request config-ref="Backend_Service" path="#[attributes.requestPath]"/>
</ee:cache>
```

### How It Works
1. Object Store V2 on CloudHub is automatically distributed across all workers
2. When Worker A caches a response, Worker B can serve it from the shared store
3. `persistent="true"` ensures the cache survives worker restarts

### Gotchas
- Object Store V2 is eventually consistent — brief window where workers may see different values
- Network latency to the OS V2 service adds ~5-10ms per cache read (vs. in-memory microseconds)
- On-premises: Object Store is NOT distributed by default — use Hazelcast or Redis

### Related
- [Cache Scope Object Store](../cache-scope-object-store/) — single-worker caching
- [Cache Invalidation](../cache-invalidation/) — TTL and event-driven purge
