## Timeout Hierarchy
> Connection, socket, pool wait, and response timeouts explained — where each one fires and what error it produces

### When to Use
- Getting timeout errors but unsure which timeout is firing
- Need to configure timeouts correctly for an HTTP requester
- Seeing `MULE:TIMEOUT` errors but the downstream service is responding within expected time
- Designing retry logic and need to know total worst-case latency
- Calculating SLA response time based on all timeout layers

### The Problem

A single HTTP request in Mule passes through at least 5 timeout boundaries. Each one produces a different error, and misconfiguring any one of them causes either premature failures (timeout too low) or hung threads (timeout too high or infinite). Developers often set one timeout and think they're covered, not realizing that another layer can fire first or that their timeout is being overridden.

### The Timeout Stack (Outside In)

```
+-----------------------------------------------------------------+
| Layer 1: Load Balancer / API Gateway Timeout (external)         |
|   CloudHub DLB: 300s default    Dedicated LB: configurable      |
| +-------------------------------------------------------------+ |
| | Layer 2: HTTP Listener Response Timeout                      | |
| |   Default: none (waits forever for your flow to complete)    | |
| | +---------------------------------------------------------+ | |
| | | Layer 3: Flow maxConcurrency Backpressure                | | |
| | |   Default: no limit (queues indefinitely)                | | |
| | | +-----------------------------------------------------+ | | |
| | | | Layer 4: Connection Pool Wait (exhaustedAction)      | | | |
| | | |   maxWait: 30000ms default                          | | | |
| | | | +-------------------------------------------------+ | | | |
| | | | | Layer 5a: TCP Connection Timeout                 | | | | |
| | | | |   connectionTimeout: 30000ms default            | | | | |
| | | | +-------------------------------------------------+ | | | |
| | | | | Layer 5b: Socket Read Timeout (clientTimeout)   | | | | |
| | | | |   clientTimeout: varies by connector            | | | | |
| | | | +-------------------------------------------------+ | | | |
| | | | | Layer 5c: Response Timeout (responseTimeout)    | | | | |
| | | | |   Default: 10000ms (HTTP Requester)             | | | | |
| | | | +-------------------------------------------------+ | | | |
| | | +-----------------------------------------------------+ | | |
| | +---------------------------------------------------------+ | |
| +-------------------------------------------------------------+ |
+-----------------------------------------------------------------+
```

### Each Timeout Explained

#### Layer 1: Load Balancer Timeout

**Where:** External to your Mule application. CloudHub DLB or dedicated load balancer.

```
CloudHub Shared Load Balancer:  300 seconds (not configurable)
CloudHub Dedicated Load Balancer: configurable via Anypoint CLI
On-prem load balancer: depends on your infrastructure
```

**Error the caller sees:**
```
HTTP 504 Gateway Timeout
```

**Configure dedicated LB timeout:**
```bash
anypoint-cli cloudhub:load-balancer:describe <lb-name>
# Check "Upstream timeout" setting
```

#### Layer 2: HTTP Listener Response Timeout

**Where:** Your Mule application's HTTP listener waiting for your flow to finish.

```xml
<http:listener-config name="HTTP_Listener">
    <http:listener-connection host="0.0.0.0" port="8081"
        readTimeout="60000"/>
    <!-- readTimeout: max time listener waits for the complete request body -->
</http:listener-config>
```

The listener itself does not have a "response timeout" — it waits for the flow to complete. The limiting factor is the **load balancer timeout** (Layer 1) or the **caller's timeout**.

#### Layer 3: Flow Backpressure / maxConcurrency

**Where:** Mule flow's internal queueing when concurrent requests exceed capacity.

```xml
<flow name="myFlow" maxConcurrency="10">
    <!-- When 11th request arrives while 10 are processing, it waits -->
    <!-- There's no explicit timeout here — it waits until a slot opens -->
    <!-- The effective timeout is the load balancer timeout (Layer 1) -->
</flow>
```

**Error:** No explicit error — the request eventually times out at Layer 1 (504) or the caller gives up.

#### Layer 4: Connection Pool Wait Timeout

**Where:** Waiting to borrow a connection from the pool.

```xml
<http:request-config name="Backend">
    <http:request-connection host="api.example.com" port="443">
        <pooling-profile
            maxActive="10"
            maxWait="30000"
            exhaustedAction="WHEN_EXHAUSTED_WAIT"/>
    </http:request-connection>
</http:request-config>
```

**Error:**
```
org.mule.runtime.api.connection.ConnectionException:
  Timeout waiting for connection from pool (30000ms)
Error type: MULE:CONNECTIVITY
```

#### Layer 5a: TCP Connection Timeout

**Where:** Establishing the TCP connection (SYN → SYN-ACK → ACK).

```xml
<http:request-connection host="api.example.com" port="443">
    <http:client-socket-properties>
        <sockets:tcp-client-socket-properties
            connectionTimeout="5000"/>
    </http:client-socket-properties>
</http:request-connection>
```

**Error:**
```
java.net.ConnectException: Connection timed out (5000ms)
Error type: HTTP:CONNECTIVITY
```

**Common cause:** Firewall blocking the port, wrong host/port, DNS resolution failure.

#### Layer 5b: Socket Read Timeout (clientTimeout)

**Where:** Waiting for data after the TCP connection is established. This is the time between sending the request and receiving the first byte of response.

```xml
<sockets:tcp-client-socket-properties
    connectionTimeout="5000"
    clientTimeout="30000"/>
```

