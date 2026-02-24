## Cache-Aside Pattern for Reference Data
> Check cache first, load from source on miss, store in cache for next time.

### When to Use
- Lookup tables (country codes, currency rates, product catalogs)
- Data that changes infrequently but is read on every request
- You need more control than cache scope provides

### Configuration / Code

```xml
<sub-flow name="get-exchange-rate">
    <try>
        <os:retrieve key="#['rate-' ++ vars.currency]" objectStore="rate-cache"/>
        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <http:request config-ref="Rate_Service" path="/rates/#[vars.currency]"/>
                <os:store key="#['rate-' ++ vars.currency]" objectStore="rate-cache">
                    <os:value>#[payload]</os:value>
                </os:store>
            </on-error-continue>
        </error-handler>
    </try>
</sub-flow>
```

### How It Works
1. Try to retrieve from Object Store cache
2. On `OS:KEY_NOT_FOUND`, call the source service
3. Store the result in cache for next request
4. Next call hits the cache (until TTL expires)

### Gotchas
- This pattern makes the cache miss path slower (source call + store)
- On cold start, every key is a miss — consider cache warming on startup
- Concurrent cache misses for the same key cause duplicate source calls (stampede)

### Related
- [Cache Scope Object Store](../cache-scope-object-store/) — automatic cache scope
- [Cached Fallback](../../../error-handling/recovery/cached-fallback/) — fallback to cache on failure
