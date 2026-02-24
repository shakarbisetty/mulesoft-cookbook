## HTTP Caching Policy at API Gateway
> Apply HTTP caching policy with ETag/Last-Modified at the Flex Gateway layer.

### When to Use
- Reducing backend load for frequently requested resources
- API responses that are cacheable (GET, deterministic data)
- Gateway-level caching without modifying backend code

### Configuration / Code

**API Manager policy configuration:**
```yaml
policyRef:
  name: http-caching
configuration:
  httpCachingKey: "#[attributes.method ++ attributes.requestPath ++ attributes.queryString]"
  maxCacheEntries: 1000
  ttl: 300
  distributed: true
  invalidationHeader: "X-Cache-Invalidate"
  conditionalHeaders: true
```

### How It Works
1. Gateway caches GET responses keyed by method + path + query string
2. Subsequent identical requests return the cached response (no backend call)
3. `conditionalHeaders` enables ETag/Last-Modified validation
4. TTL of 300 seconds means cached entries expire after 5 minutes

### Gotchas
- Only cache GET and HEAD requests — never cache POST/PUT/DELETE
- Authenticated endpoints need per-user cache keys (add auth token hash)
- `distributed: true` shares cache across gateway replicas (requires shared storage)
- Monitor cache hit ratio to verify effectiveness

### Related
- [Cache Scope Object Store](../cache-scope-object-store/) — application-level caching
- [Response Cache (AI Gateway)](../../../api-management/ai-gateway/response-cache/) — LLM response caching
