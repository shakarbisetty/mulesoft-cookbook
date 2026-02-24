## Cache Scope with Object Store V2
> Configure cache scope backed by persistent Object Store V2 for cross-restart durability.

### When to Use
- Caching expensive lookups (reference data, config, exchange rates)
- Data that changes infrequently but is read often
- Persistent cache that survives app restarts on CloudHub

### Configuration / Code

```xml
<os:object-store name="cache-os" persistent="true" entryTtl="3600" entryTtlUnit="SECONDS"/>

<flow name="cached-lookup-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/products/{id}"/>
    <ee:cache cachingStrategy-ref="cache-os" keyExpression="#[attributes.uriParams.id]">
        <http:request config-ref="Product_Service" path="/products/#[attributes.uriParams.id]"/>
    </ee:cache>
</flow>
```

### How It Works
1. `ee:cache` checks if a cached response exists for the key
2. On cache hit, returns the cached payload without calling the backend
3. On cache miss, executes the inner block and caches the result
4. `entryTtl` controls how long entries live before expiration

### Gotchas
- Cache scope stores the entire payload — large payloads consume OS storage quota
- Object Store V2 has a 10 MB per-key limit on CloudHub
- `keyExpression` must produce unique, deterministic keys
- Cache scope does NOT cache errors — failed requests are not cached

### Related
- [Distributed Cache](../distributed-cache/) — share cache across workers
- [Cache Invalidation](../cache-invalidation/) — TTL + event-driven purge
- [Cache Aside Reference](../cache-aside-reference/) — manual check-then-load
