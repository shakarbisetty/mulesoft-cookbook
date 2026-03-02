# Connection Pool Tuning by vCore Size

## Problem

Default connection pool settings in Mule applications (HikariCP for databases, HTTP requester pools for APIs) are tuned for server-class hardware with gigabytes of memory and multiple CPU cores. On CloudHub workers — especially 0.1 and 0.2 vCores with 500MB-1GB of memory — these defaults exhaust heap, cause garbage collection storms, and trigger OutOfMemoryErrors. Over-sized connection pools are the number one cause of OOM crashes on small CloudHub workers, leading teams to upgrade vCores when the fix is proper pool tuning.

## Solution

vCore-specific connection pool configurations for HikariCP (database) and HTTP requester (API calls), with DataWeave-based dynamic sizing that adjusts pools based on available memory. Includes Mule XML configuration examples and properties files for each vCore tier.

## Implementation

### Optimal Pool Sizes by vCore

| vCore | Memory | Available Heap | DB Pool Max | HTTP Pool Max | Total Connections | Rationale |
|-------|--------|---------------|-------------|---------------|-------------------|-----------|
| 0.1   | 500 MB | ~200 MB free  | 2-3         | 3-5           | 5-8               | JVM base + Mule runtime consume ~300MB; minimal headroom |
| 0.2   | 1 GB   | ~500 MB free  | 5-8         | 8-10          | 13-18             | Enough for moderate concurrency |
| 0.5   | 1.5 GB | ~800 MB free  | 8-12        | 10-15         | 18-27             | Comfortable for standard workloads |
| 1.0   | 3.5 GB | ~2.2 GB free  | 10-20       | 15-25         | 25-45             | Can handle concurrent batch + API |
| 2.0   | 7.5 GB | ~5 GB free    | 20-30       | 25-40         | 45-70             | High-throughput scenarios |
| 4.0   | 15 GB  | ~11 GB free   | 30-50       | 40-60         | 70-110            | Enterprise-grade concurrency |

### Memory Cost per Connection

```
Each connection costs memory:

Database (HikariCP):
  - Connection object:      ~5-10 KB
  - Statement cache:        ~50-100 KB (if enabled)
  - Result set buffers:     ~1-5 MB (depends on fetch size)
  - Total per connection:   ~1-5 MB

HTTP Requester:
  - Socket buffer:          ~32-64 KB
  - TLS session:            ~20-40 KB (if HTTPS)
  - Response buffer:        ~256 KB - 2 MB
  - Total per connection:   ~0.5-2 MB

Rule of thumb:
  Maximum connections ≈ Available Heap / (Avg Memory per Connection × 2)
  The ×2 factor accounts for GC overhead and request processing memory.
```

### Database Pool Configuration (HikariCP)

#### Properties File by Environment

```properties
# config-0.1vcore.properties
db.pool.maxSize=3
db.pool.minIdle=1
db.pool.connectionTimeout=10000
db.pool.idleTimeout=300000
db.pool.maxLifetime=900000
db.pool.leakDetectionThreshold=30000
db.statement.cacheSize=50

# config-0.2vcore.properties
db.pool.maxSize=5
db.pool.minIdle=2
db.pool.connectionTimeout=10000
db.pool.idleTimeout=300000
db.pool.maxLifetime=900000
db.pool.leakDetectionThreshold=30000
db.statement.cacheSize=100

# config-1.0vcore.properties
db.pool.maxSize=15
db.pool.minIdle=5
db.pool.connectionTimeout=15000
db.pool.idleTimeout=600000
db.pool.maxLifetime=1800000
db.pool.leakDetectionThreshold=60000
db.statement.cacheSize=250

# config-2.0vcore.properties
db.pool.maxSize=25
db.pool.minIdle=8
db.pool.connectionTimeout=15000
db.pool.idleTimeout=600000
db.pool.maxLifetime=1800000
db.pool.leakDetectionThreshold=60000
db.statement.cacheSize=500
```

#### Mule XML Database Configuration

```xml
<db:config name="DatabaseConfig">
    <db:my-sql-connection
        host="${db.host}"
        port="${db.port}"
        database="${db.name}"
        user="${db.user}"
        password="${db.password}">
        <db:pooling-profile
            maxPoolSize="${db.pool.maxSize}"
            minPoolSize="${db.pool.minIdle}"
            acquireTimeoutUnit="MILLISECONDS"
            acquireTimeout="${db.pool.connectionTimeout}"
            maxIdleTime="${db.pool.idleTimeout}"
            maxLifetime="${db.pool.maxLifetime}"/>
        <db:connection-properties>
            <db:connection-property key="cachePrepStmts" value="true"/>
            <db:connection-property key="prepStmtCacheSize" value="${db.statement.cacheSize}"/>
            <db:connection-property key="useServerPrepStmts" value="true"/>
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>
```

### HTTP Requester Pool Configuration

