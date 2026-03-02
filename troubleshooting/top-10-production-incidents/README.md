## Top 10 Production Incidents
> The most common Mule 4 production incidents with diagnostic runbooks for each

### When to Use
- On-call and facing a production incident you haven't seen before
- Building runbooks for your integration operations team
- Training new team members on common failure modes
- Post-incident review to prevent recurrence

### The Problem

The same 10 incidents account for ~80% of all Mule production pages. Each one has a specific diagnostic path and fix. Having a runbook for each eliminates the guesswork during a 2 AM incident.

---

### Incident 1: Application Unresponsive (Thread Pool Exhaustion)

**Alert:** Health check returns 503 or times out. No errors in logs.

**Symptoms:**
- HTTP requests hang with no response
- No ERROR-level logs (the app isn't crashing, it's stuck)
- CPU is low, memory is normal

**Diagnostic runbook:**
```bash
# 1. Take thread dump (3x, 10s apart)
jcmd <PID> Thread.print > dump_$(date +%s).txt

# 2. Count thread states
grep "Thread.State" dump_*.txt | sort | uniq -c

# 3. Look for the culprit pattern
grep -A 5 "cpuLight" dump_1.txt | grep "BLOCKED\|WAITING"
```

**Root cause:** Usually a blocking operation on the CPU_LITE pool (e.g., synchronous HTTP call, database query without timeout, or synchronized Java code).

**Fix:** Move blocking operations to IO pool. Add timeouts to all external calls.

**Time to resolve:** 15-30 minutes.

---

### Incident 2: OutOfMemoryError

**Alert:** Application restarts. CloudHub 2.0 shows OOMKilled.

**Symptoms:**
- `java.lang.OutOfMemoryError: Java heap space` in logs
- Worker restarts repeatedly
- Memory graph shows steady climb to 100%

**Diagnostic runbook:**
```bash
# 1. Check for heap dump
ls -la /tmp/*.hprof

# 2. If no dump, enable for next occurrence
# Add JVM arg: -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/

# 3. Quick histogram
jcmd <PID> GC.class_histogram | head -20
```

**Root cause:** Large payload in memory, unbounded cache, DataWeave on large dataset, or connection leak.

**Fix:** See [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) for the full 30-minute procedure.

**Time to resolve:** 30-60 minutes.

---

### Incident 3: Downstream Service Timeout Cascade

**Alert:** Multiple APIs returning 504 errors simultaneously.

**Symptoms:**
- One downstream service becomes slow
- All IO threads get consumed waiting for that service
- Other flows that use different downstream services also start failing

**Diagnostic runbook:**
```bash
# 1. Identify the slow downstream
grep "TIMEOUT\|timed out" mule_ee.log | awk -F'/' '{print $3}' | sort | uniq -c | sort -rn

# 2. Check IO thread saturation
grep "io\." dump.txt | grep -c "TIMED_WAITING"

# 3. Test the slow downstream directly
curl -w "Total: %{time_total}s\n" -o /dev/null https://slow-service.example.com/health
```

**Root cause:** No circuit breaker pattern. All IO threads consumed by one slow service, starving all other services.

**Fix:** Add response timeouts, implement circuit breaker (Until Successful with max retries + error handler that returns cached/default response).

```xml
<try>
    <http:request config-ref="Backend" method="GET" path="/data"
        responseTimeout="5000"/>
    <error-handler>
        <on-error-continue type="HTTP:TIMEOUT">
            <set-payload value='#[output application/json --- { status: "degraded", data: [] }]'/>
        </on-error-continue>
    </error-handler>
</try>
```

**Time to resolve:** Immediate (add timeouts), 1-2 hours (circuit breaker implementation).

---

### Incident 4: Connection Pool Exhaustion

**Alert:** `Cannot acquire connection from pool` errors.

**Symptoms:**
- Specific connector fails (database, HTTP, SFTP)
- Other connectors continue working
- Thread dump shows multiple threads waiting on `getConnection`

**Diagnostic runbook:**
```bash
# 1. Identify which pool
grep -i "pool\|connection" mule_ee.log | grep -i "exhaust\|timeout\|cannot" | head -10

# 2. Count waiting threads for that pool
grep -c "HikariPool\|getConnection\|borrowObject" dump.txt
```

