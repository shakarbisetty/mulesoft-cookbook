## API-Led Performance Patterns
> Eliminating unnecessary hops, direct-to-system patterns, and async experience layers

### When to Use
- Your API-led integration exceeds latency SLAs because of too many internal hops
- Monitoring shows that process or experience APIs are pure pass-throughs with no logic
- You need sub-100ms response times but your 3-tier stack adds 60-90ms of overhead
- Backend systems are fast but your API chain is the bottleneck

### The Problem

The standard 3-tier API-led model (Experience -> Process -> System) adds network latency at each hop. In production, each HTTP call between CloudHub workers adds 10-25ms for serialization, network transit, and deserialization. A 3-tier chain adds 40-75ms before backend processing even starts.

For high-frequency, low-latency integrations — real-time pricing, inventory checks, authentication flows — this overhead is unacceptable. Teams need patterns that preserve API-led governance without paying the latency tax.

### Configuration / Code

#### Latency Anatomy of a 3-Tier Chain

```
Consumer Request
    │ 10-25ms   ┌─────────────────────┐
    ├──────────►│  Experience API      │
    │           │  - Deserialize       │  5ms
    │           │  - Auth check        │  2ms
    │           │  - Transform request │  3ms
    │           └─────────┬───────────┘
    │ 10-25ms             │
    │           ┌─────────▼───────────┐
    │           │  Process API         │
    │           │  - Deserialize       │  5ms
    │           │  - Business logic    │  10ms
    │           │  - Transform         │  3ms
    │           └─────────┬───────────┘
    │ 10-25ms             │
    │           ┌─────────▼───────────┐
    │           │  System API          │
    │           │  - Deserialize       │  5ms
    │           │  - Protocol xlate    │  5ms
    │           │  - Backend call      │  50ms
    │           └─────────────────────┘

    Total overhead (excl. backend): 63-123ms
    Backend processing:              50ms
    End-to-end:                     113-173ms
```

#### Pattern 1: Direct-to-System

Skip intermediate tiers when there is no logic to execute. Apply governance via API Manager policies.

```
BEFORE:
  Consumer ──► Experience API ──► Process API ──► System API ──► Backend
  Latency: 120-170ms

AFTER:
  Consumer ──► System API (with API Manager policies) ──► Backend
  Latency: 60-80ms

  API Manager provides:
  ├── Client-ID enforcement (replaces experience auth)
  ├── Rate limiting / SLA tiers (replaces experience throttling)
  ├── Response transformation policy (replaces experience mapping)
  └── IP allowlist (replaces experience filtering)
```

```xml
<!-- System API with policies applied via API Manager (no code changes needed) -->
<flow name="sys-inventory-lookup">
    <http:listener config-ref="HTTPS_Listener" path="/api/inventory/{sku}" />

    <!-- Direct backend call — no intermediate hops -->
    <db:select config-ref="InventoryDB">
        <db:sql>SELECT sku, qty_available, warehouse_code
               FROM inventory WHERE sku = :sku</db:sql>
        <db:input-parameters>#[{ sku: attributes.uriParams.sku }]</db:input-parameters>
    </db:select>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    sku: payload[0].sku,
    available: payload[0].qty_available,
    warehouse: payload[0].warehouse_code,
    checkedAt: now() as String { format: "yyyy-MM-dd'T'HH:mm:ss'Z'" }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Pattern 2: Async Experience Layer

Decouple the experience layer from the synchronous chain. Consumer gets an immediate acknowledgment; processing happens asynchronously.

```
SYNC PATH (fast — consumer gets immediate response):
  Consumer ──► Experience API ──► Anypoint MQ (publish)
  Latency: 30-50ms (just publish to queue)

ASYNC PATH (background — no consumer waiting):
  Anypoint MQ ──► Process API ──► System API ──► Backend
  Processing time: 200ms-2s (doesn't matter, consumer isn't waiting)
```

```xml
<!-- Experience API: publish and acknowledge -->
<flow name="exp-order-submit">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders" method="POST"
                   allowedMethods="POST" />

    <!-- Validate request shape -->
    <apikit:router config-ref="order-api-config" />
</flow>

<flow name="post:\orders:order-api-config">
    <!-- Generate correlation ID -->
    <set-variable variableName="correlationId"
                  value="#[uuid()]" />

    <!-- Publish to Anypoint MQ — non-blocking -->
    <anypoint-mq:publish config-ref="Anypoint_MQ"
                         destination="order-processing-queue">
        <anypoint-mq:body>#[%dw 2.0
output application/json
---
{
    correlationId: vars.correlationId,
    order: payload,
    submittedAt: now()
}]</anypoint-mq:body>
        <anypoint-mq:properties>
            <anypoint-mq:property key="correlationId"
                                  value="#[vars.correlationId]" />
        </anypoint-mq:properties>
    </anypoint-mq:publish>

    <!-- Return immediately -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "accepted",
    correlationId: vars.correlationId,
    statusUrl: "/api/orders/status/" ++ vars.correlationId
}]]></ee:set-payload>
        </ee:message>
        <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 202 }]]></ee:set-attributes>
    </ee:transform>