**Error:**
```
java.net.SocketTimeoutException: Read timed out (30000ms)
Error type: HTTP:TIMEOUT
```

**Common cause:** Downstream service processing slowly, network latency, server overloaded.

#### Layer 5c: HTTP Requester Response Timeout

**Where:** The HTTP requester operation itself. This is an additional timeout layer on top of the socket timeout.

```xml
<http:request config-ref="Backend" method="GET" path="/api/data"
    responseTimeout="10000"/>
```

**Error:**
```
org.mule.extension.http.api.error.HttpRequestFailedException:
  HTTP GET on resource 'https://api.example.com/api/data' failed: timeout
Error type: HTTP:TIMEOUT
```

### Which Timeout Fires First?

```
Scenario: All timeouts set, downstream takes 45 seconds to respond

Layer 5c: responseTimeout=10000    <-- FIRES FIRST at 10s
Layer 5b: clientTimeout=30000      <-- Would fire at 30s (never reached)
Layer 4:  maxWait=30000            <-- Only if pool exhausted (N/A here)
Layer 5a: connectionTimeout=5000   <-- Only during TCP connect (N/A here)
Layer 1:  LB timeout=300000        <-- Would fire at 300s (never reached)

Result: HTTP:TIMEOUT after 10 seconds
```

### Recommended Timeout Configuration

```xml
<!-- Production-ready HTTP Requester config -->
<http:request-config name="Backend_Service"
    responseTimeout="15000">   <!-- 15 seconds max per request -->
    <http:request-connection host="${backend.host}" port="${backend.port}"
        protocol="HTTPS">
        <http:client-socket-properties>
            <sockets:tcp-client-socket-properties
                connectionTimeout="5000"       <!-- 5s to establish TCP -->
                clientTimeout="30000"/>         <!-- 30s socket read timeout -->
        </http:client-socket-properties>
        <pooling-profile
            maxActive="15"
            maxIdle="5"
            maxWait="10000"                    <!-- 10s waiting for pool -->
            exhaustedAction="WHEN_EXHAUSTED_WAIT"/>
    </http:request-connection>
</http:request-config>
```

**Worst-case latency calculation:**
```
Pool wait:        10,000ms  (if pool is full)
TCP connect:       5,000ms  (if host is slow to respond)
Response:         15,000ms  (if service is slow)
─────────────────────────
Maximum total:    30,000ms  (30 seconds worst case)

Ensure your LB timeout > 30 seconds + processing time margin
```

### Diagnostic Steps: Identifying Which Timeout Fired

#### Step 1: Read the Error Type

| Error Type | Layer | Meaning |
|-----------|-------|---------|
| HTTP:CONNECTIVITY | 5a | TCP connection failed |
| HTTP:TIMEOUT | 5b/5c | Response not received in time |
| MULE:CONNECTIVITY | 4 | Pool wait timed out |
| HTTP:CLIENT_SECURITY | 5a | TLS handshake failed |

#### Step 2: Check Timestamps

```bash
# Extract timeout errors with timestamps
grep -i "timeout\|timed out" mule_ee.log | \
  awk '{print $1, $2, $0}' | tail -20
```

If the time between request start and error matches:
- ~5s → connectionTimeout
- ~10s → responseTimeout or maxWait
- ~30s → clientTimeout
- ~300s → load balancer timeout

#### Step 3: Test Downstream Independently

```bash
# Test TCP connectivity
nc -zv api.example.com 443 -w 5

# Test HTTP response time
curl -o /dev/null -s -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTLS: %{time_appconnect}s\nFirst byte: %{time_starttransfer}s\nTotal: %{time_total}s\n" https://api.example.com/health

# Test with explicit timeout
curl --connect-timeout 5 --max-time 30 https://api.example.com/api/data
```

### Gotchas
- **responseTimeout vs. clientTimeout confusion** — `responseTimeout` is on the HTTP requester operation. `clientTimeout` is on the socket. If both are set, the lower one fires first. Set `clientTimeout` higher than `responseTimeout` to avoid confusion.
- **Default responseTimeout is 10 seconds** — many developers don't know this. If your downstream takes 15 seconds legitimately, you'll get timeout errors with no config changes.
- **CloudHub DLB timeout of 300s is NOT configurable on shared LBs** — only dedicated load balancers allow custom timeouts. If your flow takes >300s, you need a dedicated LB or an async pattern.
- **maxWait=0 means wait forever** — counterintuitively, setting maxWait to 0 doesn't mean "fail immediately." It means "wait indefinitely." Use WHEN_EXHAUSTED_FAIL for immediate failure.
- **TLS handshake is part of connectionTimeout** — the connectionTimeout covers TCP connect + TLS negotiation. Complex certificate chains or OCSP checking can eat into this budget.
- **Retry logic multiplies timeouts** — if you have Until Successful with 3 retries and a 30s timeout, the total worst case is 90 seconds. Make sure this fits within your LB timeout.
- **Database query timeout is separate** — JDBC drivers have their own query timeout (`queryTimeout` parameter) independent of the Mule connection pool timeout.

### Related
- [Connection Pool Sizing](../connection-pool-sizing/) — size the pools these timeouts protect
- [504 Gateway Timeout Diagnosis](../504-gateway-timeout-diagnosis/) — when Layer 1 fires
- [HTTP 502/503/504 Guide](../http-502-503-504-guide/) — all HTTP 5xx errors explained
- [Flow Profiling Methodology](../flow-profiling-methodology/) — find why your flow exceeds timeouts
