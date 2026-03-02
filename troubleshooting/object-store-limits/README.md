## Object Store Limits
> CloudHub Object Store v2 limits, TTL configuration, and partition strategy for production use

### When to Use
- Getting "Object Store is full" or "Maximum entries exceeded" errors
- Need to understand Object Store v2 limits before designing a caching strategy
- Object Store operations are slow or timing out
- Planning data partitioning across multiple Object Stores
- Migrating from Object Store v1 to v2

### The Problem

CloudHub Object Store v2 has hard limits on entry count, value size, key size, and operations per second that are not prominently documented. Developers design caching or state management solutions that hit these limits in production, causing failures that are difficult to diagnose because the error messages are generic.

### Object Store v2 Limits

```
+-------------------------------+--------------------------------------------+
| Limit                         | Value                                      |
+-------------------------------+--------------------------------------------+
| Max entries per partition     | 100,000                                    |
| Max value size                | 10 MB per entry                            |
| Max key size                  | 256 characters                             |
| Max partitions per app        | No hard limit, but impacts performance     |
| Max key-value pair size       | 10 MB (key + value combined)               |
| TTL range                     | 1 second to 2,592,000 seconds (30 days)    |
| Default TTL                   | 2,592,000 seconds (30 days)                |
| Max operations per second     | ~100 ops/sec per app (approximate)         |
| Data persistence              | Survives restarts, NOT cross-region        |
| Consistency                   | Eventually consistent (reads after write   |
|                               | may have ~100ms delay)                     |
+-------------------------------+--------------------------------------------+
```

### Configuration

#### Basic Object Store

```xml
<os:object-store name="orderCache"
    persistent="true"
    maxEntries="10000"
    entryTtl="30"
    entryTtlUnit="MINUTES"
    expirationInterval="5"
    expirationIntervalUnit="MINUTES"/>
```

**Parameter reference:**

| Parameter | What It Does | Default | Recommendation |
|-----------|-------------|---------|----------------|
| persistent | Survives app restart | true | Always true on CloudHub |
| maxEntries | Max entries before eviction | unlimited | Set explicitly to prevent OOM |
| entryTtl | Time-to-live per entry | 30 days | Set based on data freshness needs |
| expirationInterval | How often expired entries are cleaned | 1 minute | 1-5 minutes |

#### Partitioned Object Store

Use partitions to organize data and work around per-partition limits:

```xml
<!-- Partition by region -->
<os:store key="#[vars.orderId]"
    objectStore="orderCache"
    partition="#[vars.region]"/>

<os:retrieve key="#[vars.orderId]"
    objectStore="orderCache"
    partition="#[vars.region]"
    target="cachedOrder"/>
```

### Common Patterns

#### Pattern 1: Distributed Cache

```xml
<os:object-store name="apiCache"
    persistent="true"
    maxEntries="50000"
    entryTtl="5"
    entryTtlUnit="MINUTES"
    expirationInterval="1"
    expirationIntervalUnit="MINUTES"/>

<flow name="cachedApiCall">
    <http:listener config-ref="HTTP" path="/data/{id}"/>

    <!-- Try cache first -->
    <try>
        <os:retrieve key="#[attributes.uriParams.id]"
            objectStore="apiCache" target="cachedResult"/>
        <set-payload value="#[vars.cachedResult]"/>
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <!-- Cache miss: call API and cache result -->
            <http:request config-ref="Backend" method="GET"
                path="/api/data/#[attributes.uriParams.id]"/>
            <os:store key="#[attributes.uriParams.id]"
                objectStore="apiCache" value="#[payload]"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

#### Pattern 2: Distributed Lock

```xml
<os:object-store name="locks"
    persistent="true"
    entryTtl="60"
    entryTtlUnit="SECONDS"
    expirationInterval="10"
    expirationIntervalUnit="SECONDS"/>

<flow name="exclusiveProcessor">
    <try>
        <!-- Acquire lock -->
        <os:store key="processing-lock"
            objectStore="locks"
            value="#[server.dateTime ++ ' - ' ++ server.host]"
            failIfPresent="true"/>

        <!-- Critical section -->
        <flow-ref name="processExclusively"/>

        <!-- Release lock -->
        <os:remove key="processing-lock" objectStore="locks"/>

    <error-handler>
        <on-error-continue type="OS:KEY_ALREADY_EXISTS">
            <logger level="INFO" message="Lock held by another instance, skipping"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

#### Pattern 3: Idempotency Store

```xml
<os:object-store name="processedMessages"
    persistent="true"
    maxEntries="100000"
    entryTtl="24"
    entryTtlUnit="HOURS"
    expirationInterval="5"
    expirationIntervalUnit="MINUTES"/>

<flow name="idempotentProcessor">
    <anypoint-mq:subscriber config-ref="MQ" destination="orders"/>

    <!-- Check if already processed -->
    <os:contains key="#[attributes.messageId]"
        objectStore="processedMessages" target="alreadyProcessed"/>

    <choice>
        <when expression="#[vars.alreadyProcessed]">
            <logger level="INFO" message="Duplicate message, skipping"/>
            <anypoint-mq:ack config-ref="MQ"/>
        </when>
        <otherwise>
            <!-- Process message -->
            <flow-ref name="processOrder"/>

            <!-- Mark as processed -->
            <os:store key="#[attributes.messageId]"
                objectStore="processedMessages" value="#[now()]"/>
            <anypoint-mq:ack config-ref="MQ"/>
        </otherwise>
    </choice>
</flow>
```

