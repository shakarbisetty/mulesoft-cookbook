## Database Connection Pool Tuning

> HikariCP pool sizing, idle connection management, and leak detection for Mule 4 database connectors.

### When to Use

- Application experiences intermittent `ConnectionPoolTimeoutException` under load
- Database connections are exhausted during peak hours while idle during off-peak
- Mule workers are waiting for connections instead of processing requests
- CloudHub deployment with limited vCore needs optimal connection utilization
- Multiple flows share a single database and contend for connections

### The Problem

Mule 4's Database Connector uses HikariCP internally, but the defaults (`maxPoolSize=5`, no leak detection, 30-second idle timeout) are almost never correct for production. Developers either set the pool too large (saturating the database) or too small (creating bottlenecks at the Mule layer). The right formula depends on the number of concurrent flows, transaction duration, and database server capacity.

### Configuration

#### Optimal Pool Sizing

The formula for `maxPoolSize` is:

```
maxPoolSize = (number of concurrent DB-accessing flows) x (max concurrent executions per flow) + headroom
```

For a typical Mule 4 app on CloudHub with 1 vCore (2 threads per CPU core):

```xml
<db:config name="Database_Config" doc:name="Database Config">
    <db:my-sql-connection
        host="${db.host}"
        port="${db.port}"
        database="${db.name}"
        user="${db.user}"
        password="${db.password}">
        <db:pooling-profile
            maxPoolSize="10"
            minPoolSize="2"
            acquireIncrement="1"
            maxWait="10"
            maxWaitUnit="SECONDS"
            additionalProperties="#[{
                'connectionTimeout': '10000',
                'idleTimeout': '300000',
                'maxLifetime': '900000',
                'leakDetectionThreshold': '30000',
                'connectionTestQuery': 'SELECT 1'
            }]" />
        <db:connection-properties>
            <db:connection-property key="cachePrepStmts" value="true" />
            <db:connection-property key="prepStmtCacheSize" value="250" />
            <db:connection-property key="prepStmtCacheSqlLimit" value="2048" />
            <db:connection-property key="useServerPrepStmts" value="true" />
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>
```

#### Per-Environment Pool Sizing

```yaml
# dev.yaml — small pool, aggressive leak detection
db.pool.maxSize: 3
db.pool.minIdle: 1
db.pool.idleTimeout: 60000
db.pool.maxLifetime: 300000
db.pool.leakDetection: 5000

# prod.yaml — production tuned
db.pool.maxSize: 15
db.pool.minIdle: 5
db.pool.idleTimeout: 300000
db.pool.maxLifetime: 900000
db.pool.leakDetection: 30000
```

```xml
<db:config name="Database_Config" doc:name="Database Config">
    <db:my-sql-connection
        host="${db.host}"
        port="${db.port}"
        database="${db.name}"
        user="${db.user}"
        password="${db.password}">
        <db:pooling-profile
            maxPoolSize="${db.pool.maxSize}"
            minPoolSize="${db.pool.minIdle}"
            maxWait="10"
            maxWaitUnit="SECONDS"
            additionalProperties="#[{
                'idleTimeout': '${db.pool.idleTimeout}',
                'maxLifetime': '${db.pool.maxLifetime}',
                'leakDetectionThreshold': '${db.pool.leakDetection}'
            }]" />
    </db:my-sql-connection>
</db:config>
```

#### Separate Pools for Read vs Write

```xml
<!-- Read-heavy pool: more connections, shorter timeout -->
<db:config name="Database_Read_Config" doc:name="DB Read Pool">
    <db:my-sql-connection
        host="${db.read.host}"
        port="${db.port}"
        database="${db.name}"
        user="${db.readUser}"
        password="${db.readPassword}">
        <db:pooling-profile
            maxPoolSize="20"
            minPoolSize="5"
            maxWait="5"
            maxWaitUnit="SECONDS" />
        <db:connection-properties>
            <db:connection-property key="readOnly" value="true" />
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>

<!-- Write pool: smaller, longer timeout for transactions -->
<db:config name="Database_Write_Config" doc:name="DB Write Pool">
    <db:my-sql-connection
        host="${db.write.host}"
        port="${db.port}"
        database="${db.name}"
        user="${db.writeUser}"
        password="${db.writePassword}">
        <db:pooling-profile
            maxPoolSize="8"
            minPoolSize="2"
            maxWait="15"
            maxWaitUnit="SECONDS" />
    </db:my-sql-connection>
</db:config>
```

