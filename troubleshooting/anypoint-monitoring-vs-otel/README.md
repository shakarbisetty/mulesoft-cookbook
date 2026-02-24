## Anypoint Monitoring vs OpenTelemetry
> Capability comparison and OTLP setup for exporting Mule telemetry to Grafana, Datadog, or Splunk

### When to Use
- Evaluating whether Anypoint Monitoring meets your observability needs
- Planning to integrate Mule metrics into an existing Grafana/Datadog/Splunk stack
- Need distributed tracing across Mule and non-Mule services
- Building a business case for Titanium subscription vs. OpenTelemetry setup
- Troubleshooting monitoring gaps — "Why can't I see X metric?"

### Diagnosis Steps

#### Step 1: Understand What You Have vs. What You Need

**Capability Comparison Table:**

| Capability | Anypoint Monitoring (Base) | Anypoint Monitoring (Titanium) | OpenTelemetry (OTLP) |
|-----------|---------------------------|-------------------------------|----------------------|
| **Basic Metrics** (CPU, memory, thread count) | Yes | Yes | Yes |
| **API Analytics** (request count, latency, errors) | Yes | Yes | Yes |
| **Custom Dashboards** | No | Yes | Yes |
| **Custom Metrics** (business KPIs) | No | Yes | Yes |
| **Application Performance Monitoring (APM)** | No | Yes | Yes |
| **Distributed Tracing** | No | Yes (limited to Mule-to-Mule) | Yes (any service) |
| **Log Correlation** (trace ID in logs) | No | Yes | Yes |
| **Custom Alerts** | Basic (CPU/memory thresholds) | Advanced (any metric, composite conditions) | Yes (via backend) |
| **Retention** | 30 days | 30 days (90 for Titanium) | Unlimited (your storage) |
| **Cross-Platform Tracing** (Mule + Spring + Node) | No | No | Yes |
| **Backend Freedom** (Grafana, Datadog, Splunk, etc.) | No (Anypoint UI only) | No (Anypoint UI only) | Yes |
| **Cost** | Included | ~$300-500/vCore/year additional | Infrastructure cost only |

#### Step 2: Set Up Anypoint Monitoring (If Using It)

**Enable on CloudHub:**
1. Runtime Manager → Application → Settings
2. Toggle "Enable Monitoring" to ON
3. For Titanium: toggle "Enable Performance Monitoring" and "Enable Distributed Tracing"

**Verify it's working:**
```bash
# Check the monitoring agent is running
anypoint-cli runtime-mgr:cloudhub2:application:describe <app-name>
# Look for monitoringEnabled: true in the output
```

**Custom metrics (Titanium only) — in your Mule flow:**
```xml
<!-- Emit a custom metric -->
<custom-metrics:send doc:name="Order Processed">
    <custom-metrics:facts>
        <custom-metrics:fact factName="order_total" value="#[vars.orderTotal]" />
        <custom-metrics:fact factName="item_count" value="#[vars.itemCount]" />
    </custom-metrics:facts>
    <custom-metrics:dimensions>
        <custom-metrics:dimension dimensionName="region" value="#[vars.region]" />
        <custom-metrics:dimension dimensionName="order_type" value="#[vars.orderType]" />
    </custom-metrics:dimensions>
</custom-metrics:send>
```

#### Step 3: Set Up OpenTelemetry Export (OTLP)

**Architecture:**
```
Mule Runtime → Mule Agent → OpenTelemetry Collector → Your Backend
                (OTLP)           (processes/batches)    (Grafana/Datadog/Splunk)
```

**Step 3a: Deploy an OpenTelemetry Collector**

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

exporters:
  # Option A: Grafana (via Prometheus + Tempo)
  prometheus:
    endpoint: 0.0.0.0:8889
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Option B: Datadog
  datadog:
    api:
      key: ${DD_API_KEY}
      site: datadoghq.com

  # Option C: Splunk
  splunk_hec:
    token: ${SPLUNK_HEC_TOKEN}
    endpoint: https://splunk-hec.example.com:8088/services/collector

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo]  # or [datadog] or [splunk_hec]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]  # or [datadog] or [splunk_hec]
```

**Step 3b: Configure Mule Runtime Agent for OTLP**

**On-Prem Mule Runtime (4.6.0+):**

Edit `$MULE_HOME/conf/mule-agent.yml`:
```yaml
services:
  mule.agent.tracking.service:
    enabled: true
  mule.agent.opentelemetry.service:
    enabled: true
    config:
      endpoint: http://otel-collector.example.com:4317
      protocol: grpc
      compression: gzip
      headers:
        Authorization: "Bearer ${OTEL_TOKEN}"
      resource_attributes:
        service.name: my-mule-app
        deployment.environment: production
      sampling:
        type: parentbased_traceidratio
        ratio: 0.1  # Sample 10% of traces