### Partition Strategy

```
Scenario: 500,000 orders from 5 regions

Option A: Single partition (BAD)
  - Exceeds 100,000 entry limit
  - All operations compete for same partition

Option B: Partition by region (GOOD)
  - us-east: 120,000 entries (still over limit!)
  - us-west: 80,000 entries
  - eu-west: 100,000 entries
  - ap-east: 100,000 entries
  - ap-south: 100,000 entries

Option C: Partition by region + date (BEST)
  - us-east-2026-02: 30,000 entries
  - us-east-2026-03: 25,000 entries
  - Clean up old partitions with TTL
```

```xml
<!-- Partition key includes region and month -->
<os:store key="#[vars.orderId]"
    objectStore="orderStore"
    partition="#[vars.region ++ '-' ++ now() as String {format: 'yyyy-MM'}]"
    value="#[payload]"/>
```

### Diagnostic Steps

#### Step 1: Check Object Store Usage

```bash
# Via Anypoint CLI
anypoint-cli runtime-mgr:application:describe <app-name> --output json | \
  jq '.objectStoreStats'

# Via REST API
curl -H "Authorization: Bearer $TOKEN" \
  "https://object-store-stats.anypoint.mulesoft.com/api/v1/organizations/$ORG_ID/environments/$ENV_ID/stores" | jq .
```

#### Step 2: Identify Full Partitions

```bash
# Object Store v2 API: list all keys in a partition
curl -H "Authorization: Bearer $TOKEN" \
  "https://object-store-us-east.anypoint.mulesoft.com/api/v1/organizations/$ORG_ID/environments/$ENV_ID/stores/<store-name>/partitions/<partition>/keys" | jq 'length'
```

#### Step 3: Check for Large Values

```bash
# List keys with their sizes (if available)
# Object Store v2 doesn't expose size directly
# Retrieve a sample and check:
curl -H "Authorization: Bearer $TOKEN" \
  "https://object-store-us-east.anypoint.mulesoft.com/api/v1/organizations/$ORG_ID/environments/$ENV_ID/stores/<store-name>/partitions/<partition>/keys/<key>" | wc -c
```

### Error Messages and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `OS:KEY_NOT_FOUND` | Key doesn't exist | Expected for cache misses. Handle in error handler. |
| `OS:KEY_ALREADY_EXISTS` | `failIfPresent=true` and key exists | Expected for locks. Handle in error handler. |
| `OS:STORE_NOT_AVAILABLE` | Object Store service unreachable | Retry. Check CloudHub status page. |
| `OS:MAX_ENTRIES_EXCEEDED` | Partition at capacity | Increase TTL, use more partitions, or increase maxEntries. |
| `OS:INVALID_KEY` | Key too long or contains invalid chars | Keep keys under 256 chars, use alphanumeric + hyphens. |

### Gotchas
- **`maxEntries` is per Object Store config, not per partition** — setting `maxEntries="10000"` limits the TOTAL entries across all partitions of that Object Store config to 10,000.
- **10 MB value limit is for the serialized form** — if you store a Java object, the serialized size may be larger than the in-memory size. JSON serialization is predictable; Java serialization is not.
- **Object Store v2 is eventually consistent** — a `store` followed immediately by a `retrieve` from a different worker may return the old value. Add a small delay or design for eventual consistency.
- **TTL expiration is not instant** — expired entries are cleaned up at the `expirationInterval`. Between expiry and cleanup, `contains` returns true but `retrieve` may return stale data.
- **Object Store operations are network calls** — on CloudHub, each OS operation is an HTTP call to the Object Store service. At 100 ops/sec, this can become a bottleneck for high-throughput applications.
- **Persistent=false on CloudHub is mostly useless** — in-memory Object Store on CloudHub is per-worker and does not survive restarts. Since CH workers restart frequently, always use `persistent="true"`.
- **Object Store v2 keys are case-sensitive** — `Order-123` and `order-123` are different keys. Normalize keys to lowercase to avoid duplicates.
- **No built-in monitoring** — there's no dashboard showing Object Store usage, hit rates, or operation latency. Build custom monitoring using Anypoint Monitoring metrics or the OS API.
- **Cross-region is not supported** — Object Store v2 data is region-specific. If your app runs in US-East and EU-West, each region has its own Object Store.

### Related
- [Memory Budget Breakdown](../memory-budget-breakdown/) — Object Store memory impact
- [Batch Performance Tuning](../batch-performance-tuning/) — using Object Store for batch state
- [CloudHub 2.0 Migration Gotchas](../cloudhub2-migration-gotchas/) — OS behavior on CH2
- [Top 10 Production Incidents](../top-10-production-incidents/) — Object Store in incident scenarios