**Root cause:** Pool too small for concurrency, leaked connections, or downstream too slow to release connections.

**Fix:** See [Connection Pool Sizing](../connection-pool-sizing/).

**Time to resolve:** 15-30 minutes.

---

### Incident 5: Deployment Failure

**Alert:** Deployment stuck in "Deploying" state or fails with error.

**Symptoms:**
- CloudHub shows "Deployment failed"
- Application shows "Starting" for more than 5 minutes
- Previous version was undeployed but new version won't start

**Diagnostic runbook:**
```bash
# 1. Check deployment status
anypoint-cli runtime-mgr:application:describe <app-name>

# 2. Check logs during startup
anypoint-cli runtime-mgr:application:tail-logs <app-name> | head -100

# 3. Check for common startup failures
grep -i "error\|exception\|failed" startup_logs.txt | head -20
```

**Root cause:** See [Deployment Failure Common Causes](../deployment-failure-common-causes/) for the 15 most common causes.

**Time to resolve:** 15-60 minutes depending on cause.

---

### Incident 6: SSL/TLS Certificate Expiry

**Alert:** `PKIX path building failed` or `SSL handshake failed`.

**Symptoms:**
- All HTTPS calls to a specific host fail
- Error: `sun.security.validator.ValidatorException: PKIX path building failed`
- Worked yesterday, broken today

**Diagnostic runbook:**
```bash
# 1. Check certificate expiry
echo | openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null | openssl x509 -noout -dates

# 2. Check Mule's truststore
keytool -list -keystore $MULE_HOME/conf/cacerts -storepass changeit | grep -i "api.example.com"

# 3. Check if intermediate CA is missing
openssl s_client -connect api.example.com:443 -showcerts 2>/dev/null | grep "Certificate chain" -A 20
```

**Root cause:** Certificate expired, intermediate CA missing from truststore, or certificate renewed with new CA.

**Fix:**
```bash
# Import the new certificate
keytool -import -trustcacerts -alias api-example \
  -file /path/to/new-cert.pem \
  -keystore $MULE_HOME/conf/cacerts \
  -storepass changeit

# Restart Mule
$MULE_HOME/bin/mule restart
```

**Time to resolve:** 15-30 minutes.

---

### Incident 7: Anypoint MQ Message Backlog

**Alert:** Queue depth growing, consumers not keeping up.

**Symptoms:**
- Messages accumulate in the queue
- Consumer application appears healthy
- No errors in consumer logs

**Diagnostic runbook:**
```bash
# 1. Check queue depth
anypoint-cli mq:queue:stats <queue-name> --environment <env>

# 2. Check consumer throughput
grep "messages processed\|message received" mule_ee.log | tail -20

# 3. Check if consumer is blocked
grep "cpuLight\|io\." dump.txt | grep -c "WAITING\|BLOCKED"
```

**Root cause:** Consumer processing slower than publish rate, maxConcurrency too low, or downstream bottleneck.

**Fix:** Increase `maxConcurrency` on the Anypoint MQ subscriber, scale to multiple workers, or optimize processing logic.

**Time to resolve:** 15-30 minutes.

---

### Incident 8: Unexpected API Policy Rejection

**Alert:** Legitimate requests getting 403 or 429 responses.

**Symptoms:**
- API returns 403 Forbidden for valid clients
- Rate limiting policy triggering prematurely
- New deployment broke existing API contracts

**Diagnostic runbook:**
```bash
# 1. Check applied policies
anypoint-cli api-mgr:policy:list <api-id> --environment <env>

# 2. Check rate limit configuration
anypoint-cli api-mgr:policy:describe <api-id> <policy-id>

# 3. Check API Gateway logs for policy evaluation
grep "policy\|POLICY\|rate.limit\|throttle" mule_ee.log | tail -20
```

**Root cause:** Rate limit window misconfigured, SLA tier not assigned to client, or policy applied to wrong API version.

**Time to resolve:** 15-30 minutes.

---

### Incident 9: Batch Job Failure Mid-Process

