## Structured Logging Complete
> JSON logging, correlation IDs, MDC, and integration with CloudWatch, ELK, and Splunk

### When to Use
- Need machine-parseable logs instead of plain text
- Tracing a single request across multiple flows or applications
- Integrating Mule logs with a centralized logging platform (ELK, Splunk, CloudWatch)
- Debugging production issues and can't correlate log lines to specific requests
- Compliance requires audit trails with structured metadata

### The Problem

Default Mule logging produces unstructured text lines that are impossible to search at scale. When 50 concurrent requests flow through the same application, a single log line like "Processing order" tells you nothing about WHICH order, WHICH request, or WHICH user triggered it. Structured logging with correlation IDs solves this.

### Step 1: Enable JSON Logging (Log4j2 Configuration)

Replace the default `log4j2.xml` with JSON-formatted output.

**File: `src/main/resources/log4j2.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN" monitorInterval="60">

    <Properties>
        <Property name="APP_NAME">${sys:mule.app.name:-unknown}</Property>
        <Property name="ENV">${sys:mule.env:-local}</Property>
    </Properties>

    <Appenders>
        <!-- Console appender with JSON layout -->
        <Console name="Console" target="SYSTEM_OUT">
            <JsonLayout compact="true" eventEol="true"
                        properties="true" stacktraceAsString="true">
                <KeyValuePair key="app" value="${APP_NAME}"/>
                <KeyValuePair key="environment" value="${ENV}"/>
                <KeyValuePair key="correlationId" value="$${ctx:correlationId}"/>
                <KeyValuePair key="flowName" value="$${ctx:flowName}"/>
                <KeyValuePair key="traceId" value="$${ctx:trace_id}"/>
                <KeyValuePair key="spanId" value="$${ctx:span_id}"/>
            </JsonLayout>
        </Console>

        <!-- Rolling file for local/on-prem -->
        <RollingFile name="RollingFile"
            fileName="${sys:mule.home}/logs/${APP_NAME}.log"
            filePattern="${sys:mule.home}/logs/${APP_NAME}-%d{yyyy-MM-dd}-%i.log.gz">
            <JsonLayout compact="true" eventEol="true"
                        properties="true" stacktraceAsString="true">
                <KeyValuePair key="app" value="${APP_NAME}"/>
                <KeyValuePair key="environment" value="${ENV}"/>
                <KeyValuePair key="correlationId" value="$${ctx:correlationId}"/>
                <KeyValuePair key="flowName" value="$${ctx:flowName}"/>
            </JsonLayout>
            <Policies>
                <TimeBasedTriggeringPolicy interval="1"/>
                <SizeBasedTriggeringPolicy size="100 MB"/>
            </Policies>
            <DefaultRolloverStrategy max="10"/>
        </RollingFile>
    </Appenders>

    <Loggers>
        <AsyncLogger name="org.mule" level="INFO"/>
        <AsyncLogger name="com.mulesoft" level="INFO"/>
        <AsyncLogger name="org.mule.extension.http" level="WARN"/>

        <!-- Your application logger -->
        <AsyncLogger name="com.mycompany" level="INFO"/>

        <AsyncRoot level="INFO">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="RollingFile"/>
        </AsyncRoot>
    </Loggers>
</Configuration>
```

**Sample JSON log output:**
```json
{
  "instant": {"epochSecond": 1709136000, "nanoOfSecond": 123456789},
  "thread": "[MuleRuntime].cpuLight.03",
  "level": "INFO",
  "loggerName": "com.mycompany.OrderFlow",
  "message": "Order processed successfully",
  "app": "order-api",
  "environment": "production",
  "correlationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "flowName": "orderProcessingFlow",
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7"
}
```

### Step 2: Implement Correlation IDs

#### Automatic Correlation (Built-in)

Mule 4 automatically generates a correlation ID for each event. Access it in DataWeave:

```xml
<logger level="INFO"
    message="#['Processing request | correlationId=$(correlationId)']"
    category="com.mycompany.OrderFlow"/>
```

#### Propagate Correlation ID Across Services

```xml
<!-- Receive correlation ID from upstream (or generate new one) -->
<flow name="orderFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Extract or generate correlation ID -->
    <set-variable variableName="correlationId"
        value="#[attributes.headers.'x-correlation-id'
               default attributes.headers.'x-request-id'
               default correlationId]"/>

    <!-- Set in MDC for all subsequent log lines -->
    <scripting:execute engine="groovy">
        <scripting:code>
            org.slf4j.MDC.put("correlationId", vars.correlationId as String)
            org.slf4j.MDC.put("flowName", "orderFlow")
        </scripting:code>
    </scripting:execute>

    <!-- All loggers in this flow now include correlationId automatically -->
    <logger level="INFO" message="Order received" category="com.mycompany"/>

    <!-- Forward to downstream with correlation header -->
    <http:request config-ref="Inventory_API" method="GET" path="/stock">
        <http:headers>
            #[{'x-correlation-id': vars.correlationId}]
        </http:headers>
    </http:request>

    <!-- Clean up MDC -->
    <scripting:execute engine="groovy">
        <scripting:code>
            org.slf4j.MDC.clear()
        </scripting:code>
    </scripting:execute>
</flow>
```

