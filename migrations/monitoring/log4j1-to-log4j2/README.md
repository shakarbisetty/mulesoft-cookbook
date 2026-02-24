## Log4j 1.x to Log4j 2.x in Mule Apps
> Migrate from Log4j 1.x to Log4j 2.x configuration in Mule applications

### When to Use
- Mule 4 requires Log4j 2.x (Mule 3 used 1.x)
- Security vulnerability (Log4Shell CVE-2021-44228) remediation
- Need async logging, structured JSON output, or log routing

### Configuration / Code

#### 1. Log4j 2 Configuration (XML)

```xml
<!-- src/main/resources/log4j2.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <!-- Console appender -->
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout
                pattern="%-5p %d [%t] [processor: %X{processorPath}] %c: %m%n" />
        </Console>

        <!-- Rolling file appender -->
        <RollingFile name="File"
            fileName="${sys:mule.home}/logs/${sys:mule.app.name}.log"
            filePattern="${sys:mule.home}/logs/${sys:mule.app.name}-%d{yyyy-MM-dd}-%i.log.gz">
            <PatternLayout
                pattern="%-5p %d [%t] [processor: %X{processorPath}] %c: %m%n" />
            <Policies>
                <TimeBasedTriggeringPolicy />
                <SizeBasedTriggeringPolicy size="10 MB" />
            </Policies>
            <DefaultRolloverStrategy max="10" />
        </RollingFile>

        <!-- JSON structured logging -->
        <Console name="JSON" target="SYSTEM_OUT">
            <JsonLayout compact="true" eventEol="true"
                includeStacktrace="true">
                <KeyValuePair key="app" value="${sys:mule.app.name}" />
                <KeyValuePair key="env" value="${sys:mule.env}" />
            </JsonLayout>
        </Console>
    </Appenders>

    <Loggers>
        <!-- Mule runtime (reduce noise) -->
        <AsyncLogger name="org.mule" level="INFO" />
        <AsyncLogger name="com.mulesoft" level="INFO" />

        <!-- Connector logging -->
        <AsyncLogger name="org.mule.extension.http" level="WARN" />
        <AsyncLogger name="org.mule.extension.db" level="WARN" />

        <!-- Application logging -->
        <AsyncLogger name="com.mycompany" level="DEBUG" />

        <AsyncRoot level="INFO">
            <AppenderRef ref="Console" />
            <AppenderRef ref="File" />
        </AsyncRoot>
    </Loggers>
</Configuration>
```

#### 2. Key Syntax Changes

| Log4j 1.x | Log4j 2.x |
|---|---|
| `log4j.properties` | `log4j2.xml` (or .yaml, .json) |
| `log4j.rootLogger=INFO, stdout` | `<Root level="INFO">` |
| `log4j.appender.stdout=ConsoleAppender` | `<Console name="Console">` |
| `log4j.appender.stdout.layout=PatternLayout` | `<PatternLayout>` |
| `log4j.logger.com.mycompany=DEBUG` | `<Logger name="com.mycompany" level="DEBUG">` |

#### 3. Async Logging for Performance

```xml
<!-- Use AsyncLogger for high-throughput applications -->
<Loggers>
    <!-- All loggers async by default -->
    <AsyncRoot level="INFO">
        <AppenderRef ref="Console" />
    </AsyncRoot>
</Loggers>

<!-- Or set system property -->
<!-- -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -->
```

### How It Works
1. Mule 4 runtime includes Log4j 2.x; configuration goes in `src/main/resources/log4j2.xml`
2. AsyncLogger uses LMAX Disruptor for non-blocking logging
3. JSON layout enables structured logging for log aggregation platforms
4. MDC (Mapped Diagnostic Context) propagates Mule flow context to log entries

### Migration Checklist
- [ ] Create `log4j2.xml` replacing `log4j.properties`
- [ ] Convert appender syntax to Log4j 2 XML format
- [ ] Convert logger level declarations
- [ ] Add async loggers for performance
- [ ] Configure rolling file policies
- [ ] Test log output format
- [ ] Verify MDC context (correlation ID, flow name)

### Gotchas
- Log4j 2.x uses XML by default; properties format has different syntax than 1.x
- Ensure Log4j 2.17.1+ to avoid Log4Shell vulnerability
- AsyncLogger requires LMAX Disruptor on classpath (included in Mule runtime)
- CloudHub logging has its own appender - do not override it

### Related
- [anypoint-to-otel](../anypoint-to-otel/) - Observability migration
- [splunk-to-otlp](../splunk-to-otlp/) - Log forwarding