**Alert:** Batch job started but never completed.

**Symptoms:**
- Batch job processes some records, then stops
- No error in batch logs
- Worker memory climbs during batch execution

**Diagnostic runbook:**
```bash
# 1. Check batch status
grep "batch\|Batch" mule_ee.log | tail -30

# 2. Look for OOM or thread issues during batch
grep -i "outofmemory\|thread.*exhaust" mule_ee.log

# 3. Check temp disk usage (batch uses temp files)
df -h /tmp
```

**Root cause:** OOM from accumulating records, temp disk full, or unhandled error in batch step.

**Fix:** See [Batch Performance Tuning](../batch-performance-tuning/).

**Time to resolve:** 30-60 minutes.

---

### Incident 10: Sporadic CONNECTIVITY Errors

**Alert:** Intermittent `MULE:CONNECTIVITY` errors to a downstream service.

**Symptoms:**
- 95% of requests succeed, 5% fail with connectivity error
- No pattern to failures (not time-based, not payload-based)
- Downstream service health check passes

**Diagnostic runbook:**
```bash
# 1. Count error frequency
grep "CONNECTIVITY" mule_ee.log | awk '{print $1}' | uniq -c

# 2. Check if errors correlate with specific worker
grep "CONNECTIVITY" mule_ee.log | awk '{print $3}' | sort | uniq -c

# 3. Test DNS resolution
for i in $(seq 1 10); do dig +short api.example.com; sleep 1; done

# 4. Check for connection resets
grep "Connection reset\|Broken pipe\|EOF" mule_ee.log | wc -l
```

**Root cause:** DNS round-robin returning unhealthy host, load balancer draining, firewall idle connection timeout closing pooled connections, or network micro-partitions.

**Fix:** Reduce connection pool idle timeout, add connection validation on borrow, or implement retry with exponential backoff.

```xml
<until-successful maxRetries="3" millisBetweenRetries="1000">
    <http:request config-ref="Backend" method="GET" path="/data"/>
</until-successful>
```

**Time to resolve:** 30-60 minutes to diagnose, fix depends on root cause.

---

### Incident Severity Classification

```
+----------+------------------------------+--------------------+------------------+
| Severity | Criteria                     | Response Time      | Examples         |
+----------+------------------------------+--------------------+------------------+
| P1       | Complete outage, all traffic | 15 min             | Incidents 1, 2   |
|          | affected                     |                    |                  |
+----------+------------------------------+--------------------+------------------+
| P2       | Partial outage, some traffic | 30 min             | Incidents 3, 4, 5|
|          | affected                     |                    |                  |
+----------+------------------------------+--------------------+------------------+
| P3       | Degraded performance, no     | 2 hours            | Incidents 7, 8   |
|          | data loss                    |                    |                  |
+----------+------------------------------+--------------------+------------------+
| P4       | Intermittent issues,         | Next business day  | Incidents 9, 10  |
|          | workaround available         |                    |                  |
+----------+------------------------------+--------------------+------------------+
```

### Gotchas
- **Don't restart first, diagnose first** — restarting clears the evidence (thread dumps, heap state, connection counts). Collect evidence BEFORE restarting unless the service is P1 and customer-facing.
- **Check recent deployments** — 60% of production incidents happen within 24 hours of a deployment. Always check if there was a recent change.
- **CloudHub auto-restart masks root causes** — CloudHub 1.0 automatically restarts crashed workers. The app may recover before you investigate. Check the "Restarts" count in Runtime Manager.
- **Time zones in logs** — CloudHub logs use UTC. Make sure you're searching the right time window when correlating with user-reported incident times.
- **Multiple root causes** — incidents can have compound causes. A slow downstream (Incident 3) can cause pool exhaustion (Incident 4) which causes thread starvation (Incident 1). Solve from the bottom up.

### Related
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — detailed OOM procedure
- [Thread Dump Reading Guide](../thread-dump-reading-guide/) — analyze thread dumps
- [Connection Pool Sizing](../connection-pool-sizing/) — prevent pool exhaustion
- [Deployment Failure Common Causes](../deployment-failure-common-causes/) — deployment issues
