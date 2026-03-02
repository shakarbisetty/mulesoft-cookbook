## 504 Gateway Timeout Diagnosis
> The 6+ root causes of 504 errors in Mule and how to identify each one

### When to Use
- Clients receiving HTTP 504 Gateway Timeout responses
- API Manager showing 504 errors in analytics
- Intermittent 504s that are difficult to reproduce
- 504s that started after a deployment or infrastructure change
- Need to determine whether the problem is Mule, the load balancer, or a downstream service

### The Problem

A 504 Gateway Timeout means a proxy or load balancer did not receive a response from the upstream server within its timeout window. In a MuleSoft architecture, the 504 can originate from at least 6 different layers, and the fix for each is different. Without systematic diagnosis, teams chase the wrong layer.

### The 504 Origin Map

```
Client -> Load Balancer -> API Gateway -> Mule App -> Downstream Service
  |            |               |            |              |
  |        504 from LB     504 from       504 from      Timeout
  |        (Cause 1-2)     Gateway        Mule app      (Cause 5-6)
  |                        (Cause 3)      (Cause 4)
  |
  Receives 504 — but from WHERE?
```

### Cause 1: CloudHub Load Balancer Timeout

**Shared Load Balancer:** Fixed 300-second timeout (not configurable).
**Dedicated Load Balancer:** Configurable timeout.

**How to identify:**
```bash
# Check if the flow takes > 300 seconds
# Look at response time in Anypoint Monitoring or logs
grep "orderFlow" mule_ee.log | grep "completed" | awk '{print $NF}' | sort -n | tail -5

# If processing time > 300s on shared LB -> this is the cause
```

**Fix:**
```
Option A: Optimize the flow to complete within 300 seconds
Option B: Switch to a dedicated load balancer with higher timeout
Option C: Convert to async pattern (accept request, return 202, process in background)
```

**Async pattern implementation:**
```xml
<flow name="asyncOrderFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Return 202 immediately -->
    <set-variable variableName="requestId" value="#[uuid()]"/>

    <!-- Queue for background processing -->
    <vm:publish config-ref="VM" queueName="order-processing">
        <vm:content>#[{requestId: vars.requestId, payload: payload}]</vm:content>
    </vm:publish>

    <set-payload value='#[output application/json --- {
        status: "accepted",
        requestId: vars.requestId,
        statusUrl: "/orders/status/$(vars.requestId)"
    }]'/>
    <set-variable variableName="httpStatus" value="202"/>
</flow>

<flow name="backgroundOrderProcessing">
    <vm:listener config-ref="VM" queueName="order-processing"/>
    <!-- Long-running processing here — no timeout concern -->
</flow>
```

### Cause 2: Dedicated Load Balancer Misconfiguration

**How to identify:**
```bash
# Check DLB settings
anypoint-cli cloudhub:load-balancer:describe <lb-name>

# Look for "Upstream timeout" — if lower than your flow processing time, this is the cause
```

**Fix:**
```bash
# Increase DLB upstream timeout
anypoint-cli cloudhub:load-balancer:update <lb-name> --upstream-timeout 600
```

### Cause 3: API Gateway Proxy Timeout

If using API Manager with an auto-generated proxy, the proxy has its own timeout.

**How to identify:**
- 504 appears in API Manager analytics
- Mule application logs show the request completed successfully
- There's a gap between proxy response and app response

**Fix:**
```xml
<!-- In the auto-generated proxy, increase responseTimeout -->
<http:request config-ref="Backend_API" method="#[attributes.method]"
    path="#[attributes.requestPath]"
    responseTimeout="60000"/>
```

### Cause 4: Mule Application Internal Timeout

**How to identify:**
```bash
# Check if Mule itself is returning 504
grep "504\|TIMEOUT" mule_ee.log | head -10

# Check which component is timing out
grep "responseTimeout\|timed out\|Read timed out" mule_ee.log | head -10
```

**Common scenarios:**
- HTTP Requester `responseTimeout` reached (default: 10 seconds)
- Database query exceeds connection timeout
- SFTP operation times out

**Fix:** Increase the specific operation timeout:
```xml
<http:request config-ref="Backend" method="GET" path="/slow-endpoint"
    responseTimeout="60000"/>
```

### Cause 5: Downstream Service Slow Response

**How to identify:**
```bash
# Test downstream directly
time curl -s -o /dev/null -w "%{http_code}" https://downstream-api.example.com/endpoint

# Check if downstream has its own timeout issues
curl -v -w "\nTime: %{time_total}s\n" https://downstream-api.example.com/health
```

