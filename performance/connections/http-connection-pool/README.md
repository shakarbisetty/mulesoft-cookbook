## HTTP Connection Pooling
> Configure maxConnections and idle timeouts on HTTP requesters.

### When to Use
- High-throughput APIs making many downstream HTTP calls
- Connection reuse for persistent backends

### Configuration / Code

```xml
<http:request-config name="Backend_API" responseTimeout="10000">
    <http:request-connection host="api.example.com" port="443" protocol="HTTPS">
        <http:client-socket-properties connectionTimeout="5000"/>
        <http:pooling-profile maxActive="20" maxIdle="5" maxWait="10000"
                              exhaustedAction="WHEN_EXHAUSTED_WAIT"/>
    </http:request-connection>
</http:request-config>
```

### How It Works
1. `maxActive` — maximum open connections to this host
2. `maxIdle` — connections kept alive when not in use
3. `maxWait` — time to wait for a connection before throwing an error
4. `exhaustedAction` — WAIT, FAIL, or GROW when pool is full

### Gotchas
- `maxActive` should match your maxConcurrency — more concurrent requests than connections causes queuing
- Idle connections consume memory and server resources — set `maxIdle` conservatively
- `WHEN_EXHAUSTED_GROW` bypasses the pool limit — avoid in production

### Related
- [DB HikariCP Pool](../db-hikaricp-pool/) — database connection pooling
- [Connection Timeouts](../connection-timeouts/) — timeout configuration
