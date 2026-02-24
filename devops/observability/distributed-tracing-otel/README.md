## Distributed Tracing with OpenTelemetry
> OTel tracing in Mule 4.11+ for end-to-end request visibility across services

### When to Use
- You need to trace requests across multiple Mule apps and external services
- You want to identify latency bottlenecks in distributed integration flows
- You need W3C Trace Context propagation for cross-service correlation

### Configuration

**pom.xml — OpenTelemetry agent dependency**
```xml
<!-- Mule 4.11+ has built-in OTel support -->
<dependency>
    <groupId>com.mulesoft.mule.distributions</groupId>
    <artifactId>mule-runtime-impl-bom</artifactId>
    <version>4.11.0</version>
    <type>pom</type>
    <scope>provided</scope>
</dependency>
```

**JVM arguments for OTel agent**
```properties
# wrapper.conf or Runtime Manager system properties
wrapper.java.additional.20=-javaagent:/opt/mule/lib/opentelemetry-javaagent.jar
wrapper.java.additional.21=-Dotel.service.name=order-api
wrapper.java.additional.22=-Dotel.traces.exporter=otlp
wrapper.java.additional.23=-Dotel.exporter.otlp.endpoint=http://otel-collector:4317
wrapper.java.additional.24=-Dotel.exporter.otlp.protocol=grpc
wrapper.java.additional.25=-Dotel.resource.attributes=service.namespace=mulesoft,deployment.environment=prod
wrapper.java.additional.26=-Dotel.traces.sampler=parentbased_traceidratio
wrapper.java.additional.27=-Dotel.traces.sampler.arg=0.1
```

**OpenTelemetry Collector config (otel-collector.yaml)**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000
    send_batch_max_size: 2000

  attributes:
    actions:
      - key: environment
        value: "${ENVIRONMENT}"
        action: upsert

  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-policy
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: latency-policy
        type: latency
        latency: {threshold_ms: 2000}
      - name: probabilistic-policy
        type: probabilistic
        probabilistic: {sampling_percentage: 10}

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  prometheus:
    endpoint: 0.0.0.0:8889
    namespace: mulesoft

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, attributes, tail_sampling]
      exporters: [otlp/jaeger, otlp/tempo]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

**W3C Trace Context propagation in Mule flows**
```xml
<!-- Propagate trace context to downstream HTTP calls -->
<flow name="order-process-flow">
    <!-- Incoming trace context is automatically extracted from headers -->

    <logger message='#["TraceID: " ++ attributes.headers."traceparent" default "none"]'
        level="DEBUG" />

    <!-- Downstream call automatically propagates traceparent header -->
    <http:request method="POST"
        config-ref="Inventory_API_Config"
        path="/api/v1/inventory/reserve">
        <!-- OTel agent automatically injects traceparent header -->
    </http:request>

    <!-- Add custom span attributes -->
    <set-variable variableName="otel.span.attributes"
        value='#[output application/java --- {
            "order.id": payload.orderId,
            "order.total": payload.totalAmount,
            "customer.tier": vars.customerTier
        }]' />
</flow>
```

**Docker Compose for local tracing stack**
```yaml
version: "3.9"
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.93.0
    ports:
      - "4317:4317"   # gRPC
      - "4318:4318"   # HTTP
      - "8889:8889"   # Prometheus metrics
    volumes:
      - ./otel-collector.yaml:/etc/otelcol-contrib/config.yaml

  jaeger:
    image: jaegertracing/all-in-one:1.53
    ports:
      - "16686:16686"  # Jaeger UI
      - "4317"         # OTLP gRPC

  grafana:
    image: grafana/grafana:10.3.1
    ports:
      - "3000:3000"
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
```

### How It Works
1. The OTel Java agent automatically instruments Mule runtime: HTTP listeners, requesters, DB operations
2. Traces are exported via OTLP (gRPC) to the OTel Collector for processing
3. The Collector applies tail sampling (keep errors, slow requests, and 10% of normal requests)
4. W3C `traceparent` headers propagate context across service boundaries
5. Jaeger/Tempo stores traces; Grafana provides visualization and trace-to-logs correlation
6. Custom span attributes enrich traces with business context (order ID, customer tier)

### Gotchas
- Mule 4.11+ has native OTel support; older versions need the generic Java agent (less Mule-aware)
- OTel agent adds ~5% overhead; use sampling to reduce production impact
- Tail sampling requires the Collector to buffer spans; size the Collector accordingly
- The `traceparent` header must be allowed through API policies (CORS, header forwarding)
- CloudHub 2.0 does not support custom Java agents; use Anypoint Monitoring instead (limited OTel)
- For on-prem/RTF, the agent JAR must be placed in the runtime's `lib/` directory

### Related
- [custom-metrics-micrometer](../custom-metrics-micrometer/) — Custom business metrics
- [log-aggregation](../log-aggregation/) — Structured logging with trace correlation
- [slo-sli-alerting](../slo-sli-alerting/) — SLOs based on trace data
