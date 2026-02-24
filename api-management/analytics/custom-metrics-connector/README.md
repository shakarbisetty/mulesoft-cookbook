## Custom Metrics via Anypoint Monitoring Connector
> Push custom business metrics from Mule flows to Anypoint Monitoring dashboards.

### When to Use
- Tracking business KPIs (orders processed, revenue, SLA compliance)
- Custom dashboards beyond standard API analytics
- Alerting on business-level thresholds

### Configuration / Code

```xml
<flow name="order-processing">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <flow-ref name="process-order"/>
    <!-- Push custom metric -->
    <anypoint-monitoring:custom-metric metricName="orders_processed">
        <anypoint-monitoring:dimensions>
            <anypoint-monitoring:dimension key="region" value="#[payload.region]"/>
            <anypoint-monitoring:dimension key="priority" value="#[payload.priority]"/>
        </anypoint-monitoring:dimensions>
        <anypoint-monitoring:facts>
            <anypoint-monitoring:fact key="order_total" value="#[payload.total]"/>
            <anypoint-monitoring:fact key="item_count" value="#[sizeOf(payload.items)]"/>
        </anypoint-monitoring:facts>
    </anypoint-monitoring:custom-metric>
</flow>
```

### How It Works
1. Custom metric connector sends data points to Anypoint Monitoring
2. Dimensions are labels for filtering and grouping (region, priority)
3. Facts are numeric values that can be aggregated (sum, avg, count)
4. Data appears in custom dashboards within minutes

### Gotchas
- Custom metrics require Titanium subscription tier
- Maximum 20 dimensions and 20 facts per metric
- Metric names should be stable — renaming loses historical data
- High-cardinality dimensions (per-user, per-order) cause dashboard performance issues

### Related
- [Analytics Dashboard](../analytics-dashboard/) — building dashboards
- [OTel Telemetry Export](../otel-telemetry-export/) — exporting to external tools
