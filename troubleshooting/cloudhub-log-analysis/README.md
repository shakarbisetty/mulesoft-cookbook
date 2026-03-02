## CloudHub Log Analysis
> Searching CloudHub logs effectively — retention, downloading, filtering, and advanced queries

### When to Use
- Debugging a production issue and need to find specific log entries
- Need to download logs for offline analysis or compliance
- Logs are disappearing and you need to understand retention policies
- Setting up log forwarding to an external system
- Need to search across multiple workers or applications

### The Problem

CloudHub log management differs significantly between CloudHub 1.0 and 2.0, and the documentation is scattered. Developers waste time searching the wrong way, miss critical log entries due to retention limits, or fail to set up log forwarding before an incident occurs.

### CloudHub 1.0 Log Basics

#### Retention
```
+-------------------+------------------+
| Log Type          | Retention        |
+-------------------+------------------+
| Application logs  | 30 days          |
| Worker logs       | 30 days          |
| Deployment logs   | Permanent (UI)   |
| Archived logs     | Until deleted    |
+-------------------+------------------+
```

#### Viewing Logs in Runtime Manager

1. Navigate to **Runtime Manager > Applications > [app-name]**
2. Click the **Logs** tab
3. Use the search bar and filters

**Filter options:**
- Priority: DEBUG, INFO, WARN, ERROR
- Time range: Last hour, 24 hours, 7 days, custom range
- Worker: Select specific worker (for multi-worker deployments)

#### Downloading Logs via Anypoint CLI

```bash
# Install Anypoint CLI
npm install -g anypoint-cli@latest

# Login
anypoint-cli login --username <user> --password <pass>

# Set environment
anypoint-cli use environment <env-name>

# Download logs (saves to current directory)
anypoint-cli runtime-mgr:application:download-logs <app-name>

# Tail logs in real time
anypoint-cli runtime-mgr:application:tail-logs <app-name>
```

#### Downloading Logs via API

```bash
# Get auth token
TOKEN=$(curl -s https://anypoint.mulesoft.com/accounts/login \
  -H "Content-Type: application/json" \
  -d '{"username":"'$USER'","password":"'$PASS'"}' | jq -r '.access_token')

# Get organization ID
ORG_ID=$(curl -s https://anypoint.mulesoft.com/accounts/api/me \
  -H "Authorization: Bearer $TOKEN" | jq -r '.user.organizationId')

# Get environment ID
ENV_ID=$(curl -s "https://anypoint.mulesoft.com/accounts/api/organizations/$ORG_ID/environments" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.data[] | select(.name=="Production") | .id')

# Download logs
curl -s "https://anypoint.mulesoft.com/cloudhub/api/v2/applications/<app-name>/logs" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-ANYPNT-ENV-ID: $ENV_ID" \
  -H "X-ANYPNT-ORG-ID: $ORG_ID" \
  -o logs.json
```

### CloudHub 2.0 Log Basics

#### Retention
```
+-------------------+------------------+
| Log Type          | Retention        |
+-------------------+------------------+
| Application logs  | 30 days (default)|
| Pod logs          | Until pod dies   |
| Deployment logs   | 30 days          |
+-------------------+------------------+
```

#### Viewing Logs via Anypoint CLI (CH2)

```bash
# List replicas (pods)
anypoint-cli runtime-mgr:application:describe <app-name> --output json | jq '.replicas'

# Tail logs from a specific replica
anypoint-cli runtime-mgr:application:tail-logs <app-name> --replica <replica-id>
```

### Effective Log Searching

#### Pattern 1: Find All Errors in a Time Window

```bash
# Download and search locally (most reliable)
anypoint-cli runtime-mgr:application:download-logs <app-name>

# Search for errors
grep -i "ERROR\|Exception\|FATAL" <app-name>-logs.log | head -50

# With timestamps
grep -i "ERROR" <app-name>-logs.log | awk '{print $1, $2, $0}' | sort
```

#### Pattern 2: Trace a Request by Correlation ID

```bash
# Find all log lines for a specific correlation ID
grep "a1b2c3d4-e5f6-7890" <app-name>-logs.log

# If using structured JSON logging:
cat <app-name>-logs.log | jq -r 'select(.correlationId == "a1b2c3d4-e5f6-7890")'
```

#### Pattern 3: Count Errors by Type

```bash
# Extract error types and count occurrences
grep "ERROR" <app-name>-logs.log | \
  grep -oP 'Error type: \K[A-Z_:]+' | \
  sort | uniq -c | sort -rn

# Sample output:
#   142 HTTP:TIMEOUT
#    38 DB:CONNECTIVITY
#    12 MULE:EXPRESSION
#     5 HTTP:INTERNAL_SERVER_ERROR
```