</flow>
```

#### Pattern 3: Parallel System Calls

When the process layer calls multiple system APIs, parallelize instead of sequential calls.

```
BEFORE (sequential — 300ms):
  Process API ──► System API A (100ms)
              ──► System API B (100ms)  ← waits for A
              ──► System API C (100ms)  ← waits for B

AFTER (parallel — 120ms):
  Process API ──┬──► System API A (100ms) ──┐
                ├──► System API B (100ms) ──┼──► Merge results
                └──► System API C (100ms) ──┘
```

```xml
<flow name="prc-customer-360">
    <http:listener config-ref="HTTPS_Listener" path="/api/customer/{id}/360" />

    <scatter-gather>
        <route>
            <http:request config-ref="sys-salesforce"
                         path="/customers/#[attributes.uriParams.id]"
                         method="GET" />
            <set-variable variableName="sfData" value="#[payload]" />
        </route>
        <route>
            <http:request config-ref="sys-orders-db"
                         path="/orders?customerId=#[attributes.uriParams.id]"
                         method="GET" />
            <set-variable variableName="orderData" value="#[payload]" />
        </route>
        <route>
            <http:request config-ref="sys-support-tickets"
                         path="/tickets?customerId=#[attributes.uriParams.id]"
                         method="GET" />
            <set-variable variableName="ticketData" value="#[payload]" />
        </route>
    </scatter-gather>

    <!-- Merge parallel results -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    profile: payload."0".payload,
    recentOrders: payload."1".payload,
    openTickets: payload."2".payload
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Pattern 4: Cached System Layer

Use Object Store as a cache to avoid repeated backend calls for slowly-changing data.

```xml
<flow name="sys-product-catalog">
    <http:listener config-ref="HTTPS_Listener" path="/api/products/{id}" />

    <!-- Check cache first -->
    <try>
        <os:retrieve key="#['product-' ++ attributes.uriParams.id]"
                     objectStore="Product_Cache" />
        <set-variable variableName="cacheHit" value="#[true]" />
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <set-variable variableName="cacheHit" value="#[false]" />
        </on-error-continue>
    </error-handler>
    </try>

    <choice>
        <when expression="#[vars.cacheHit != true]">
            <!-- Cache miss — call backend -->
            <http:request config-ref="SAP_Config" path="/products/#[attributes.uriParams.id]"
                         method="GET" />

            <!-- Store in cache with 5-minute TTL -->
            <os:store key="#['product-' ++ attributes.uriParams.id]"
                      objectStore="Product_Cache">
                <os:value>#[payload]</os:value>
            </os:store>
        </when>
    </choice>
</flow>

<!-- Object Store with TTL -->
<os:object-store name="Product_Cache"
                 persistent="false"
                 entryTtl="300"
                 entryTtlUnit="SECONDS"
                 maxEntries="10000" />
```

#### Performance Impact Summary

| Pattern | Latency Reduction | Trade-off |
|---------|-------------------|-----------|
| Direct-to-System | 40-80ms saved | Less separation of concerns |
| Async Experience | 70-120ms saved (consumer) | Consumer must poll or use webhooks |
| Parallel System Calls | 40-60% faster | Error handling more complex |
| Cached System Layer | 80-95% faster (cache hit) | Stale data risk, cache invalidation |
| Response Streaming | 50-70% TTFB improvement | Client must handle streaming |

### How It Works

1. **Profile your current latency** — use Runtime Manager > Monitoring to measure each hop
2. **Identify pass-through layers** — any layer that adds < 5ms of processing is a candidate for removal
3. **Apply the appropriate pattern** — direct-to-system for simple lookups, async for write-heavy, parallel for multi-source reads
4. **Monitor after changes** — verify latency improvement and watch for error rate changes

### Gotchas

- **Removing layers does not remove governance.** Always apply API Manager policies to maintain client-id enforcement, rate limiting, and analytics on every exposed endpoint.
- **Scatter-gather default timeout is 30 seconds.** Set explicit timeouts on each route to fail fast. One slow backend should not block all routes.
- **Object Store cache in CloudHub is per-worker.** If you have 2 workers, each has its own cache. Use `persistent="true"` for shared cache, but accept higher latency (~5ms vs ~1ms).
- **Async patterns require idempotency.** Anypoint MQ delivers at-least-once. Your process API must handle duplicate messages gracefully.
- **Scatter-gather returns a Map, not an Array.** Access results by string index: `payload."0".payload`, not `payload[0]`.

### Related

- [API-Led Layer Decision Framework](../api-led-layer-decision-framework/) — decide how many layers you need
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — common mistakes with the 3-tier model
- [Sync-Async Decision Flowchart](../sync-async-decision-flowchart/) — when to go async
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — protect against slow backends
