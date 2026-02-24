## Log Aggregation
> Structured JSON logging with ELK, Splunk, or Loki integration

### When to Use
- You need centralized logging across multiple Mule applications
- You want structured (JSON) logs for better search and analysis
- You need to correlate logs with traces using trace IDs

### Configuration

**src/main/resources/log4j2.xml — structured JSON logging**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Properties>
        <Property name="APP_NAME">${sys:app.name:-mule-app}</Property>
        <Property name="ENV">${sys:env:-dev}</Property>
    </Properties>

    <Appenders>
        <!-- Console appender with JSON layout -->
        <Console name="Console" target="SYSTEM_OUT">
            <JsonLayout compact="true" eventEol="true"
                        properties="true" stacktraceAsString="true">
                <KeyValuePair key="app" value="${APP_NAME}" />
                <KeyValuePair key="environment" value="${ENV}" />
                <KeyValuePair key="timestamp" value="$${date:yyyy-MM-dd'T'HH:mm:ss.SSSZ}" />
            </JsonLayout>
        </Console>

        <!-- File appender for local development -->
        <RollingFile name="File"
            fileName="logs/${APP_NAME}.log"
            filePattern="logs/${APP_NAME}-%d{yyyy-MM-dd}-%i.log.gz">
            <JsonLayout compact="true" eventEol="true" properties="true" />
            <Policies>
                <SizeBasedTriggeringPolicy size="100MB" />
                <TimeBasedTriggeringPolicy interval="1" />
            </Policies>
            <DefaultRolloverStrategy max="7" />
        </RollingFile>

        <!-- Async wrapper for performance -->
        <Async name="AsyncConsole">
            <AppenderRef ref="Console" />
        </Async>
    </Appenders>

    <Loggers>
        <!-- Application logger -->
        <Logger name="com.example" level="INFO" additivity="false">
            <AppenderRef ref="AsyncConsole" />
            <AppenderRef ref="File" />
        </Logger>

        <!-- Mule runtime (reduce noise) -->
        <Logger name="org.mule" level="WARN" />
        <Logger name="org.mule.runtime.core.internal.processor" level="WARN" />
        <Logger name="com.mulesoft" level="WARN" />

        <!-- HTTP wire logging (DEBUG only) -->
        <Logger name="org.mule.service.http" level="WARN" />

        <Root level="INFO">
            <AppenderRef ref="AsyncConsole" />
        </Root>
    </Loggers>
</Configuration>
```

**Structured logging in Mule flows**
```xml
<flow name="order-process-flow">
    <!-- Set correlation ID for log correlation -->
    <set-variable variableName="correlationId"
        value="#[attributes.headers.'x-correlation-id' default correlationId]" />

    <logger message='#[output application/json ---
        {
            "event": "order.received",
            "correlationId": vars.correlationId,
            "orderId": payload.orderId,
            "customerId": payload.customerId,
            "amount": payload.totalAmount
        }
    ]' level="INFO" doc:name="Log Order Received" />

    <!-- Process order -->
    <flow-ref name="validate-order-flow" />

    <logger message='#[output application/json ---
        {
            "event": "order.processed",
            "correlationId": vars.correlationId,
            "orderId": payload.orderId,
            "processingTimeMs": (now() - vars.startTime) as Number {unit: "milliseconds"}
        }
    ]' level="INFO" doc:name="Log Order Processed" />

    <error-handler>
        <on-error-continue>
            <logger message='#[output application/json ---
                {
                    "event": "order.failed",
                    "correlationId": vars.correlationId,
                    "orderId": payload.orderId default "unknown",
                    "errorType": error.errorType.identifier,
                    "errorMessage": error.description
                }
            ]' level="ERROR" doc:name="Log Order Failed" />
        </on-error-continue>
    </error-handler>
</flow>
```

**Filebeat config (ship logs to Elasticsearch)**
```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /opt/mule/logs/*.log
    json.keys_under_root: true
    json.add_error_key: true
    json.message_key: message
    fields:
      service: mulesoft
    fields_under_root: true

output.elasticsearch:
  hosts: ["https://elasticsearch:9200"]
  index: "mulesoft-logs-%{+yyyy.MM.dd}"
  username: "${ES_USER}"
  password: "${ES_PASSWORD}"

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
```

**Promtail config (ship logs to Loki)**
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: mulesoft
    static_configs:
      - targets: [localhost]
        labels:
          job: mulesoft
          __path__: /opt/mule/logs/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            app: app
            event: event
            correlationId: correlationId
      - labels:
          level:
          app:
          event:
```

### How It Works
1. Log4j2 JsonLayout outputs structured JSON logs with consistent fields
2. Correlation IDs from HTTP headers propagate through all log entries
3. Business events (order.received, order.processed) are logged as structured objects
4. Log shippers (Filebeat/Promtail) collect logs and send to the aggregation backend
5. Elasticsearch/Loki indexes logs for search; Kibana/Grafana provides visualization
6. Async appender prevents logging from blocking Mule flow execution

### Gotchas
- JSON logging increases log volume ~2x compared to plain text; plan storage accordingly
- Do not log sensitive data (passwords, tokens, PII) — sanitize payloads before logging
- CloudHub 2.0 logs are available via Runtime Manager and `anypoint-cli`; custom log shippers are for RTF/on-prem
- Async logging can lose messages on JVM crash; use sync for critical audit logs
- Log level changes require app restart unless you use Anypoint Monitoring dynamic log levels

### Related
- [distributed-tracing-otel](../distributed-tracing-otel/) — Trace-to-log correlation
- [custom-metrics-micrometer](../custom-metrics-micrometer/) — Metrics from log events
- [slo-sli-alerting](../slo-sli-alerting/) — Alert on log-derived metrics
