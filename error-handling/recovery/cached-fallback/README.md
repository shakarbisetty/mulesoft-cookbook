## Cached Fallback
> Return the last known good response from Object Store cache when a downstream service fails.

### When to Use
- Stale data is better than no data
- Reference data (catalogs, configs) that changes infrequently
- High-availability requirement where downstream outages must not cascade

### Configuration / Code

```xml
<os:object-store name="response-cache" persistent="true" entryTtl="3600" entryTtlUnit="SECONDS"/>

<flow name="product-api-with-fallback">
    <http:listener config-ref="HTTP_Listener" path="/api/products"/>
    <try>
        <http:request config-ref="Product_Service" path="/products" method="GET"
                      responseTimeout="5000"/>
        <os:store key="products-latest" objectStore="response-cache">
            <os:value>#[payload]</os:value>
        </os:store>
        <error-handler>
            <on-error-continue type="HTTP:TIMEOUT, HTTP:CONNECTIVITY, HTTP:INTERNAL_SERVER_ERROR">
                <logger level="WARN" message="Product service unavailable, serving cached data"/>
                <try>
                    <os:retrieve key="products-latest" objectStore="response-cache"/>
                    <error-handler>
                        <on-error-continue type="OS:KEY_NOT_FOUND">
                            <set-variable variableName="httpStatus" value="503"/>
                            <set-payload value='{"error":"No cached data available"}' mimeType="application/json"/>
                        </on-error-continue>
                    </error-handler>
                </try>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. On successful response, cache it in Object Store
2. On failure, retrieve the cached version
3. If no cache exists, return 503
4. TTL (1 hour) prevents serving extremely stale data

### Gotchas
- Always set a TTL — serving day-old data may be worse than returning an error
- Add `X-Data-Source: cache` header to let clients know they got cached data
- Object Store V2 on CloudHub has a 10 MB per-key limit

### Related
- [HTTP Timeout Fallback](../../connector-errors/http-timeout-fallback/) — timeout-specific fallback
- [Circuit Breaker](../../retry/circuit-breaker-object-store/) — prevent calling failing service
- [Cache Scope](../../performance/caching/cache-scope-object-store/) — proactive caching