```

**On CloudHub 2.0:**

Set the following properties in your deployment configuration:
```properties
# Runtime Manager → Application → Properties
anypoint.platform.config.analytics.agent.enabled=true
otel.exporter.otlp.endpoint=http://otel-collector.internal:4317
otel.exporter.otlp.protocol=grpc
otel.resource.attributes=service.name=my-mule-app,deployment.environment=production
otel.traces.sampler=parentbased_traceidratio
otel.traces.sampler.arg=0.1
```

#### Step 4: Verify Telemetry is Flowing

```bash
# Check OTel Collector is receiving data
curl http://otel-collector:8888/metrics | grep otelcol_receiver_accepted

# Expected output:
# otelcol_receiver_accepted_spans{receiver="otlp"} 1523
# otelcol_receiver_accepted_metric_points{receiver="otlp"} 8901

# Check for export errors
curl http://otel-collector:8888/metrics | grep otelcol_exporter_send_failed
```

#### Step 5: Create Useful Dashboards

**Key metrics to dashboard (regardless of backend):**

| Metric | What It Tells You | Alert Threshold |
|--------|------------------|-----------------|
| `mule.app.request.count` | Traffic volume | Sudden drop >50% = outage |
| `mule.app.request.duration.p99` | Worst-case latency | >5s for sync APIs |
| `mule.app.error.count` | Error rate | >5% of total requests |
| `jvm.memory.heap.used` | Memory usage | >85% for >5 minutes |
| `jvm.threads.count` | Thread usage | Sudden spike or hitting max |
| `db.connection.pool.active` | DB pool usage | >80% of max pool size |
| `http.client.request.duration` | Downstream API latency | >3s (your SLA depends on theirs) |

### How It Works
1. The Mule runtime agent collects metrics, traces, and logs from the running application
2. With Anypoint Monitoring, this data goes to MuleSoft's backend and is shown in the Anypoint Platform UI
3. With OTLP, the agent exports the same data in OpenTelemetry format to an OTel Collector
4. The Collector receives, processes (batches, filters, enriches), and exports to your chosen backend
5. Distributed tracing works by propagating `traceparent` headers (W3C Trace Context) across HTTP calls

### Gotchas
- **Titanium subscription is required for APM** — without it, Anypoint Monitoring only gives you basic CPU/memory charts and basic API analytics. No custom dashboards, no distributed tracing, no custom metrics.
- **OTLP is NOT supported on CloudHub 1.0** — only CloudHub 2.0 and Runtime Fabric support the OTel agent. If you're on CH1, you're limited to Anypoint Monitoring or custom logging.
- **Sampling is critical for cost control** — sending 100% of traces to Datadog or Splunk can cost thousands per month. Start with 10% sampling (`ratio: 0.1`) and increase only if needed.
- **OTel Collector is a SPOF** — if it goes down, you lose telemetry. Deploy at least 2 replicas with a load balancer.
- **Mule runtime version matters** — native OTLP support started in Mule 4.6.0. Earlier versions require custom Java agent instrumentation.
- **Clock synchronization** — distributed tracing requires NTP-synced clocks across all services. Even 1-second drift will make trace timelines nonsensical.
- **Don't export from Anypoint AND OTel simultaneously** — this doubles the telemetry overhead on the runtime. Pick one path.
- **Log correlation requires trace ID injection** — add `%X{traceId}` to your log4j2 pattern to embed trace IDs in log lines for correlation.

### Related
- [Thread Dump Analysis](../thread-dump-analysis/) — when monitoring shows high CPU but you need to know which threads
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — setting up pool monitoring
- [CloudHub vCore Sizing](../../performance/cloudhub/vcore-sizing-matrix/) — monitoring helps right-size your vCores
- [CloudHub 2.0 HPA Autoscaling](../../performance/cloudhub/ch2-hpa-autoscaling/) — autoscaling based on metrics
