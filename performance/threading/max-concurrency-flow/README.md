## Max Concurrency on Flow Sources
> Limit concurrent HTTP listener processing to match backend capacity.

### When to Use
- Protecting downstream systems from being overwhelmed
- Limiting memory usage during traffic spikes
- Back-pressure to signal load balancers when capacity is reached

### Configuration / Code

```xml
<!-- Limit to 20 concurrent requests -->
<flow name="api-flow" maxConcurrency="20">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>
    <db:select config-ref="Database_Config">
        <db:sql>SELECT * FROM orders</db:sql>
    </db:select>
</flow>
```

### How It Works
1. `maxConcurrency` limits how many events can be processed simultaneously in the flow
2. When the limit is reached, the HTTP listener applies back-pressure (queues or rejects)
3. This protects both the Mule app and downstream systems

### Gotchas
- Default maxConcurrency varies by source type; HTTP defaults to the UBER pool size
- Setting it too low causes unnecessary queuing and higher latency
- Setting it too high removes the protection — set based on slowest downstream component

### Related
- [Parallel For-Each Bounded](../parallel-foreach-bounded/) — collection-level concurrency
- [Async Back-Pressure](../async-back-pressure/) — async concurrency
