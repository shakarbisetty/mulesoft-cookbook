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

### Related
- [HTTP Connection Pool](../http-connection-pool/) — HTTP equivalent
- [Pool Sizing by DB](../../database/pool-sizing-by-db/) — vendor-specific sizing
