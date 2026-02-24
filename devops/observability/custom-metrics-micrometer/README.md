## Custom Metrics with Micrometer
> Business metrics and technical counters with Micrometer and Prometheus

### When to Use
- You need business-level metrics beyond standard HTTP metrics (orders processed, revenue, etc.)
- You want Prometheus-compatible metrics for Grafana dashboards and alerting
- You need to track custom SLIs for your integration flows

### Configuration

**Custom metrics via Mule flow (using Object Store for counters)**
```xml
<!-- Metrics endpoint flow -->
<flow name="metrics-endpoint-flow">
    <http:listener path="/metrics" method="GET"
        config-ref="HTTP_Metrics_Listener" />

    <!-- Collect metrics from Object Store -->
    <os:retrieve key="metrics.orders.processed"
        objectStore="metricsStore" target="ordersProcessed">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <os:retrieve key="metrics.orders.failed"
        objectStore="metricsStore" target="ordersFailed">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <os:retrieve key="metrics.revenue.total"
        objectStore="metricsStore" target="totalRevenue">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <!-- Prometheus exposition format -->
    <set-payload value='#[output text/plain ---
"# HELP orders_processed_total Total orders processed
# TYPE orders_processed_total counter
orders_processed_total " ++ vars.ordersProcessed ++ "

# HELP orders_failed_total Total orders that failed processing
# TYPE orders_failed_total counter
orders_failed_total " ++ vars.ordersFailed ++ "

# HELP revenue_total_dollars Total revenue in dollars
# TYPE revenue_total_dollars counter
revenue_total_dollars " ++ vars.totalRevenue ++ "

# HELP order_processing_duration_seconds Order processing duration
# TYPE order_processing_duration_seconds histogram
"
    ]' />
</flow>

<!-- Increment counters in business flows -->
<flow name="process-order-flow">
    <set-variable variableName="startTime" value="#[now()]" />

    <!-- Business logic here -->
    <flow-ref name="validate-order-flow" />
    <flow-ref name="persist-order-flow" />

    <!-- Increment success counter -->
    <os:retrieve key="metrics.orders.processed"
        objectStore="metricsStore" target="currentCount">
        <os:default-value>0</os:default-value>
    </os:retrieve>
    <os:store key="metrics.orders.processed"
        objectStore="metricsStore">
        <os:value>#[vars.currentCount as Number + 1]</os:value>
    </os:store>

    <!-- Track revenue -->
    <os:retrieve key="metrics.revenue.total"
        objectStore="metricsStore" target="currentRevenue">
        <os:default-value>0</os:default-value>
    </os:retrieve>
    <os:store key="metrics.revenue.total"
        objectStore="metricsStore">
        <os:value>#[vars.currentRevenue as Number + payload.totalAmount]</os:value>
    </os:store>

    <error-handler>
        <on-error-continue>
            <os:retrieve key="metrics.orders.failed"
                objectStore="metricsStore" target="failCount">
                <os:default-value>0</os:default-value>
            </os:retrieve>
            <os:store key="metrics.orders.failed"
                objectStore="metricsStore">
                <os:value>#[vars.failCount as Number + 1]</os:value>
            </os:store>
        </on-error-continue>
    </error-handler>
</flow>
```

**Prometheus scrape config (prometheus.yml)**
```yaml
scrape_configs:
  - job_name: "mulesoft"
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets:
          - "order-api:8081"
          - "inventory-api:8081"
          - "payment-api:8081"
        labels:
          environment: "prod"

    # For CloudHub, use Anypoint Monitoring API or DLB metrics
    # static_configs won't work with dynamic CloudHub IPs
```

**Grafana dashboard JSON (key panels)**
```json
{
  "panels": [
    {
      "title": "Orders Processed (Rate)",
      "targets": [{"expr": "rate(orders_processed_total[5m])"}],
      "type": "timeseries"
    },
    {
      "title": "Error Rate (%)",
      "targets": [{"expr": "rate(orders_failed_total[5m]) / rate(orders_processed_total[5m]) * 100"}],
      "type": "gauge",
      "thresholds": [
        {"value": 0, "color": "green"},
        {"value": 1, "color": "yellow"},
        {"value": 5, "color": "red"}
      ]
    },
    {
      "title": "Revenue per Hour",
      "targets": [{"expr": "increase(revenue_total_dollars[1h])"}],
      "type": "stat"
    }
  ]
}
```

### How It Works
1. Business metrics are tracked in Object Store counters, incremented during flow execution
2. A `/metrics` endpoint exposes counters in Prometheus exposition format
3. Prometheus scrapes the metrics endpoint at regular intervals (30s)
4. Grafana dashboards visualize rates, gauges, and histograms from Prometheus
5. Error handlers increment failure counters for error rate calculations

### Gotchas
- Object Store counters are not atomic — under high concurrency, counts may be slightly off
- For accurate high-throughput metrics, use a proper metrics library (Micrometer) via custom Java module
- Prometheus scraping requires network access to the Mule app; use a push gateway for CloudHub
- The `/metrics` endpoint should be on a separate port or secured to prevent public access
- Histogram metrics require bucketing configuration; counters and gauges are simpler to start with
- CloudHub 2.0 apps are behind a DLB — Prometheus cannot scrape directly without VPN

### Related
- [distributed-tracing-otel](../distributed-tracing-otel/) — Distributed tracing
- [log-aggregation](../log-aggregation/) — Structured logging
- [slo-sli-alerting](../slo-sli-alerting/) — Alert on business metrics