#### Pattern 4: Find Slow Requests

```bash
# If you have timing logs
grep "PERF\|elapsed\|duration\|response.time" <app-name>-logs.log | \
  awk -F'[=:]' '{for(i=1;i<=NF;i++) if($i~/[0-9]+ms/) print $0}' | \
  sort -t'=' -k2 -rn | head -20
```

#### Pattern 5: Find Restart Events

```bash
# CloudHub 1.0
grep -i "starting\|started\|stopped\|restarting\|OOMKilled" <app-name>-logs.log

# Look for the pattern: stopped -> starting -> started
# Multiple restart cycles = crash loop
```

### Log Forwarding Setup

#### Forward to Splunk

```bash
# In Runtime Manager > Application > Settings > Logging
# Add log4j2 appender:
```

**log4j2.xml addition:**
```xml
<Appenders>
    <!-- Existing console appender -->
    <Console name="Console" target="SYSTEM_OUT">
        <PatternLayout pattern="%d [%t] %-5p %c - %m%n"/>
    </Console>

    <!-- Splunk HEC appender -->
    <Http name="Splunk" url="https://splunk.example.com:8088/services/collector/event">
        <Property name="Authorization" value="Splunk ${splunk.hec.token}"/>
        <JsonLayout compact="true" eventEol="true">
            <KeyValuePair key="source" value="mule"/>
            <KeyValuePair key="sourcetype" value="_json"/>
        </JsonLayout>
    </Http>
</Appenders>
```

#### Forward to ELK (via Filebeat sidecar on CloudHub 2.0)

CloudHub 2.0 runs in Kubernetes, so you can deploy a Filebeat sidecar:

```yaml
# In your CH2 deployment config, configure log4j2 to write to stdout (default)
# Then set up a CloudWatch Logs subscription to forward to ELK
```

#### Forward to Datadog

```bash
# CloudHub 2.0: Use Datadog's CloudWatch Logs integration
# CloudHub 1.0: Use a custom log4j2 appender or Datadog's TCP/HTTP log intake
```

### Advanced: Log Level Management at Runtime

```bash
# Change log level without restarting (CloudHub 1.0)
# Runtime Manager > Application > Settings > Logging

# Via API:
curl -X PATCH "https://anypoint.mulesoft.com/cloudhub/api/v2/applications/<app-name>" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "loggingCustomLog4JEnabled": true,
    "loggingNgEnabled": true
  }'

# Enable DEBUG for specific package at runtime:
# Runtime Manager > Logs tab > click gear icon > Add logger
# Package: com.mycompany.flows
# Level: DEBUG
```

### Gotchas
- **CloudHub 1.0 log search UI is slow for large volumes** — for high-throughput apps generating GBs of logs daily, the UI search times out. Download logs and search locally with grep.
- **30-day retention means evidence disappears** — set up log forwarding BEFORE you need it. After an incident, it's too late if logs are past retention.
- **Multi-worker log interleaving** — on CloudHub 1.0 with multiple workers, the Logs tab interleaves logs from all workers. Filter by worker to isolate a single instance.
- **Log4j2 changes require redeployment on CloudHub 1.0** — unlike on-prem where you can hot-reload log4j2.xml, CloudHub requires a full redeployment to pick up log config changes. Runtime log level changes (via UI) are temporary and reset on restart.
- **CloudHub 2.0 pod logs are ephemeral** — when a pod restarts, its logs are gone unless forwarded to an external system. Always configure log forwarding for CH2.
- **Binary payloads in logs corrupt log files** — if you log `#[payload]` and the payload is binary (PDF, image), it creates garbage in your log file and can break log parsing. Always check content type before logging payload.
- **Anypoint CLI tail-logs has a buffer** — there's a 5-10 second delay between log generation and appearance in tail output. Don't assume logs are missing just because they don't appear instantly.
- **Log4j2 async logging can lose logs on crash** — AsyncLogger buffers log entries. If the JVM crashes (OOM, kill -9), buffered entries are lost. For critical audit logs, use synchronous logging on a separate appender.

### Related
- [Structured Logging Complete](../structured-logging-complete/) — JSON logging and correlation IDs
- [Deployment Failure Common Causes](../deployment-failure-common-causes/) — finding deployment errors in logs
- [Top 10 Production Incidents](../top-10-production-incidents/) — what to search for during incidents
- [OpenTelemetry Setup Guide](../opentelemetry-setup-guide/) — correlate logs with traces
