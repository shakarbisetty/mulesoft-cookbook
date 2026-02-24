## Custom Metrics to New Monitoring API
> Migrate custom metrics from legacy Anypoint Monitoring API to current implementation

### When to Use
- Custom metrics API deprecated or changed
- Moving from custom metrics to standard OTel metrics
- Need to update metric collection for new monitoring backend

### Configuration / Code

#### 1. Anypoint Custom Metrics Connector

```xml
<!-- Custom metric reporting -->
<dependency>
    <groupId>com.mulesoft.modules</groupId>
    <artifactId>mule-custom-metrics-extension</artifactId>
    <version>2.2.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

```xml
<flow name="orderProcessingFlow">
    <http:listener config-ref="HTTP_Listener" path="/orders" />

    <!-- Record custom metric -->
    <custom-metrics:send config-ref="Custom_Metrics"
        metricName="order_processing">
        <custom-metrics:dimensions>
            <custom-metrics:dimension dimensionName="region"
                value="#[vars.region]" />
            <custom-metrics:dimension dimensionName="order_type"
                value="#[vars.orderType]" />
        </custom-metrics:dimensions>
        <custom-metrics:facts>
            <custom-metrics:fact factName="order_count" value="1" />
            <custom-metrics:fact factName="order_amount"
                value="#[payload.amount]" />
        </custom-metrics:facts>
    </custom-metrics:send>
</flow>
```

#### 2. Migration to OTel Metrics

```xml
<!-- Replace custom metrics with OTel-compatible approach -->
<!-- Use Java module to emit OTel metrics -->
<java:invoke-static
    class="com.mycompany.metrics.MetricsEmitter"
    method="recordOrderMetric(String,String,double)">
    <java:args>#[{
        region: vars.region,
        orderType: vars.orderType,
        amount: payload.amount
    }]</java:args>
</java:invoke-static>
```

```java
// MetricsEmitter.java
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.DoubleHistogram;

public class MetricsEmitter {
    private static final Meter meter = GlobalOpenTelemetry.getMeter("mule-app");
    private static final LongCounter orderCounter = meter
        .counterBuilder("order_count").build();
    private static final DoubleHistogram orderAmount = meter
        .histogramBuilder("order_amount").build();

    public static void recordOrderMetric(String region, String type, double amount) {
        Attributes attrs = Attributes.of(
            AttributeKey.stringKey("region"), region,
            AttributeKey.stringKey("order_type"), type
        );
        orderCounter.add(1, attrs);
        orderAmount.record(amount, attrs);
    }
}
```

#### 3. Prometheus-Style Metrics Endpoint

```xml
<!-- Expose /metrics endpoint for scraping -->
<http:listener config-ref="HTTP_Listener" path="/metrics">
    <http:response statusCode="200">
        <http:headers>#[{'Content-Type': 'text/plain'}]</http:headers>
    </http:response>
</http:listener>
<java:invoke-static
    class="com.mycompany.metrics.PrometheusExporter"
    method="getMetrics()" />
```

### How It Works
1. Anypoint Custom Metrics extension sends metrics to Anypoint Monitoring
2. OTel metrics use standard counters, histograms, and gauges
3. Metrics can be exported via OTLP or Prometheus scrape endpoint
4. Dimensions map to OTel Attributes for filtering and grouping

### Migration Checklist
- [ ] Inventory all custom metrics currently reported
- [ ] Map dimensions/facts to OTel attributes/measurements
- [ ] Implement OTel metric recording (Java module or OTel agent)
- [ ] Configure metric export (OTLP or Prometheus)
- [ ] Create equivalent dashboards in new backend
- [ ] Migrate alerting rules
- [ ] Remove custom metrics connector dependency

### Gotchas
- Custom Metrics extension only works with Anypoint Monitoring backend
- OTel metric types (counter, histogram, gauge) must match the measurement semantics
- Prometheus metric naming conventions differ from Anypoint (snake_case, units suffix)
- High-cardinality dimensions can cause metric explosion

### Related
- [anypoint-to-otel](../anypoint-to-otel/) - Full OTel migration
- [splunk-to-otlp](../splunk-to-otlp/) - Log/metric export
