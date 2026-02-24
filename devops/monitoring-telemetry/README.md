# Monitoring & Direct Telemetry Stream

> Export MuleSoft traces and logs to Grafana, Splunk, Datadog, or New Relic via OpenTelemetry.

## Overview

MuleSoft provides two monitoring paths:

| Path | Mechanism | Data | Tier |
|------|-----------|------|------|
| **Anypoint Monitoring** | Built-in dashboards in Runtime Manager | Metrics + logs + traces | Starter+ |
| **Direct Telemetry Stream (DTS)** | OTLP export from Mule runtime to your observability stack | Traces + logs | Advanced/Titanium |

DTS (GA in Mule 4.11.0) streams OpenTelemetry-formatted telemetry directly from the runtime — no intermediate storage in Anypoint Platform.

## Prerequisites

- Mule Runtime **4.11.0+** (for DTS)
- HTTP Connector **1.8+** (for W3C Trace Context propagation)
- **Advanced or Titanium** Anypoint subscription
- An OTLP-compatible collector or observability backend

## Direct Telemetry Stream Configuration

DTS is configured via **protected application properties** in Runtime Manager — no code changes needed.

### Core Properties

```properties
# --- Traces ---
mule.openTelemetry.tracer.exporter.enabled=true
mule.openTelemetry.tracer.exporter.endpoint=https://your-collector:4318/v1/traces
mule.openTelemetry.tracer.exporter.type=HTTP

# Sampling strategies: always_on | always_off | traceidratio | parentbased_traceidratio
mule.openTelemetry.tracer.exporter.sampler=parentbased_traceidratio
mule.openTelemetry.tracer.exporter.sampler.arg=0.1

# Backpressure: DROP (default, silently discards) | BLOCK (lossless, adds latency)
mule.openTelemetry.tracer.exporter.backpressure.strategy=DROP

# --- Logs ---
mule.openTelemetry.logging.exporter.enabled=true
mule.openTelemetry.logging.exporter.endpoint=https://your-collector:4318/v1/logs
mule.openTelemetry.logging.exporter.backpressure.strategy=BLOCK
```

### Tracing Levels

| Level | What Gets Spanned |
|-------|-------------------|
| `OVERVIEW` | Flow-level spans only |
| `MONITORING` | Flow + component spans (default) |
| `DEBUG` | Flow + component + internal execution spans |

### Batch and Queue Tuning

```properties
# Queue capacity
mule.openTelemetry.tracer.exporter.queue.size=2048

# Max items per export batch
mule.openTelemetry.tracer.exporter.batch.max.size=512

# Export interval (ms)
mule.openTelemetry.tracer.exporter.batch.delay=5000

# Per-batch timeout (ms)
mule.openTelemetry.tracer.exporter.timeout=10000
```

### TLS Configuration

```properties
mule.openTelemetry.exporter.tls.enabled=true
mule.openTelemetry.exporter.tls.certificatesStrategy=CERTIFICATES_PATH
mule.openTelemetry.exporter.tls.server.cert=/path/to/server.pem

# For mTLS
mule.openTelemetry.exporter.tls.client.cert=/path/to/client.pem
mule.openTelemetry.exporter.tls.client.key=/path/to/client-key.pem
```

## Destination: Grafana Cloud

Grafana accepts OTLP directly. Get your endpoint and credentials from **Grafana Cloud > Manage > OpenTelemetry**.

```properties
mule.openTelemetry.tracer.exporter.enabled=true
mule.openTelemetry.tracer.exporter.type=HTTP
mule.openTelemetry.tracer.exporter.endpoint=https://otlp-gateway-prod-us-central-0.grafana.net/otlp/v1/traces
mule.openTelemetry.tracer.exporter.headers.Authorization=Basic <base64(instanceId:apiToken)>

mule.openTelemetry.logging.exporter.enabled=true
mule.openTelemetry.logging.exporter.endpoint=https://otlp-gateway-prod-us-central-0.grafana.net/otlp/v1/logs
mule.openTelemetry.logging.exporter.headers.Authorization=Basic <base64(instanceId:apiToken)>
```

Traces appear in **Explore > Tempo**. Logs in **Explore > Loki**.

## Destination: New Relic

New Relic accepts OTLP directly without a collector:

```properties
mule.openTelemetry.tracer.exporter.enabled=true
mule.openTelemetry.tracer.exporter.type=HTTP
mule.openTelemetry.tracer.exporter.endpoint=https://otlp.nr-data.net:4318/v1/traces
mule.openTelemetry.tracer.exporter.headers.api-key=YOUR_LICENSE_KEY

mule.openTelemetry.logging.exporter.enabled=true
mule.openTelemetry.logging.exporter.endpoint=https://otlp.nr-data.net:4318/v1/logs
mule.openTelemetry.logging.exporter.headers.api-key=YOUR_LICENSE_KEY
```

