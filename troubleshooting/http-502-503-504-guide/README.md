## HTTP 502/503/504 Guide
> What each HTTP 5xx error means in a MuleSoft architecture and where the problem actually is

### When to Use
- API consumers receiving 502, 503, or 504 errors
- Need to determine whether the problem is in your Mule app, the load balancer, or a downstream service
- Intermittent 5xx errors with no clear pattern
- Building error handling that distinguishes between different 5xx causes

### The Problem

502, 503, and 504 look similar to the caller but have completely different root causes and fixes. In a typical MuleSoft stack (Load Balancer > API Gateway > Mule App > Downstream), any layer can generate these errors. Fixing the wrong layer wastes time and doesn't resolve the issue.

### Error Reference

```
+------+---------------------+------------------------------------------+
| Code | Name                | What It Means                            |
+------+---------------------+------------------------------------------+
| 500  | Internal Server Err | Your code threw an unhandled exception   |
| 502  | Bad Gateway         | Upstream sent an invalid response        |
| 503  | Service Unavailable | Server exists but can't handle requests  |
| 504  | Gateway Timeout     | Upstream didn't respond in time          |
+------+---------------------+------------------------------------------+
```

### 502 Bad Gateway

**Definition:** The proxy/LB received an invalid or incomplete response from the upstream server.

#### Where It Comes From

```
Client <-- 502 -- Load Balancer <-- garbled/incomplete response -- Mule App
```

**The LB expected a valid HTTP response but got:**
- Connection reset (TCP RST)
- Connection closed before response was sent
- Malformed HTTP response
- SSL/TLS handshake failure between LB and Mule

#### Common Causes in MuleSoft

**Cause 1: Mule App Crashed During Response**
```bash
# Check for JVM crash or OOMKilled around the time of 502
grep -i "OutOfMemory\|SIGKILL\|terminated\|crash" mule_ee.log
```

**Cause 2: Connection Reset by Mule**
```bash
# The Mule app closed the connection before sending the response
# Often caused by an error handler that doesn't set a response body
grep "Connection reset\|Broken pipe" mule_ee.log
```

**Fix:**
```xml
<!-- Ensure error handlers always return a valid response -->
<error-handler>
    <on-error-continue type="ANY">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: error.errorType.identifier,
    message: error.description default "Internal error",
    correlationId: correlationId
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <set-variable variableName="httpStatus" value="#[500]"/>
    </on-error-continue>
</error-handler>
```

**Cause 3: TLS Mismatch Between LB and Mule**
```bash
# Check TLS configuration
openssl s_client -connect <mule-host>:8082 -tls1_2

# If TLS 1.0/1.1 is required by LB but Mule only supports 1.2+, you get 502
```

#### Diagnostic Script for 502

```bash
#!/bin/bash
echo "=== 502 Diagnosis ==="

# 1. Is the Mule app running?
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8081/health

# 2. Check for recent crashes
grep -c "OutOfMemory\|FATAL\|terminated" /opt/mule/logs/mule_ee.log

# 3. Check for connection resets
grep -c "Connection reset\|Broken pipe" /opt/mule/logs/mule_ee.log

# 4. Test direct connection (bypass LB)
curl -v http://localhost:8081/api/test 2>&1 | head -20
```

---

### 503 Service Unavailable

**Definition:** The server is running but cannot handle the request right now.

#### Where It Comes From

```
Scenario A: Client <-- 503 -- Load Balancer (no healthy backends)
Scenario B: Client <-- 503 -- Mule App (overloaded, backpressure)
Scenario C: Client <-- 503 -- API Gateway (rate limited, policy rejection)
```

#### Common Causes in MuleSoft

**Cause 1: Load Balancer — No Healthy Backends**
```bash
# Check LB backend health
anypoint-cli cloudhub:load-balancer:describe <lb-name>

# If all backends are unhealthy, LB returns 503
# Check why health checks are failing
curl -v http://<mule-worker-ip>:8081/health
```

**Cause 2: Mule Backpressure (maxConcurrency Reached)**

When all threads are busy and `maxConcurrency` is set, Mule returns 503:
```
WARN: Flow 'orderFlow' backpressure applied. maxConcurrency reached.
```

```xml
<!-- This returns 503 when 10 requests are already processing -->
<flow name="orderFlow" maxConcurrency="10">
    <http:listener config-ref="HTTP" path="/orders"/>
    <!-- ... -->
</flow>
```

**Fix:** Increase `maxConcurrency` or scale to more workers.

**Cause 3: API Manager Rate Limiting Policy**
```
Policy violation: Rate limit exceeded. 429 Too Many Requests.
```

Note: Rate limiting usually returns 429, but some proxy configurations return 503.

**Cause 4: Mule App Deploying/Starting**

During deployment, the old version is stopped before the new one is ready. Requests in this window get 503.

**Fix:** Use rolling deployments (CloudHub 2.0) or zero-downtime deployment with multiple workers:
```bash
# CloudHub 2.0 rolling update (default behavior)
# Ensure replicas > 1 and PodDisruptionBudget is configured
```

