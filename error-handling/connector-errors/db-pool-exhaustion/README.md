## Database Pool Exhaustion Recovery
> Catch DB:CONNECTIVITY errors when the connection pool is exhausted and return a 503 with Retry-After.

### When to Use
- High-traffic APIs where DB pool can become saturated
- You want graceful degradation instead of generic 500 errors
- Clients need a Retry-After hint to back off

### Configuration / Code

```xml
<flow name="db-query-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/customers"/>
    <db:select config-ref="Database_Config">
        <db:sql>SELECT * FROM customers WHERE region = :region</db:sql>
        <db:input-parameters>#[{region: attributes.queryParams.region}]</db:input-parameters>
    </db:select>
    <error-handler>
        <on-error-propagate type="DB:CONNECTIVITY">
            <set-variable variableName="httpStatus" value="503"/>
            <set-payload value='#[output application/json --- {error: "Service Unavailable", message: "Database connection pool exhausted. Please retry.", retryAfter: 5}]' mimeType="application/json"/>
            <set-variable variableName="outboundHeaders" value="#[{'Retry-After': '5'}]"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. When all connections in the pool are in use, new requests get `DB:CONNECTIVITY`
2. The handler returns 503 with a `Retry-After` header (5 seconds)
3. Clients that respect `Retry-After` will wait before retrying

### Gotchas
- Pool exhaustion often indicates undersized pool — check `maxPoolSize` in your DB config
- Leaked connections (not closed) are a common cause — enable `leakDetectionThreshold` in HikariCP
- Monitor pool metrics via JMX to set proper thresholds

### Related
- [DB HikariCP Pool](../../../performance/connections/db-hikaricp-pool/) — pool configuration
- [HTTP 429 Backoff](../http-429-backoff/) — similar retry-after pattern for HTTP
