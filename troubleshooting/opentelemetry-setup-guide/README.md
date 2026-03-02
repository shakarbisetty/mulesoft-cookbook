## OpenTelemetry Setup Guide
> Complete OTel setup for Mule 4 with Datadog, Grafana, and Splunk backends

### When to Use
- Need distributed tracing across multiple Mule applications
- Anypoint Monitoring lacks the features or retention your team needs
- Standardizing on OpenTelemetry across your organization
- Need to correlate Mule traces with non-Mule services (Node.js, Java, Python)
- Want to export metrics and traces to Datadog, Grafana Cloud, or Splunk

### The Problem

Anypoint Monitoring provides built-in observability but is tied to the MuleSoft ecosystem. Organizations using multi-vendor stacks need a unified observability platform. OpenTelemetry (OTel) is the CNCF standard, but setting it up with Mule 4 requires configuring the Java agent, managing propagation context, and routing telemetry to your backend — none of which is well documented.

### Architecture Overview

```
+------------------+     OTLP/gRPC      +------------------+     Export      +------------------+
|   Mule Runtime   | -----------------> | OTel Collector   | -------------> | Backend          |
|   + OTel Agent   |     (port 4317)    | (optional)       |                | Datadog/Grafana/ |
|                  |                     |                  |                | Splunk/Jaeger    |
+------------------+                     +------------------+                +------------------+
       |                                        |
  Traces, Metrics,                        Transform, Filter,
  Logs (auto-instrumented)                Route, Sample
```

### Option A: Direct Export (No Collector)

Simplest setup — the OTel Java agent exports directly to your backend.

#### Step 1: Download the OTel Java Agent

```bash
# Download the latest OpenTelemetry Java agent
curl -L -o opentelemetry-javaagent.jar \
  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Verify the download
ls -la opentelemetry-javaagent.jar
# Should be ~30 MB
```

#### Step 2: Configure JVM Arguments

**For CloudHub 1.0 — add to Runtime Manager > Settings > JVM Args:**
```
-javaagent:/opt/mule/lib/opentelemetry-javaagent.jar
-Dotel.service.name=my-mule-app
-Dotel.exporter.otlp.endpoint=https://otel-collector.example.com:4317
-Dotel.exporter.otlp.protocol=grpc
-Dotel.resource.attributes=deployment.environment=production,service.version=1.0.0
-Dotel.traces.sampler=parentbased_traceidratio
-Dotel.traces.sampler.arg=0.1
```

**For CloudHub 2.0 — in the deployment properties:**
```yaml
# In your application's mule-artifact.json or deployment config
jvmArgs:
  - "-javaagent:/opt/mule/lib/opentelemetry-javaagent.jar"
  - "-Dotel.service.name=my-mule-app"
  - "-Dotel.exporter.otlp.endpoint=https://otel-collector.example.com:4317"
```

**For on-prem — in wrapper.conf:**
```properties
# Add to $MULE_HOME/conf/wrapper.conf
wrapper.java.additional.100=-javaagent:%MULE_HOME%/lib/boot/opentelemetry-javaagent.jar
wrapper.java.additional.101=-Dotel.service.name=my-mule-app
wrapper.java.additional.102=-Dotel.exporter.otlp.endpoint=http://localhost:4317
wrapper.java.additional.103=-Dotel.exporter.otlp.protocol=grpc
```

#### Step 3: Place the Agent JAR

**CloudHub:** Upload the JAR as part of your application package.
```
src/
  main/
    mule/
    resources/
  lib/
    opentelemetry-javaagent.jar    <-- place here
```

**On-prem:**
```bash
cp opentelemetry-javaagent.jar $MULE_HOME/lib/boot/
```

### Option B: Via OTel Collector (Recommended for Production)

The collector provides buffering, retry, sampling, and multi-backend routing.

#### Step 1: Deploy the OTel Collector

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
    timeout: 5s
    send_batch_size: 1024

  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  attributes:
    actions:
      - key: environment
        value: production
        action: upsert

  filter:
    traces:
      span:
        # Drop health check traces to reduce noise
        - 'attributes["http.target"] == "/health"'
        - 'attributes["http.target"] == "/ready"'

exporters:
  # Choose your backend(s) below

  # Option: Datadog
  datadog:
    api:
      key: ${DD_API_KEY}
      site: datadoghq.com

  # Option: Grafana Cloud (Tempo for traces, Prometheus for metrics)
  otlp/grafana:
    endpoint: tempo-us-central1.grafana.net:443
    headers:
      Authorization: "Basic ${GRAFANA_CLOUD_TOKEN}"

  # Option: Splunk
  splunk_hec:
    token: ${SPLUNK_HEC_TOKEN}
    endpoint: https://splunk.example.com:8088/services/collector
    source: mule-runtime

  # Option: Jaeger (self-hosted)
  otlp/jaeger:
    endpoint: jaeger-collector:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, attributes, filter]
      exporters: [datadog]  # Change to your backend
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [datadog]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [datadog]
```

#### Step 2: Run the Collector

```bash
# Docker
docker run -d --name otel-collector \
  -p 4317:4317 -p 4318:4318 \
  -v $(pwd)/otel-collector-config.yaml:/etc/otelcol/config.yaml \
  -e DD_API_KEY="${DD_API_KEY}" \
  otel/opentelemetry-collector-contrib:latest

