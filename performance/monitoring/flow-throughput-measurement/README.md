## Flow Throughput Measurement
> Measure messages per second per flow using Notifications and Object Store counters.

### When to Use
- Tracking processing rates in real-time
- Capacity planning based on actual throughput
- Alerting when throughput drops below expected rates

### Configuration / Code

```xml
<flow name="monitored-api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>
    <flow-ref name="process-order"/>
    <!-- Increment counter asynchronously -->
    <async>
        <try>
            <os:retrieve key="order-count" objectStore="metrics-store" target="count"/>
            <error-handler>
                <on-error-continue type="OS:KEY_NOT_FOUND">
                    <set-variable variableName="count" value="0"/>
                </on-error-continue>
            </error-handler>
        </try>
        <os:store key="order-count" objectStore="metrics-store">
            <os:value>#[(vars.count as Number) + 1]</os:value>
        </os:store>
    </async>
</flow>

<!-- Scheduled reporter (every 60s) -->
<flow name="throughput-reporter">
    <scheduler><scheduling-strategy><fixed-frequency frequency="60000"/></scheduling-strategy></scheduler>
    <os:retrieve key="order-count" objectStore="metrics-store" target="count"/>
    <logger level="INFO" message="Throughput: #[vars.count] orders in last 60s (#[vars.count / 60] ops/sec)"/>
    <os:store key="order-count" objectStore="metrics-store"><os:value>0</os:value></os:store>
</flow>
```

### How It Works
1. Each processed request increments a counter in Object Store
2. A scheduled flow reads and resets the counter every 60 seconds
3. Log the throughput rate or publish to a custom metric

### Gotchas
- Object Store increment is not atomic — may undercount under high concurrency
- Use Custom Metrics Connector for more accurate production monitoring
- The async scope adds minimal latency but consumes a thread

### Related
- [Custom Business Metrics](../custom-business-metrics/) — production-grade metrics
- [Distributed Tracing](../distributed-tracing-bottlenecks/) — latency analysis