**Fix:** Implement timeout + fallback:
```xml
<try>
    <http:request config-ref="Downstream" method="GET" path="/data"
        responseTimeout="10000"/>
    <error-handler>
        <on-error-continue type="HTTP:TIMEOUT">
            <logger level="WARN" message="Downstream timeout, using cached response"/>
            <os:retrieve key="last-known-good" objectStore="cache"
                target="payload"/>
        </on-error-continue>
    </error-handler>
</try>
```

### Cause 6: Thread Pool Starvation

When all threads are consumed, new requests cannot be processed and eventually timeout at the load balancer.

**How to identify:**
```bash
# Take thread dump
jcmd <PID> Thread.print > dump.txt

# Count threads waiting vs. active
grep "Thread.State" dump.txt | sort | uniq -c

# If ALL cpuLight threads are BLOCKED/WAITING -> pool starvation
grep -A 1 "cpuLight" dump.txt | grep "BLOCKED\|WAITING" | wc -l
```

**Fix:** See [Thread Pool Component Mapping](../thread-pool-component-mapping/) to identify and fix the blocking operation.

### Diagnostic Decision Tree

```
                        Getting 504 errors
                              |
                 Is the Mule app logging the request?
                              |
                    +---------+---------+
                    |                   |
                   NO                  YES
                    |                   |
            Request never reached      Does the Mule app log
            the Mule app               show the request completing?
                    |                   |
            Check LB timeout     +-----+-----+
            (Cause 1 or 2)       |           |
                                YES          NO
                                 |           |
                           LB timeout   Which component
                           is shorter   is the flow waiting on?
                           than flow        |
                           processing  +----+----+
                           time        |         |
                           (Cause 1-2) |         |
                                  HTTP Request  DB Query
                                  (Cause 4-5)  (Cause 4)
```

### Quick Diagnosis Script

```bash
#!/bin/bash
# 504-diagnosis.sh — run this during a 504 incident

APP_NAME=$1
echo "=== 504 Diagnosis for $APP_NAME ==="

# 1. Check if app is responding at all
echo "--- Health Check ---"
curl -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s\n" \
  "http://localhost:8081/health" || echo "App not responding locally"

# 2. Check thread state
PID=$(pgrep -f "MuleContainerBootstrap" | head -1)
if [ -n "$PID" ]; then
  echo "--- Thread Summary ---"
  jcmd $PID Thread.print 2>/dev/null | grep "Thread.State" | sort | uniq -c
  echo "--- CPU_LITE Pool ---"
  jcmd $PID Thread.print 2>/dev/null | grep -c "cpuLight.*BLOCKED"
  echo " threads BLOCKED"
fi

# 3. Check recent errors
echo "--- Recent Timeout Errors ---"
grep -i "timeout\|504\|timed.out" /opt/mule/logs/mule_ee.log 2>/dev/null | tail -5

# 4. Check memory
echo "--- Memory ---"
jcmd $PID GC.heap_info 2>/dev/null | head -5

echo "=== Diagnosis Complete ==="
```

### Gotchas
- **504 vs. 408** — 504 means the proxy/LB timed out waiting for your app. 408 means the server timed out waiting for the client to send the request. They're different failure points.
- **CloudHub shared LB 300s limit is absolute** — you cannot increase it. If your flow legitimately takes >5 minutes, you MUST use an async pattern or a dedicated LB.
- **API Manager analytics may show 504 from the proxy** — this doesn't mean your Mule app returned 504. The proxy timed out waiting for your app. Check your app logs separately.
- **Multiple 504 sources** — in a typical MuleSoft architecture with DLB + API Gateway + Mule App + Downstream, a 504 could originate from any of these layers. Start from the innermost layer (downstream) and work outward.
- **Retry on 504 can make things worse** — if the downstream is overloaded, retrying adds more load. Implement exponential backoff with jitter.
- **Health checks mask the problem** — a health check endpoint that returns 200 doesn't mean the app can process real requests. Thread starvation allows health checks to succeed while real requests timeout.

### Related
- [HTTP 502/503/504 Guide](../http-502-503-504-guide/) — all 5xx errors explained
- [Timeout Hierarchy](../timeout-hierarchy/) — understand every timeout layer
- [Thread Pool Component Mapping](../thread-pool-component-mapping/) — fix thread starvation
- [Connection Pool Sizing](../connection-pool-sizing/) — fix pool-related timeouts
