## Structured JSON Logging
> Emit structured JSON error logs with correlationId, flowName, and errorType for ELK/Splunk ingestion.

### When to Use
- Your organization uses centralized log aggregation (ELK, Splunk, Datadog)
- You need machine-parseable error logs, not human-readable text
- Correlation IDs must flow through for distributed tracing

### Configuration / Code

**log4j2.xml** configuration:
```xml
<Configuration>
    <Appenders>
        <RollingFile name="json-file" fileName="${sys:mule.home}/logs/app.json.log"
                     filePattern="${sys:mule.home}/logs/app.json-%d{yyyy-MM-dd}-%i.log.gz">
            <JsonLayout compact="true" eventEol="true" properties="true">
                <KeyValuePair key="app" value="${sys:domain}"/>
                <KeyValuePair key="env" value="${sys:mule.env}"/>
            </JsonLayout>
            <Policies>
                <SizeBasedTriggeringPolicy size="10 MB"/>
            </Policies>
        </RollingFile>
    </Appenders>
    <Loggers>
        <AsyncRoot level="INFO">
            <AppenderRef ref="json-file"/>
        </AsyncRoot>
    </Loggers>
</Configuration>
```

**Mule flow logging:**
```xml
<on-error-propagate type="ANY">
    <logger level="ERROR" message='#[output application/json --- {
        event: "ERROR",
        correlationId: correlationId,
        flowName: flow.name,
        errorType: error.errorType.identifier,
        errorDescription: error.description,
        timestamp: now(),
        payload: if (sizeOf(payload default "") < 1000) payload else "TRUNCATED"
    }]'/>
</on-error-propagate>
```

### How It Works
1. Log4j2 `JsonLayout` outputs each log entry as a JSON line
2. The Mule logger outputs structured JSON with error context
3. Filebeat/Fluentd ships the JSON logs to ELK/Splunk
4. Dashboards and alerts query by `correlationId`, `errorType`, etc.

### Gotchas
- `JsonLayout` in Log4j2 adds thread, level, and logger name automatically
- Avoid logging full payloads — truncate to prevent disk exhaustion
- On CloudHub, use Anypoint Monitoring or DTS instead of custom log files
- Log4j2 async logging reduces performance impact — use `AsyncRoot`

### Related
- [CloudHub Notifications](../cloudhub-notifications/) — platform-native monitoring
- [Distributed Tracing](../../../performance/monitoring/distributed-tracing-bottlenecks/) — trace-level observability
