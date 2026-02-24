## Custom Business Metrics
> Publish custom KPIs to Anypoint Monitoring dashboards.

### When to Use
- Tracking business metrics (orders/min, revenue, error rate by type)
- Custom dashboards beyond built-in API analytics
- Correlating business events with technical metrics

### Configuration / Code

```xml
<custom-metrics:send config-ref="Custom_Metrics"
                     xmlns:custom-metrics="http://www.mulesoft.org/schema/mule/custom-metrics">
    <custom-metrics:metric metricName="order_processed" value="1">
        <custom-metrics:dimensions>
            <custom-metrics:dimension dimensionName="region" value="#[vars.region]"/>
            <custom-metrics:dimension dimensionName="status" value="success"/>
        </custom-metrics:dimensions>
    </custom-metrics:metric>
</custom-metrics:send>
```

### How It Works
1. Custom Metrics Connector sends metrics to Anypoint Monitoring
2. Metrics appear in custom dashboards with dimensions for filtering
3. Set alerts based on metric thresholds

### Gotchas
- Requires Anypoint Monitoring Titanium subscription
- Metric names and dimensions are case-sensitive
- Maximum 20 dimensions per metric
- Sending metrics adds ~2ms latency — use async for non-critical metrics

### Related
- [Distributed Tracing](../distributed-tracing-bottlenecks/) — trace-level monitoring
- [Flow Throughput](../flow-throughput-measurement/) — throughput tracking
