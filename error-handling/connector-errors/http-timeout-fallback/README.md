## HTTP Timeout with Fallback
> Catch HTTP:TIMEOUT and return cached data or a degraded response instead of failing.

### When to Use
- A slow downstream service should not block your entire API
- Cached/stale data is acceptable as a fallback
- You want graceful degradation over hard failure

### Configuration / Code

```xml
<flow name="product-catalog-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/products"/>
    <try>
        <http:request config-ref="Catalog_Service" path="/products" method="GET"
                      responseTimeout="3000"/>
        <!-- Cache successful response -->
        <os:store key="products-cache" objectStore="cache-store">
            <os:value>#[payload]</os:value>
        </os:store>
        <error-handler>
            <on-error-continue type="HTTP:TIMEOUT">
                <logger level="WARN" message="Catalog service timed out, using cached data"/>
                <try>
                    <os:retrieve key="products-cache" objectStore="cache-store" target="cachedProducts"/>
                    <set-payload value="#[vars.cachedProducts]"/>
                    <error-handler>
                        <on-error-continue type="OS:KEY_NOT_FOUND">
                            <set-variable variableName="httpStatus" value="503"/>
                            <set-payload value='{"error":"Service unavailable","message":"No cached data available"}' mimeType="application/json"/>
                        </on-error-continue>
                    </error-handler>
                </try>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Set a tight `responseTimeout` on the HTTP request (3 seconds)
2. On success, cache the response in Object Store
3. On `HTTP:TIMEOUT`, try to retrieve the cached version
4. If no cache exists, return 503

### Gotchas
- Cached data can be stale — include a `Cache-Control` or `X-Data-Age` header
- `responseTimeout` is per-request; set at the config level for default, override per request
- `HTTP:CONNECTIVITY` is different from `HTTP:TIMEOUT` — handle both if needed

### Related
- [Cached Fallback](../../recovery/cached-fallback/) — broader fallback pattern
- [Circuit Breaker](../../retry/circuit-breaker-object-store/) — prevent calling a timed-out service