**Cause 5: Circuit Breaker Tripped**
```bash
# If using a circuit breaker pattern that returns 503 when the circuit is open
grep "circuit.*open\|breaker.*open" mule_ee.log
```

#### Diagnostic Flowchart for 503

```
                  503 Service Unavailable
                          |
            Is the Mule app process running?
                          |
                 +--------+--------+
                 |                 |
                NO                YES
                 |                 |
         Check deployment    Can you reach it directly
         status and logs     (bypass LB)?
                 |                 |
         (Cause 4)          +-----+-----+
                            |           |
                          YES (200)    NO (503)
                            |           |
                   LB health check   App is returning 503
                   is failing        (backpressure or error)
                   (Cause 1)         (Cause 2 or 5)
```

---

### 504 Gateway Timeout

**Definition:** The proxy/LB did not receive a response from the upstream server within its timeout.

See the detailed recipe: [504 Gateway Timeout Diagnosis](../504-gateway-timeout-diagnosis/).

**Quick summary of causes:**
1. Load balancer timeout (300s on CloudHub shared LB)
2. Dedicated LB misconfigured timeout
3. API Gateway proxy timeout
4. Mule app waiting on slow downstream
5. Thread pool starvation (no threads to process the request)
6. Database query taking too long

---

### Distinguishing 5xx Errors in Logs

```bash
# Count 5xx errors by type
grep -oP 'HTTP/1\.[01]" \K5[0-9]{2}' access.log | sort | uniq -c | sort -rn

# If you have structured logging:
cat mule_ee.log | jq -r 'select(.httpStatus >= 500) | "\(.httpStatus) \(.errorType)"' | \
  sort | uniq -c | sort -rn
```

### Building Proper Error Responses

```xml
<!-- Global error handler that returns appropriate 5xx codes -->
<error-handler name="globalErrorHandler">
    <!-- Downstream timeout -> 504 -->
    <on-error-continue type="HTTP:TIMEOUT">
        <set-variable variableName="httpStatus" value="504"/>
        <set-payload value='#[output application/json --- {
            error: "GATEWAY_TIMEOUT",
            message: "Downstream service did not respond in time",
            correlationId: correlationId
        }]'/>
    </on-error-continue>

    <!-- Downstream connectivity -> 502 -->
    <on-error-continue type="HTTP:CONNECTIVITY">
        <set-variable variableName="httpStatus" value="502"/>
        <set-payload value='#[output application/json --- {
            error: "BAD_GATEWAY",
            message: "Unable to reach downstream service",
            correlationId: correlationId
        }]'/>
    </on-error-continue>

    <!-- Overloaded -> 503 -->
    <on-error-continue type="MULE:OVERLOAD">
        <set-variable variableName="httpStatus" value="503"/>
        <set-payload value='#[output application/json --- {
            error: "SERVICE_UNAVAILABLE",
            message: "Service is temporarily overloaded",
            retryAfter: 30,
            correlationId: correlationId
        }]'/>
    </on-error-continue>

    <!-- Everything else -> 500 -->
    <on-error-continue type="ANY">
        <set-variable variableName="httpStatus" value="500"/>
        <set-payload value='#[output application/json --- {
            error: "INTERNAL_SERVER_ERROR",
            message: "An unexpected error occurred",
            correlationId: correlationId
        }]'/>
    </on-error-continue>
</error-handler>
```

### Gotchas
- **502 is often misdiagnosed as a Mule bug** — most 502 errors are caused by the Mule app closing the connection unexpectedly (crash, OOM, unhandled exception). The LB is just reporting what it saw.
- **503 during deployment is expected** — if you have a single worker, there's always a window during deployment where the app is unavailable. This is not a bug, it's a design choice. Use multiple workers for zero-downtime.
- **Load balancer health checks determine 503 vs. 504** — if the LB knows the backend is down (failed health check), it returns 503 immediately. If it thinks the backend is up but gets no response, it waits and returns 504.
- **Retry logic should differ by error code** — 502/503 are safe to retry (the request may not have been processed). 504 is NOT safe to retry for non-idempotent operations (the request may have been processed but the response was lost).
- **Mule doesn't return 502/504 by default** — Mule returns 500 for unhandled exceptions. 502/504 are typically generated by the load balancer or API gateway. If you want your app to return them, you must explicitly set the status code in error handlers.
- **API Analytics may not distinguish sources** — Anypoint API Analytics shows 5xx counts but doesn't always indicate whether the error came from the Mule app, the gateway, or the LB. Correlate with application logs.

### Related
- [504 Gateway Timeout Diagnosis](../504-gateway-timeout-diagnosis/) — detailed 504 analysis
- [Timeout Hierarchy](../timeout-hierarchy/) — all timeout layers explained
- [Top 10 Production Incidents](../top-10-production-incidents/) — common incidents including 5xx errors
- [Deployment Failure Common Causes](../deployment-failure-common-causes/) — 503 during deployment
