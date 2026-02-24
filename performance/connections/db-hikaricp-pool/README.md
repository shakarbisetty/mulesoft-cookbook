## Database HikariCP Pool
> Replace default pool with HikariCP for faster acquisition and leak detection.

### When to Use
- Default Mule DB pool has slow connection acquisition
- You need connection leak detection
- High-throughput database operations

### Configuration / Code

```xml
<db:config name="Database_Config">
    <db:my-sql-connection host="${db.host}" port="3306" database="${db.name}"
                          user="${db.user}" password="${db.password}">
        <db:pooling-profile maxPoolSize="20" minPoolSize="5"
                            acquireIncrement="2" maxIdleTime="300"/>
        <db:connection-properties>
            <db:connection-property key="cachePrepStmts" value="true"/>
            <db:connection-property key="prepStmtCacheSize" value="250"/>
            <db:connection-property key="prepStmtCacheSqlLimit" value="2048"/>
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>
```

### How It Works
1. `maxPoolSize` caps open connections; `minPoolSize` keeps warm connections ready
2. Prepared statement caching avoids re-parsing SQL on every call
3. `maxIdleTime` closes stale connections to free DB resources

### Gotchas
- `maxPoolSize` per app × number of workers = total DB connections (watch DB connection limits)
- Leaked connections exhaust the pool — enable leak detection with `leakDetectionThreshold`
- Connection validation query adds latency — use `isValid()` instead of test queries

### Troubleshooting: Diagnosing Pool Exhaustion

When your app hangs with "Connection is not available, request timed out after 30000ms", follow this step-by-step diagnosis:

#### Step 1: Confirm Pool Exhaustion from Thread Dumps

```bash
# Take 3 thread dumps 10 seconds apart
jstack <pid> > dump1.txt && sleep 10 && jstack <pid> > dump2.txt && sleep 10 && jstack <pid> > dump3.txt

# Search for HikariCP pool wait signature:
grep -A 5 "HikariPool" dump1.txt
# Look for threads in TIMED_WAITING state:
#   at com.zaxxer.hikari.pool.HikariPool.getConnection(HikariPool.java:...)
#   - waiting on <0x...> (a java.util.concurrent.SynchronousQueue$TransferStack)
```

If many threads show this pattern across all 3 dumps, pool is exhausted.

#### Step 2: Check JMX Pool Metrics

Enable JMX and query HikariCP metrics:

```xml
<!-- Add to log4j2.xml for HikariCP debug logging -->
<Logger name="com.zaxxer.hikari" level="DEBUG" />
<Logger name="com.zaxxer.hikari.pool.HikariPool" level="DEBUG" />

<!-- Key metrics to monitor: -->
<!-- HikariPool-1.pool.ActiveConnections — currently in use -->
<!-- HikariPool-1.pool.IdleConnections — available but idle -->
<!-- HikariPool-1.pool.TotalConnections — active + idle -->
<!-- HikariPool-1.pool.PendingThreads — threads waiting for connection -->
```

| Metric | Healthy | Exhausted |
|--------|---------|-----------|
| ActiveConnections | < maxPoolSize | = maxPoolSize |
| IdleConnections | > 0 | 0 |
| PendingThreads | 0 | > 0 (growing) |
| TotalConnections | = maxPoolSize | = maxPoolSize |

#### Step 3: Identify Root Cause

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Active = max, steady | Pool too small for load | Increase `maxPoolSize` |
| Active = max, grows over hours | Connection leak | Enable leak detection, fix unclosed try blocks |
| Active = max, spikes | Slow queries holding connections | Add query timeout, optimize SQL |
| Total < max, pending > 0 | Connection creation failing | Check DB reachability, max_connections on DB |

#### Step 4: Enable Leak Detection

```xml
<db:pooling-profile maxPoolSize="20" minPoolSize="5"
                    acquireIncrement="2" maxIdleTime="300">
    <!-- Leak detection: log warning if connection held > 60 seconds -->
    <db:connection-property key="leakDetectionThreshold" value="60000" />
</db:pooling-profile>
```

When a connection is held longer than the threshold, HikariCP logs a stack trace showing exactly which code is holding the connection. Look for:
- Missing `finally` blocks that close connections
- Long-running transforms between DB operations
- Scatter-gather where one branch holds a connection while waiting for others

#### Pool Sizing Formula

```
maxPoolSize = (peak_concurrent_requests × avg_db_calls_per_request) / avg_query_time_ms × 1000

Example:
  50 concurrent requests × 3 DB calls each / (20ms avg × 1000) = 7.5 → use 10
  Add 20% headroom → maxPoolSize = 12
```

### Related
- [HTTP Connection Pool](../http-connection-pool/) — HTTP equivalent
- [Pool Sizing by DB](../../database/pool-sizing-by-db/) — vendor-specific sizing
