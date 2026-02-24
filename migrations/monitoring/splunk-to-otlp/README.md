## Splunk HEC to OTLP Exporter
> Migrate from Splunk HTTP Event Collector to OpenTelemetry Protocol for log/metrics export

### When to Use
- Moving from Splunk to Grafana/Loki/Datadog/other backends
- Standardizing on OpenTelemetry for all telemetry data
- Reducing vendor lock-in for log aggregation
- Need unified traces + metrics + logs pipeline

### Configuration / Code

#### 1. Before: Splunk HEC Appender

```xml
<!-- log4j2.xml with Splunk HEC -->
<Appenders>
    <Http name="Splunk" url="https://splunk.example.com:8088/services/collector">
        <Property name="Authorization" value="Splunk ${sys:splunk.token}" />
        <JsonLayout>
            <KeyValuePair key="sourcetype" value="mule:app" />
            <KeyValuePair key="index" value="mule_logs" />
        </JsonLayout>
    </Http>
</Appenders>
```

#### 2. After: OTLP Log Exporter via OTel Collector

```yaml
# otel-collector-config.yaml
receivers:
  filelog:
    include: [/opt/mule/logs/*.log]
    operators:
      - type: regex_parser
        regex: '(?P<severity>\w+)\s+(?P<timestamp>\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2},\d{3})\s\[(?P<thread>[^\]]+)\]\s(?P<logger>[^:]+):\s(?P<message>.*)'
      - type: severity_parser
        parse_from: attributes.severity

  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  loki:
    endpoint: https://loki.example.com/loki/api/v1/push
    labels:
      attributes:
        app: ""
        env: ""
  otlphttp:
    endpoint: https://otlp-gateway.example.com

service:
  pipelines:
    logs:
      receivers: [filelog, otlp]
      exporters: [loki, otlphttp]
```

#### 3. Mule Log4j2 with OTLP Appender

```xml
<Configuration>
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <JsonLayout compact="true" eventEol="true">
                <KeyValuePair key="trace_id" value="$${ctx:traceId}" />
                <KeyValuePair key="span_id" value="$${ctx:spanId}" />
                <KeyValuePair key="service" value="${sys:mule.app.name}" />
            </JsonLayout>
        </Console>
    </Appenders>
    <Loggers>
        <AsyncRoot level="INFO">
            <AppenderRef ref="Console" />
        </AsyncRoot>
    </Loggers>
</Configuration>
```

### How It Works
1. OTel Collector replaces Splunk HEC as the log ingestion point
2. File log receiver parses Mule log files directly
3. OTLP receiver accepts logs from OTel-instrumented applications
4. Logs can be exported to any OTel-compatible backend

### Migration Checklist
- [ ] Deploy OTel Collector alongside Mule runtime
- [ ] Configure filelog receiver for Mule log format
- [ ] Update log4j2.xml for JSON structured output
- [ ] Configure exporters for target backend
- [ ] Verify logs appear in new backend
- [ ] Migrate Splunk dashboards and alerts
- [ ] Remove Splunk HEC configuration
- [ ] Verify trace ID correlation in logs

### Gotchas
- Splunk SPL queries do not translate to PromQL/LogQL
- Dashboard migration is manual
- Custom Splunk add-ons have no OTel equivalent
- Log volume may differ due to parsing differences
- Ensure OTel Collector has sufficient resources

### Related
- [anypoint-to-otel](../anypoint-to-otel/) - Full OTel migration
- [log4j1-to-log4j2](../log4j1-to-log4j2/) - Logging framework