# Kubernetes
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
spec:
  replicas: 2
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: collector
        image: otel/opentelemetry-collector-contrib:latest
        ports:
        - containerPort: 4317
        - containerPort: 4318
        volumeMounts:
        - name: config
          mountPath: /etc/otelcol/config.yaml
          subPath: config.yaml
      volumes:
      - name: config
        configMap:
          name: otel-collector-config
EOF
```

### Backend-Specific Configuration

#### Datadog Setup

```bash
# Set environment variables for the OTel agent
-Dotel.exporter.otlp.endpoint=https://otel-collector:4317
# Or send directly to Datadog:
-Dotel.exporter.otlp.endpoint=https://trace.agent.datadoghq.com:443
-Dotel.exporter.otlp.headers=DD-API-KEY=${DD_API_KEY}
```

#### Grafana Cloud Setup (Tempo + Prometheus + Loki)

```bash
# Traces -> Tempo
-Dotel.exporter.otlp.endpoint=https://tempo-us-central1.grafana.net:443
-Dotel.exporter.otlp.headers=Authorization=Basic%20${GRAFANA_TOKEN}

# Metrics -> Prometheus-compatible endpoint
# Configured in collector, not in agent
```

#### Splunk Setup

```bash
# Via HEC (HTTP Event Collector)
-Dotel.exporter.otlp.endpoint=https://splunk.example.com:4317
# Or use the Splunk distribution of the OTel Collector
```

### Context Propagation Between Mule Apps

For distributed tracing to work across multiple Mule applications, trace context must propagate via HTTP headers.

The OTel Java agent automatically injects and extracts `traceparent` and `tracestate` headers (W3C Trace Context format). No additional configuration is needed for HTTP-based communication.

**For non-HTTP communication (JMS, Anypoint MQ):**
```xml
<!-- Manually propagate trace context via message properties -->
<set-variable variableName="traceparent"
    value="#[attributes.headers.'traceparent' default '']"/>

<!-- When publishing to queue, include the header -->
<anypoint-mq:publish config-ref="MQ" destination="orders-queue">
    <anypoint-mq:properties>
        <anypoint-mq:property key="traceparent" value="#[vars.traceparent]"/>
    </anypoint-mq:properties>
</anypoint-mq:publish>
```

### Sampling Configuration

```bash
# Always sample (development only — high overhead)
-Dotel.traces.sampler=always_on

# Sample 10% of traces (production)
-Dotel.traces.sampler=parentbased_traceidratio
-Dotel.traces.sampler.arg=0.1

# Sample only errors (cost-effective)
# Configure in collector with tail-based sampling:
```

```yaml
# Collector config for tail-based sampling
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-only
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: slow-requests
        type: latency
        latency:
          threshold_ms: 5000
      - name: baseline
        type: probabilistic
        probabilistic:
          sampling_percentage: 5
```

### Verifying the Setup

```bash
# 1. Check that the agent loaded
grep "opentelemetry" mule_ee.log | head -5
# Should see: "[otel.javaagent] ... OpenTelemetry Javaagent enabled"

# 2. Send a test request
curl -v http://localhost:8081/api/test

# 3. Check collector is receiving data (if using collector)
curl http://localhost:8888/metrics | grep otelcol_receiver_accepted_spans

# 4. Check your backend for traces
# Datadog: APM > Traces > search for service:my-mule-app
# Grafana: Explore > Tempo > search by service name
# Splunk: Search > index=otel sourcetype=otel:traces
```

### Gotchas
- **OTel agent adds ~5-10% overhead** — the Java agent instruments bytecode at startup and adds small latency to each operation. In high-throughput applications (10,000+ TPS), this is measurable.
- **Agent version compatibility** — not all OTel agent versions work with all Mule runtime versions. Test in staging before deploying to production. Java 17+ runtime requires OTel agent 1.20+.
- **CloudHub 1.0 has limited JVM arg space** — there's a character limit on JVM arguments in Runtime Manager. Use a properties file (`otel.properties`) and reference it with `-Dotel.javaagent.configuration-file=/opt/mule/conf/otel.properties`.
- **Anypoint Monitoring and OTel can coexist** — they use different instrumentation mechanisms. Running both increases overhead but doesn't cause conflicts.
- **gRPC export requires port 4317 outbound** — CloudHub workers must be able to reach your collector on this port. Check VPC firewall rules.
- **Trace IDs in logs require MDC integration** — the OTel agent injects trace_id and span_id into MDC, but Mule's default Log4j2 config doesn't include them. Update `log4j2.xml` to include `%X{trace_id}`.
- **Large payloads in span attributes** — by default, the agent captures HTTP request/response bodies as span attributes. For large payloads, this creates massive spans. Disable with `-Dotel.instrumentation.http.capture-headers.server.request=` (empty value).

### Related
- [Anypoint Monitoring vs OTel](../anypoint-monitoring-vs-otel/) — capability comparison
- [Structured Logging Complete](../structured-logging-complete/) — correlate logs with traces
- [Anypoint Monitoring Custom Metrics](../anypoint-monitoring-custom-metrics/) — the Anypoint-native approach
- [Flow Profiling Methodology](../flow-profiling-methodology/) — use traces for profiling