#### Connection Health Monitoring Flow

```xml
<flow name="db-pool-health-check-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/health/db"
        allowedMethods="GET" />

    <try doc:name="Test Connection">
        <db:select config-ref="Database_Config" doc:name="Ping DB">
            <db:sql><![CDATA[SELECT 1 AS health]]></db:sql>
        </db:select>

        <ee:transform doc:name="Health Response">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "UP",
    database: "connected",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <error-handler>
            <on-error-continue type="DB:CONNECTIVITY, DB:QUERY_EXECUTION">
                <ee:transform doc:name="Unhealthy Response">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "DOWN",
    database: "unreachable",
    error: error.description,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                    </ee:message>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 503 }]]></ee:set-attributes>
                </ee:transform>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

fun calculatePoolSize(concurrentFlows: Number, threadsPerFlow: Number, headroomPercent: Number): Number =
    ceil((concurrentFlows * threadsPerFlow) * (1 + headroomPercent / 100))

fun poolSizeForVcores(vcores: Number, dbFlowCount: Number): Number = do {
    var threadsPerVcore = 2
    var totalThreads = vcores * threadsPerVcore
    var maxConcurrent = min([totalThreads, dbFlowCount * 2])
    ---
    maxConcurrent + 2
}
---
{
    recommendations: {
        "0.1_vCore": poolSizeForVcores(0.1, 3),
        "0.2_vCore": poolSizeForVcores(0.2, 3),
        "1_vCore": poolSizeForVcores(1, 5),
        "2_vCore": poolSizeForVcores(2, 8),
        "4_vCore": poolSizeForVcores(4, 12)
    }
}
```

### Gotchas

- **`maxPoolSize` vs database `max_connections`** — If you have 4 CloudHub workers each with `maxPoolSize=15`, that is 60 connections to the database. Most MySQL/PostgreSQL defaults allow 100-150 connections total. Your pool size multiplied by worker count must stay well below the database max
- **`maxLifetime` must be shorter than database timeout** — MySQL's `wait_timeout` defaults to 8 hours. HikariCP's `maxLifetime` must be at least 30 seconds shorter to avoid handing out a connection that the database is about to kill. Set `maxLifetime` to 900000 (15 minutes) as a safe starting point
- **`idleTimeout` only applies when `minPoolSize` is less than `maxPoolSize`** — If you set `minPoolSize` equal to `maxPoolSize`, idle connections are never evicted. This wastes database resources during off-peak
- **Leak detection false positives** — Setting `leakDetectionThreshold` too low (under 10 seconds) triggers warnings for legitimate long-running queries. Start at 30 seconds in production and lower it only during debugging
- **CloudHub connection limits** — CloudHub 2.0 Shared Space has networking constraints. Each vCore handles a limited number of outbound connections. If your pool is larger than what the networking layer supports, connections will fail at the TCP level, not the pool level
- **Prepared statement cache** — Enabling `cachePrepStmts` with `useServerPrepStmts` on MySQL dramatically improves performance for repeated queries but increases memory per connection. On memory-constrained workers (0.1 vCore), keep `prepStmtCacheSize` under 100

### Testing

```xml
<munit:test name="db-pool-exhaustion-test"
    description="Verify pool timeout behavior under load">

    <munit:behavior>
        <munit-tools:mock-when processor="db:select">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="doc:name"
                    whereValue="Slow Query" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#[[{'id': 1}]]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="db-pool-health-check-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('UP')]" />
    </munit:validation>
</munit:test>
```

### Related

- [Database CDC](../database-cdc/) — CDC polling patterns that depend on pool availability
- [DB Bulk Insert Performance](../db-bulk-insert-performance/) — Batch insert tuning that requires dedicated write pool sizing
