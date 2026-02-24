## Anypoint Monitoring to OpenTelemetry
> Migrate from Anypoint Monitoring to OpenTelemetry-based observability

### When to Use
- Consolidating monitoring to a vendor-neutral standard
- Need to correlate Mule metrics with non-Mule services
- Using Grafana, Datadog, New Relic, or other OTel-compatible backends
- Want distributed tracing across Mule and microservices

### Configuration / Code

#### 1. Add OpenTelemetry Agent

```properties
# wrapper.conf
wrapper.java.additional.70=-javaagent:/opt/mule/lib/opentelemetry-javaagent.jar
wrapper.java.additional.71=-Dotel.service.name=my-mule-api
wrapper.java.additional.72=-Dotel.exporter.otlp.endpoint=http://otel-collector:4317
wrapper.java.additional.73=-Dotel.exporter.otlp.protocol=grpc
wrapper.java.additional.74=-Dotel.traces.exporter=otlp
wrapper.java.additional.75=-Dotel.metrics.exporter=otlp
wrapper.java.additional.76=-Dotel.logs.exporter=otlp
wrapper.java.additional.77=-Dotel.resource.attributes=deployment.environment=production
```

#### 2. OTel Collector Configuration

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
    limit_mib: 512

exporters:
  otlp/grafana:
    endpoint: grafana-cloud:4317
    headers:
      Authorization: "Basic ${GRAFANA_TOKEN}"
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/grafana]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

#### 3. Custom Span in Mule Flow

```xml
<!-- Add trace context propagation -->
<http:request config-ref="HTTPS_Config"
    method="GET" path="/api/data">
    <http:headers>#[{
        'traceparent': vars.traceparent default ""
    }]</http:headers>
</http:request>
```

#### 4. Grafana Dashboard Query

```promql
# Request rate by API
rate(http_server_request_duration_seconds_count{service_name="my-mule-api"}[5m])

# P99 latency
histogram_quantile(0.99,
    rate(http_server_request_duration_seconds_bucket{service_name="my-mule-api"}[5m]))

# Error rate
rate(http_server_request_duration_seconds_count{http_status_code=~"5.."}[5m])
/ rate(http_server_request_duration_seconds_count[5m])
```

### How It Works
1. OTel Java agent auto-instruments HTTP, DB, and JMS operations
2. Traces, metrics, and logs are exported via OTLP protocol
3. OTel Collector receives, processes, and forwards to backends
4. Distributed tracing connects Mule flows with downstream services

### Migration Checklist
- [ ] Deploy OTel Collector infrastructure
- [ ] Add OTel Java agent to Mule runtime
- [ ] Configure OTLP exporter endpoints
- [ ] Verify traces appear in backend (Grafana, Datadog, etc.)
- [ ] Create dashboards for key metrics
- [ ] Set up alerts equivalent to Anypoint Monitoring
- [ ] Migrate existing alert rules
- [ ] Verify log correlation with trace IDs

### Gotchas
- OTel agent adds ~5-10% overhead — test performance impact
- CloudHub does not support custom Java agents; use RTF or on-prem
- Anypoint Monitoring built-in dashboards will not be available
- Some Mule-specific metrics may not be captured by generic OTel agent
- Trace context propagation requires header forwarding in HTTP requests

### Related
- [log4j1-to-log4j2](../log4j1-to-log4j2/) - Logging migration
- [splunk-to-otlp](../splunk-to-otlp/) - Splunk migration
- [custom-metrics-migration](../custom-metrics-migration/) - Metrics API
