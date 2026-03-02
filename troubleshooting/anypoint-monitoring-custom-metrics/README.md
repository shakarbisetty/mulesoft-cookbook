## Anypoint Monitoring Custom Metrics
> Micrometer integration, custom dashboards, and alerting for Mule 4 applications

### When to Use
- Built-in Anypoint Monitoring metrics don't cover your KPIs
- Need business-level metrics (orders processed, revenue, SLA compliance)
- Want custom dashboards for operations teams
- Need alerting on application-specific thresholds
- Building observability beyond basic CPU/memory/response time

### The Problem

Anypoint Monitoring (Titanium) provides infrastructure metrics (CPU, memory, response time) out of the box. But it doesn't know about YOUR application's business logic. You need custom metrics to answer questions like "How many orders processed per minute?", "What's the 99th percentile of downstream API latency?", or "Are we within SLA for each customer tier?"

### Architecture

```
+------------------+     +--------------------+     +-------------------+
|   Mule App       |     | Anypoint           |     | Custom            |
|   + Micrometer   | --> | Monitoring         | --> | Dashboards        |
|   + Custom       |     | (Titanium)         |     | + Alerts          |
|   Metrics        |     |                    |     |                   |
+------------------+     +--------------------+     +-------------------+
        |
        | (alternative)
        v
+--------------------+
| External Backend   |
| Datadog/Grafana/   |
| Prometheus         |
+--------------------+
```

### Method 1: Anypoint Monitoring Custom Metrics (Titanium)

#### Step 1: Add Micrometer to Your Project

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
    <version>1.12.0</version>
</dependency>
```

#### Step 2: Create a Custom Metrics Module

```java
// src/main/java/com/mycompany/metrics/CustomMetrics.java
package com.mycompany.metrics;

import io.micrometer.core.instrument.*;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.util.concurrent.atomic.AtomicLong;

public class CustomMetrics {

    private static final MeterRegistry registry = Metrics.globalRegistry;

    // Counter: total orders processed
    private static final Counter ordersProcessed = Counter.builder("orders.processed")
        .description("Total orders processed")
        .tag("status", "success")
        .register(registry);

    private static final Counter ordersFailed = Counter.builder("orders.processed")
        .description("Total orders failed")
        .tag("status", "failed")
        .register(registry);

    // Gauge: current queue depth
    private static final AtomicLong queueDepth = new AtomicLong(0);
    static {
        Gauge.builder("orders.queue.depth", queueDepth, AtomicLong::get)
            .description("Current order queue depth")
            .register(registry);
    }

    // Timer: order processing duration
    private static final Timer processingTimer = Timer.builder("orders.processing.time")
        .description("Order processing duration")
        .publishPercentiles(0.5, 0.9, 0.95, 0.99)
        .register(registry);

    // Distribution summary: order amounts
    private static final DistributionSummary orderAmounts =
        DistributionSummary.builder("orders.amount")
            .description("Order amounts in USD")
            .baseUnit("usd")
            .publishPercentiles(0.5, 0.9, 0.99)
            .register(registry);

    public static void recordOrderSuccess() { ordersProcessed.increment(); }
    public static void recordOrderFailure() { ordersFailed.increment(); }
    public static void setQueueDepth(long depth) { queueDepth.set(depth); }
    public static Timer.Sample startTimer() { return Timer.start(registry); }
    public static void stopTimer(Timer.Sample sample) { sample.stop(processingTimer); }
    public static void recordOrderAmount(double amount) { orderAmounts.record(amount); }
}
```

#### Step 3: Use Metrics in Your Flows

```xml
<flow name="orderProcessingFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Start timer -->
    <java:invoke-static class="com.mycompany.metrics.CustomMetrics"
        method="startTimer()" target="timerSample"/>

    <try>
        <!-- Process order -->
        <flow-ref name="processOrder"/>

        <!-- Record success -->
        <java:invoke-static class="com.mycompany.metrics.CustomMetrics"
            method="recordOrderSuccess()"/>

        <!-- Record order amount -->
        <java:invoke-static class="com.mycompany.metrics.CustomMetrics"
            method="recordOrderAmount(double)">
            <java:args>#[{amount: payload.totalAmount as Number}]</java:args>
        </java:invoke-static>

        <!-- Stop timer -->
        <java:invoke-static class="com.mycompany.metrics.CustomMetrics"
            method="stopTimer(io.micrometer.core.instrument.Timer$Sample)">
            <java:args>#[{sample: vars.timerSample}]</java:args>
        </java:invoke-static>

    <error-handler>
        <on-error-continue type="ANY">
            <java:invoke-static class="com.mycompany.metrics.CustomMetrics"
                method="recordOrderFailure()"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

### Method 2: Custom Metrics via DataWeave + Object Store

For teams that prefer a no-code approach:

```xml
<!-- Metrics store -->
<os:object-store name="metricsStore"
    persistent="true"
    entryTtl="1"
    entryTtlUnit="HOURS"/>

<flow name="orderFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Increment counter using Object Store -->
    <try>
        <os:retrieve key="orders.count" objectStore="metricsStore"
            target="currentCount"/>
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <set-variable variableName="currentCount" value="#[0]"/>
        </on-error-continue>
    </error-handler>
    </try>

    <os:store key="orders.count" objectStore="metricsStore"
        value="#[vars.currentCount as Number + 1]"/>

    <!-- Process order... -->
</flow>

<!-- Metrics endpoint for scraping -->
<flow name="metricsEndpoint">
    <http:listener config-ref="HTTP" path="/metrics"/>

    <os:retrieve-all objectStore="metricsStore" target="allMetrics"/>

    <set-payload value='#[output application/json --- {
        timestamp: now(),
        metrics: vars.allMetrics
    }]'/>
</flow>
```