EU region: use `https://otlp.eu01.nr-data.net:4318`.

## Destination: Datadog

Datadog requires a local collector with OTLP ingestion enabled.

### Datadog Agent Config (`datadog.yaml`)

```yaml
otlp_config:
  receiver:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

### Mule Properties

```properties
mule.openTelemetry.tracer.exporter.enabled=true
mule.openTelemetry.tracer.exporter.type=GRPC
mule.openTelemetry.tracer.exporter.endpoint=http://dd-agent-host:4317

mule.openTelemetry.logging.exporter.enabled=true
mule.openTelemetry.logging.exporter.endpoint=http://dd-agent-host:4317
```

## Destination: Splunk

Use the Splunk OpenTelemetry Collector as an intermediary.

### Splunk OTel Collector Config

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  splunk_hec:
    token: "YOUR_HEC_TOKEN"
    endpoint: "https://splunk-host:8088/services/collector"
    source: "mulesoft"
    sourcetype: "mule:trace"
    index: "mule_observability"

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [splunk_hec]
    logs:
      receivers: [otlp]
      exporters: [splunk_hec]
```

### Mule Properties

```properties
mule.openTelemetry.tracer.exporter.enabled=true
mule.openTelemetry.tracer.exporter.type=GRPC
mule.openTelemetry.tracer.exporter.endpoint=http://splunk-otel-collector:4317

mule.openTelemetry.logging.exporter.enabled=true
mule.openTelemetry.logging.exporter.endpoint=http://splunk-otel-collector:4317
```

## Anypoint Monitoring Built-in Dashboards

Available at all tiers (metrics scope varies):

| Dashboard | Key Metrics |
|-----------|-------------|
| **Overview** | Message count, avg response time, error count, CPU %, heap |
| **Inbound** | Requests by status, response time percentiles (p50/p75/p90/p99) |
| **Outbound** | Outgoing connector call metrics |
| **Flows** | Per-flow response times, volumes, failures (Advanced+) |
| **Connectors** | Per-operation metrics for Salesforce, DB, HTTP, etc. (Advanced+, Hybrid) |
| **JVM** | GC metrics, heap breakdown, thread count |
| **Infrastructure** | CPU, memory, swap, processor count |

### Response Time Color Codes

| Color | Average | Maximum |
|-------|---------|---------|
| Green | < 300ms | < 300ms |
| Yellow | 300–600ms | 300–500ms |
| Red | ≥ 600ms | ≥ 500ms |

### Data Retention

| Tier | Metrics | Logs |
|------|---------|------|
| Starter | 30 days | — |
| Advanced | 365 days | 5 GB archival + 0.5 GB searchable/flow |
| Titanium | 365 days | 200 GB archival + 20 GB searchable/vCore |

## Distributed Tracing

Available for **CloudHub 2.0** and **Runtime Fabric** only (US and EU regions).

Enable in Runtime Manager: **Settings > Monitoring > Distributed Tracing > Enable**

Features:
- End-to-end request visualization across Mule flows
- Root cause path identification
- Trace ID and Span ID injected into logs for correlation
- W3C Trace Context headers (`traceparent`, `tracestate`) auto-propagated

## Context Propagation

HTTP Connector 1.8+ automatically injects/extracts W3C Trace Context headers. Trace context is available in flow variables:

```
#[vars.OTEL_TRACE_CONTEXT.traceId]
#[vars.OTEL_TRACE_CONTEXT.spanId]
#[vars.OTEL_TRACE_CONTEXT.traceparent]
```

Anypoint MQ also supports trace context extraction from message properties.

## Common Gotchas

- **DTS exports traces and logs only** — metrics are not yet available via OTLP
- **Mule 4.11.0+ required** — older runtimes don't support native DTS
- **Advanced/Titanium tier required** — Starter tier cannot use DTS or Telemetry Exporter
- **Distributed Tracing limited to US/EU** — not available in Canada, Japan, GovCloud, or PCE
- **Only async Log4j appenders** — file appenders are stripped in CloudHub 2.0
- **Sampling is critical for production** — `always_on` can generate massive trace volumes; use `parentbased_traceidratio` with a ratio like 0.05–0.1

## References

- [Direct Telemetry Stream](https://blogs.mulesoft.com/news/direct-telemetry-stream-from-mule-runtime/)
- [OpenTelemetry Support in Mule](https://docs.mulesoft.com/mule-runtime/latest/otel-support)
- [Telemetry Exporter](https://docs.mulesoft.com/monitoring/telemetry-exporter)
- [Anypoint Monitoring](https://docs.mulesoft.com/monitoring/)
- [Built-in Dashboards](https://docs.mulesoft.com/monitoring/app-dashboards)
- [Performance and Data Retention](https://docs.mulesoft.com/monitoring/performance-and-impact)
- [AVIO OpenTelemetry Module](https://avioconsulting.github.io/mule-opentelemetry-module/)