```xml
<!-- HTTP Requester with vCore-appropriate pool settings -->
<http:request-config name="SystemApiConfig">
    <http:request-connection
        host="${system.api.host}"
        port="${system.api.port}"
        protocol="HTTPS">
        <http:client-socket-properties>
            <sockets:tcp-client-socket-properties
                connectionTimeout="10000"
                clientTimeout="30000"
                keepAlive="true"
                sendBufferSize="32768"
                receiveBufferSize="32768"/>
        </http:client-socket-properties>
    </http:request-connection>
</http:request-config>

<!--
    HTTP requester pool is controlled via system properties:
    -Dhttp.maxConnections=15         (total pool size)
    -Dhttp.maxConnectionsPerHost=10  (per-host limit)
    -Dhttp.connectionIdleTimeout=30  (seconds)

    Set these in Runtime Manager > App Settings > Properties
    Adjust per vCore tier.
-->
```

### Dynamic Pool Sizing with DataWeave

```dataweave
%dw 2.0
output application/json

// Read available memory at runtime to calculate optimal pool sizes
var runtimeMemoryMB = 3500  // Replace with actual from JMX or system property
var muleRuntimeOverhead = 300
var connectorOverhead = 100
var gcHeadroom = 0.30

var availableMemory = (runtimeMemoryMB - muleRuntimeOverhead - connectorOverhead) * (1 - gcHeadroom)

// Memory cost assumptions
var dbConnectionMemoryMB = 3     // Average including result set buffers
var httpConnectionMemoryMB = 1.5 // Average including TLS and response buffers

// Allocation strategy: 40% DB, 40% HTTP, 20% processing
var dbBudget = availableMemory * 0.40
var httpBudget = availableMemory * 0.40

var optimalDbPool = min([floor(dbBudget / dbConnectionMemoryMB), 50])
var optimalHttpPool = min([floor(httpBudget / httpConnectionMemoryMB), 60])
---
{
    totalMemoryMB: runtimeMemoryMB,
    availableForPoolsMB: availableMemory,
    recommendation: {
        dbPoolMax: max([optimalDbPool, 2]),      // Minimum 2
        httpPoolMax: max([optimalHttpPool, 3]),   // Minimum 3
        dbMinIdle: max([floor(optimalDbPool / 3), 1]),
        httpKeepAlive: true,
        statementCacheSize: if (optimalDbPool > 10) 250 else 50
    },
    memoryAllocation: {
        dbPoolMB: max([optimalDbPool, 2]) * dbConnectionMemoryMB,
        httpPoolMB: max([optimalHttpPool, 3]) * httpConnectionMemoryMB,
        processingMB: availableMemory * 0.20,
        totalAllocatedMB: (max([optimalDbPool, 2]) * dbConnectionMemoryMB) +
                          (max([optimalHttpPool, 3]) * httpConnectionMemoryMB) +
                          (availableMemory * 0.20)
    }
}
```

### Common Misconfigurations and Fixes

| Misconfiguration | vCore | Symptom | Fix |
|------------------|-------|---------|-----|
| `maxPoolSize=20` on 0.1 vCore | 0.1 | OOM after 50 requests | Reduce to `maxPoolSize=3` |
| `minIdle=10` on 0.2 vCore | 0.2 | 500MB consumed at startup | Reduce to `minIdle=2` |
| No `maxLifetime` set | Any | Connection leaks after DB failover | Set `maxLifetime=1800000` |
| `fetchSize=1000` on 0.1 vCore | 0.1 | OOM on first query with large result | Set `fetchSize=50` |
| Unlimited HTTP pool | 0.2 | Thread exhaustion under load | Set `http.maxConnections=10` |
| No idle timeout | Any | Stale connections cause errors | Set `idleTimeout=300000` |

## How It Works

1. **Identify your vCore size** from Runtime Manager and look up the recommended pool limits in the sizing table.
2. **Configure database pools** using the environment-specific properties files. Use `db.pool.maxSize` values from the table as your ceiling.
3. **Configure HTTP requester pools** via JVM system properties in Runtime Manager app settings.
4. **Deploy and monitor** heap usage in Anypoint Monitoring. If heap stays below 70% at peak traffic, the pool sizing is correct.
5. **If you need more connections** than the table allows for your vCore, upgrade the vCore rather than increasing pool size. Exceeding the limits causes OOM.

## Key Takeaways

- A 0.1 vCore worker should never have more than 3 database connections and 5 HTTP connections total.
- Each database connection consumes 1-5MB including statement cache and result buffers.
- Default pool sizes from documentation and tutorials are tuned for development machines, not CloudHub workers.
- Set `maxLifetime` on all pools to prevent stale connection errors after database failovers.
- The dynamic sizing DataWeave can be run as a startup script to auto-configure pools based on detected memory.

## Related Recipes

- [vcore-benchmark-by-workload](../vcore-benchmark-by-workload/) — Throughput expectations per vCore
- [t2-burstable-monitoring](../t2-burstable-monitoring/) — Small vCore workers need pool tuning most
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Right-size vCores after tuning pools
- [idle-worker-detection](../idle-worker-detection/) — Detect idle connections wasting pool slots