### Method 3: Export to External Backends

#### Prometheus Endpoint

```java
// Add Prometheus registry
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;

public class PrometheusMetrics {
    private static final PrometheusMeterRegistry registry =
        new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);

    public static String scrape() {
        return registry.scrape(); // Returns Prometheus exposition format
    }
}
```

```xml
<!-- Expose /metrics endpoint for Prometheus scraping -->
<flow name="prometheusEndpoint">
    <http:listener config-ref="HTTP" path="/metrics"/>
    <java:invoke-static class="com.mycompany.metrics.PrometheusMetrics"
        method="scrape()" target="payload"/>
    <set-payload value="#[payload]" mimeType="text/plain"/>
</flow>
```

#### Datadog via DogStatsD

```java
import io.micrometer.datadog.DatadogConfig;
import io.micrometer.datadog.DatadogMeterRegistry;

DatadogConfig config = new DatadogConfig() {
    @Override public String apiKey() { return System.getProperty("dd.api.key"); }
    @Override public String get(String key) { return null; }
};

MeterRegistry registry = new DatadogMeterRegistry(config, Clock.SYSTEM);
Metrics.addRegistry(registry);
```

### Building Custom Dashboards in Anypoint Monitoring

#### Step 1: Navigate to Custom Dashboards

1. Anypoint Platform > Monitoring > Custom Dashboards
2. Click **New Dashboard**
3. Add panels

#### Step 2: Create Panels

**Throughput panel (Graph):**
```
Metric: orders.processed
Aggregation: rate
Group by: status
Timeframe: Last 1 hour
```

**Latency panel (Graph with percentiles):**
```
Metric: orders.processing.time
Aggregation: percentile(99)
Timeframe: Last 1 hour
Thresholds: Warning=2000ms, Critical=5000ms
```

**Queue depth panel (Gauge):**
```
Metric: orders.queue.depth
Aggregation: last
Thresholds: Warning=100, Critical=500
```

**Error rate panel (Single stat):**
```
Metric: orders.processed
Filter: status=failed
Aggregation: rate
Display: Percentage of total
```

### Setting Up Alerts

#### Anypoint Monitoring Alerts (Titanium)

1. Navigate to Monitoring > Alerts
2. Click **New Alert**

**Alert: High Error Rate**
```
Condition: orders.processed{status=failed} / orders.processed{} > 0.05
Duration: 5 minutes
Severity: Critical
Notification: Email, Slack, PagerDuty
Message: "Order failure rate exceeded 5% for 5 minutes"
```

**Alert: High Latency**
```
Condition: orders.processing.time.p99 > 5000
Duration: 10 minutes
Severity: Warning
Message: "P99 order processing latency exceeded 5 seconds"
```

**Alert: Queue Buildup**
```
Condition: orders.queue.depth > 500
Duration: 5 minutes
Severity: Critical
Message: "Order queue depth exceeds 500, possible processing slowdown"
```

### Metric Types Cheat Sheet

```
+---------------------+----------------------------+---------------------------+
| Metric Type         | When to Use                | Example                   |
+---------------------+----------------------------+---------------------------+
| Counter             | Count events (monotonic)   | orders.processed          |
| Gauge               | Current value (up/down)    | queue.depth               |
| Timer               | Duration of operations     | processing.time           |
| Distribution Summary| Distribution of values     | order.amount              |
| Long Task Timer     | Duration of long tasks     | batch.job.duration        |
+---------------------+----------------------------+---------------------------+
```

### Gotchas
- **Anypoint Monitoring Titanium is required** — custom metrics, custom dashboards, and advanced alerting require the Titanium subscription tier. The Gold tier only provides built-in dashboards.
- **Metric cardinality explosion** — adding high-cardinality tags (like customerId or orderId) creates a new time series per unique value. 10,000 customers x 5 metrics = 50,000 time series = slow dashboards and high cost. Use low-cardinality tags only (region, status, tier).
- **Micrometer registry must be global** — use `Metrics.globalRegistry` to ensure all components write to the same registry. Multiple registries cause metrics to be split across backends.
- **Timer precision on CloudHub** — CloudHub's time resolution for custom metrics is ~1 minute. Sub-minute fluctuations won't appear in dashboards.
- **Object Store-based metrics have race conditions** — two concurrent requests reading, incrementing, and writing a counter can lose increments. Use atomic operations or accept approximate counts.
- **Custom metrics add overhead** — each metric operation (increment, record) takes ~0.01ms. For extremely high-throughput flows (100,000+ TPS), this is measurable. For typical flows, it's negligible.
- **Dashboard query limits** — Anypoint Monitoring limits the number of data points per query. Long time ranges with high-resolution metrics may be downsampled or truncated.
- **Alert notification flood** — if an alert condition flaps (crosses threshold repeatedly), you can get hundreds of notifications. Configure alert dampening (minimum time between notifications).

### Related
- [Anypoint Monitoring vs OTel](../anypoint-monitoring-vs-otel/) — comparing monitoring approaches
- [OpenTelemetry Setup Guide](../opentelemetry-setup-guide/) — OTel as an alternative
- [Structured Logging Complete](../structured-logging-complete/) — correlate metrics with logs
- [Flow Profiling Methodology](../flow-profiling-methodology/) — use metrics for profiling
