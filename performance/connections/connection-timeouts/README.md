## Connection Timeout Strategy
> Set connect, read, and response timeouts per connector to fail fast.

### When to Use
- Downstream services with varying response times
- You want to fail fast on hung backends
- Different timeout requirements for different integrations

### Configuration / Code

```xml
<!-- HTTP: 5s connect, 30s response -->
<http:request-config name="Slow_Backend" responseTimeout="30000">
    <http:request-connection host="slow-api.example.com" port="443" protocol="HTTPS">
        <http:client-socket-properties connectionTimeout="5000"/>
    </http:request-connection>
</http:request-config>

<!-- DB: 10s query timeout -->
<db:select config-ref="Database_Config" queryTimeout="10" queryTimeoutUnit="SECONDS">
    <db:sql>SELECT * FROM large_table WHERE status = :status</db:sql>
    <db:input-parameters>#[{status: "active"}]</db:input-parameters>
</db:select>
```

### How It Works
1. `connectionTimeout` — how long to wait for TCP connection establishment
2. `responseTimeout` — how long to wait for the full response
3. `queryTimeout` — how long to wait for a DB query to complete

### Gotchas
- `connectionTimeout` should be shorter than `responseTimeout`
- A 0 or -1 value usually means infinite timeout — never use in production
- Timeouts throw specific error types (HTTP:TIMEOUT, DB:QUERY_EXECUTION) — handle them

### Related
- [HTTP Timeout Fallback](../../../error-handling/connector-errors/http-timeout-fallback/) — fallback on timeout
- [HTTP Connection Pool](../http-connection-pool/) — pool configuration