#### MDC Without Scripting (Custom Interceptor)

```java
// MDCInterceptor.java — automatically sets MDC for every flow execution
import org.mule.runtime.api.interception.ProcessorInterceptor;
import org.mule.runtime.api.interception.ProcessorParameterValue;
import org.slf4j.MDC;
import java.util.Map;

public class MDCInterceptor implements ProcessorInterceptor {

    @Override
    public void before(ComponentLocation location,
                       Map<String, ProcessorParameterValue> parameters,
                       InterceptionEvent event) {
        MDC.put("correlationId", event.getCorrelationId());
        MDC.put("flowName", location.getRootContainerName());
    }

    @Override
    public void after(ComponentLocation location,
                      InterceptionEvent event, java.util.Optional<Throwable> thrown) {
        MDC.clear();
    }
}
```

### Step 3: Integrate with Logging Platforms

#### CloudWatch (CloudHub 2.0)

CloudHub 2.0 sends stdout to CloudWatch Logs automatically. JSON-formatted logs are parsed as structured data.

```bash
# Search CloudWatch Logs for a specific correlation ID
aws logs filter-log-events \
  --log-group-name "/aws/mule/my-app" \
  --filter-pattern '{ $.correlationId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890" }' \
  --start-time $(date -d '1 hour ago' +%s000) \
  --output json | jq '.events[].message | fromjson'
```

**CloudWatch Insights query:**
```
fields @timestamp, message, correlationId, flowName, level
| filter correlationId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
| sort @timestamp asc
```

#### ELK Stack (Elasticsearch + Logstash + Kibana)

**Filebeat config to ship Mule logs:**
```yaml
# filebeat.yml
filebeat.inputs:
- type: log
  paths:
    - /opt/mule/logs/*.log
  json.keys_under_root: true
  json.add_error_key: true
  json.message_key: message

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "mule-logs-%{+yyyy.MM.dd}"

setup.kibana:
  host: "kibana:5601"
```

**Logstash pipeline (if using Logstash instead of Filebeat):**
```ruby
# logstash.conf
input {
  file {
    path => "/opt/mule/logs/*.log"
    codec => json
    start_position => "beginning"
  }
}

filter {
  if [correlationId] {
    mutate {
      add_field => { "[@metadata][correlation]" => "%{correlationId}" }
    }
  }
  date {
    match => [ "[instant][epochSecond]", "UNIX" ]
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "mule-logs-%{+YYYY.MM.dd}"
  }
}
```

#### Splunk

**Splunk Universal Forwarder config:**
```ini
# inputs.conf
[monitor:///opt/mule/logs/*.log]
sourcetype = _json
index = mule
disabled = false
```

**Splunk search for correlated events:**
```
index=mule sourcetype=_json correlationId="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
| table _time level flowName message
| sort _time
```

### Step 4: Structured Error Logging

```xml
<error-handler>
    <on-error-continue type="ANY">
        <logger level="ERROR" category="com.mycompany"
            message="#[output application/json --- {
                correlationId: correlationId,
                errorType: error.errorType.identifier,
                errorDescription: error.description,
                failedComponent: error.failedComponent default 'unknown',
                httpStatus: error.errorType.identifier match {
                    case 'HTTP:TIMEOUT' -> 504,
                    case 'HTTP:CONNECTIVITY' -> 503,
                    case 'DB:CONNECTIVITY' -> 503,
                    else -> 500
                }
            }]"/>
    </on-error-continue>
</error-handler>
```

### Gotchas
- **MDC is thread-local** — when flow execution switches threads (which happens at every pool handoff in Mule 4 UBER model), MDC values are lost. Use the interceptor approach or re-set MDC after thread boundaries.
- **JSON logging doubles log volume** — structured logs include metadata that plain text does not. Budget for 1.5-2x more log storage.
- **Log4j2 JsonLayout requires Jackson** — ensure `jackson-databind` is available. Most Mule runtimes include it, but custom classloading can hide it.
- **AsyncLogger is strongly recommended** — synchronous logging blocks the flow thread. Use `AsyncLogger` (not `Logger`) in log4j2.xml. This requires the LMAX Disruptor library (included in Mule runtime).
- **CloudHub 1.0 log size limit** — CloudHub 1.0 truncates log entries longer than 8 KB. Large JSON objects in log messages may be cut off. Keep log messages concise.
- **Do not log full payloads** — logging `#[payload]` for large payloads consumes the stream (if non-repeatable) and creates enormous log entries. Log payload size, content type, and record count instead.
- **MDC.clear() in error handlers** — if an error occurs before MDC.clear() is called, MDC values from a previous request may leak into the error handler's log lines. Always clear MDC in both success and error paths.

### Related
- [OpenTelemetry Setup Guide](../opentelemetry-setup-guide/) — correlate traces with logs
- [CloudHub Log Analysis](../cloudhub-log-analysis/) — searching and downloading CloudHub logs
- [Anypoint Monitoring Custom Metrics](../anypoint-monitoring-custom-metrics/) — metrics alongside logs
- [Top 10 Production Incidents](../top-10-production-incidents/) — debugging scenarios that need structured logs
