## OpenTelemetry Telemetry Export
> Export Mule runtime metrics and traces to external observability platforms via OTLP.

### When to Use
- Consolidating MuleSoft monitoring with other systems in Datadog, Grafana, or Splunk
- Distributed tracing across Mule flows and non-Mule services
- Custom retention and analysis beyond Anypoint Monitoring capabilities

### Configuration / Code

**Mule 4 OTLP exporter configuration (mule-artifact.json):**
```json
{
  "configs": {
    "opentelemetry": {
      "endpoint": "http://otel-collector:4317",
      "protocol": "grpc",
      "exportInterval": 30000,
      "resourceAttributes": {
        "service.name": "orders-api",
        "deployment.environment": "${mule.env}"
      }
    }
  }
}
```

**OpenTelemetry Collector config (otel-collector.yaml):**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  datadog:
    api:
      key: "${DD_API_KEY}"
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [datadog]
    metrics:
      receivers: [otlp]
      exporters: [prometheus]
```

### How It Works
1. Mule runtime exports traces and metrics via OTLP (gRPC or HTTP)
2. OpenTelemetry Collector receives, processes, and exports to backends
3. Traces include flow execution, connector calls, and error details
4. Metrics include request count, latency, and custom business metrics

### Gotchas
- OTLP export adds ~1-2% overhead — acceptable for production
- Trace sampling may be needed for high-throughput APIs (head or tail sampling)
- Collector is the recommended deployment (not direct-to-backend)
- CloudHub 2.0 supports OTLP natively; CloudHub 1.0 requires a sidecar agent

### Related
- [Custom Metrics Connector](../custom-metrics-connector/) — Anypoint-native metrics
- [Distributed Tracing](../../../performance/monitoring/distributed-tracing-bottlenecks/) — tracing patterns
