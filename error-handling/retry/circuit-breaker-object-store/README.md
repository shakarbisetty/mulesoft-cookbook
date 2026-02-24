## Circuit Breaker with Object Store
> Track failure counts in Object Store; trip the circuit after N failures, reject fast during cooldown, then probe.

### When to Use
- A downstream service is completely down and retrying wastes resources
- You want fail-fast behavior to protect your app and the failing service
- Three states: CLOSED (normal), OPEN (reject fast), HALF_OPEN (probe)

### Configuration / Code

```xml
<os:object-store name="circuit-breaker-store"
                 persistent="true" entryTtl="60" entryTtlUnit="SECONDS"
                 expirationInterval="10" expirationIntervalUnit="SECONDS"/>

<flow name="circuit-breaker-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>

    <!-- Check circuit state -->
    <try>
        <os:retrieve key="circuit-state" objectStore="circuit-breaker-store" target="circuitState"/>
        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <set-variable variableName="circuitState" value="CLOSED"/>
            </on-error-continue>
        </error-handler>
    </try>

    <!-- If OPEN, reject immediately -->
    <choice>
        <when expression="#[vars.circuitState == 'OPEN']">
            <set-variable variableName="httpStatus" value="503"/>
            <set-payload value='{"error":"Circuit open — service unavailable"}' mimeType="application/json"/>
        </when>
        <otherwise>
            <!-- Attempt the call -->
            <try>
                <http:request config-ref="Order_Service" path="/orders" method="GET"/>
                <!-- Success: reset failure count -->
                <os:store key="failure-count" objectStore="circuit-breaker-store">
                    <os:value>0</os:value>
                </os:store>
                <os:store key="circuit-state" objectStore="circuit-breaker-store">
                    <os:value>CLOSED</os:value>
                </os:store>
                <error-handler>
                    <on-error-propagate type="HTTP:CONNECTIVITY, HTTP:TIMEOUT">
                        <!-- Increment failure count -->
                        <try>
                            <os:retrieve key="failure-count" objectStore="circuit-breaker-store" target="failCount"/>
                            <error-handler>
                                <on-error-continue type="OS:KEY_NOT_FOUND">
                                    <set-variable variableName="failCount" value="0"/>
                                </on-error-continue>
                            </error-handler>
                        </try>
                        <set-variable variableName="failCount" value="#[(vars.failCount as Number) + 1]"/>
                        <os:store key="failure-count" objectStore="circuit-breaker-store">
                            <os:value>#[vars.failCount]</os:value>
                        </os:store>
                        <!-- Trip circuit if threshold exceeded -->
                        <choice>
                            <when expression="#[vars.failCount >= 5]">
                                <os:store key="circuit-state" objectStore="circuit-breaker-store">
                                    <os:value>OPEN</os:value>
                                </os:store>
                                <logger level="WARN" message="Circuit OPEN after #[vars.failCount] failures"/>
                            </when>
                        </choice>
                        <set-variable variableName="httpStatus" value="503"/>
                        <set-payload value='{"error":"Service temporarily unavailable"}' mimeType="application/json"/>
                    </on-error-propagate>
                </error-handler>
            </try>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. **CLOSED**: Requests pass through normally. Failures increment a counter in Object Store.
2. **OPEN**: After 5 failures, circuit trips. Requests immediately return 503 (no backend call).
3. The `entryTtl` (60s) on Object Store acts as the cooldown timer — after 60s, the state expires and the circuit resets to CLOSED (half-open probe).
4. On successful probe, failure count resets to 0.

### Gotchas
- Object Store V2 on CloudHub is eventually consistent — two workers may trip at slightly different times
- `entryTtl` controls cooldown duration; too short = hammering a down service, too long = slow recovery
- This pattern blocks the calling thread during the OS operations — keep the flow `maxConcurrency` reasonable
- For high-throughput scenarios, consider a custom Java component with AtomicInteger for thread-safe counting

### Related
- [Exponential Backoff](../exponential-backoff-jitter/) — retry before tripping
- [Cached Fallback](../../recovery/cached-fallback/) — serve stale data when circuit is open
- [Bulkhead Isolation](../../recovery/bulkhead-isolation/) — isolate failing services
