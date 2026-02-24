## Cache Invalidation
> Combine TTL-based expiry with explicit event-driven cache purge.

### When to Use
- Cached data changes unpredictably (product updates, config changes)
- TTL alone is not granular enough
- You need immediate cache refresh on data change events

### Configuration / Code

```xml
<!-- TTL-based expiry (30 min) -->
<os:object-store name="product-cache" persistent="true" entryTtl="1800" entryTtlUnit="SECONDS"/>

<!-- Explicit invalidation endpoint -->
<flow name="cache-invalidation-flow">
    <http:listener config-ref="Admin_Listener" path="/admin/cache/invalidate" method="POST"/>
    <ee:invalidate-cache cachingStrategy-ref="product-cache"
                         keyExpression="#[payload.productId]"/>
    <set-payload value=Cache invalidated mimeType="application/json"/>
</flow>

<!-- Event-driven invalidation via MQ -->
<flow name="product-update-listener">
    <anypoint-mq:subscriber config-ref="MQ_Config" destination="product-updates"/>
    <ee:invalidate-cache cachingStrategy-ref="product-cache"
                         keyExpression="#[payload.productId]"/>
</flow>
```

### How It Works
1. TTL provides baseline expiry — stale data is eventually replaced
2. Admin endpoint allows manual invalidation for specific keys
3. MQ listener invalidates cache automatically when products are updated
4. `ee:invalidate-cache` removes the specific key from the cache

### Gotchas
- Invalidating all keys at once requires iterating — there is no "clear all" operation
- In distributed mode, invalidation propagates eventually (not instantly)
- Race condition: if a read happens between data update and invalidation, stale data is served

### Related
- [Cache Scope Object Store](../cache-scope-object-store/) — caching setup
- [Distributed Cache](../distributed-cache/) — multi-worker cache
