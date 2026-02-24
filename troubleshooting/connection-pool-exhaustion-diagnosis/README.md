## Connection Pool Exhaustion Diagnosis
> Identify which pool is starved using thread dumps, JMX metrics, and debug logging

### When to Use
- Requests start timing out after the application has been running fine for a while
- Thread dump shows many threads in `WAITING` state on pool acquisition
- Logs show `Connection pool exhausted` or `Timeout waiting for connection`
- Performance degrades under load but CPU and memory look normal
- Intermittent `MULE:CONNECTIVITY` or `MULE:TIMEOUT` errors that resolve on app restart

### Diagnosis Steps

#### Step 1: Identify Which Pool Is Starved

Take a thread dump (see [Thread Dump Analysis](../thread-dump-analysis/)) and search for threads waiting on pools:

```bash
# Search for pool-related waits in thread dump
grep -A 5 "WAITING\|TIMED_WAITING" thread_dump.txt | grep -i "pool\|hikari\|connection\|grizzly"
```

**Common pool wait signatures:**

**HikariCP (Database Connection Pool):**
```
"http-listener-worker-7" WAITING
    at com.zaxxer.hikari.pool.HikariPool.getConnection(HikariPool.java:162)
    at com.zaxxer.hikari.HikariDataSource.getConnection(HikariDataSource.java:128)
```

**HTTP Requester Pool (Grizzly):**
```
"http-listener-worker-12" WAITING
    at org.glassfish.grizzly.connectionpool.SingleEndpointPool.take(SingleEndpointPool.java:287)
    at org.mule.extension.http.internal.request.grizzly.GrizzlyHttpClient.send(...)
```

**SFTP Connection Pool:**
```
"http-listener-worker-3" TIMED_WAITING
    at org.mule.extension.sftp.internal.connection.SftpConnectionProvider.connect(...)
```

#### Step 2: Check Current Pool Metrics via JMX

**Enable JMX on Mule runtime (on-prem):**
```
# wrapper.conf
wrapper.java.additional.<n>=-Dcom.sun.management.jmxremote
wrapper.java.additional.<n>=-Dcom.sun.management.jmxremote.port=9010
wrapper.java.additional.<n>=-Dcom.sun.management.jmxremote.authenticate=false
wrapper.java.additional.<n>=-Dcom.sun.management.jmxremote.ssl=false
```

**Connect with JConsole or VisualVM:**
```bash
jconsole <PID>
# Navigate to MBeans tab
```

**HikariCP JMX Metrics (MBean: com.zaxxer.hikari:type=Pool):**

| Metric | Meaning | Alert If |
|--------|---------|----------|
| `ActiveConnections` | Connections currently in use | Close to `MaximumPoolSize` |
| `IdleConnections` | Connections waiting in pool | 0 when `ActiveConnections` is maxed |
| `TotalConnections` | Active + Idle | Less than `MaximumPoolSize` (can't create more) |
| `ThreadsAwaitingConnection` | Threads blocked waiting for a connection | > 0 for extended periods |
| `ConnectionTimeout` | Configured timeout (ms) | N/A — reference value |

**If you can't use JMX, check via log4j debug logging (Step 3).**

#### Step 3: Enable Pool Debug Logging

**Add to your `log4j2.xml` (temporarily — remove after diagnosis):**

```xml
<!-- HikariCP pool stats (logs every 30 seconds by default) -->
<AsyncLogger name="com.zaxxer.hikari" level="DEBUG" />
<AsyncLogger name="com.zaxxer.hikari.pool.HikariPool" level="DEBUG" />

<!-- HTTP requester pool -->
<AsyncLogger name="org.glassfish.grizzly.connectionpool" level="DEBUG" />
<AsyncLogger name="org.mule.extension.http.internal.request" level="DEBUG" />

<!-- Mule connection pooling framework -->
<AsyncLogger name="org.mule.runtime.core.internal.connection" level="DEBUG" />

<!-- SFTP connection pool -->
<AsyncLogger name="org.mule.extension.sftp" level="DEBUG" />
```

**What to look for in the logs:**

```
# HikariCP pool stats (logged periodically)
HikariPool-1 - Pool stats (total=10, active=10, idle=0, waiting=23)
                                      ^^^^^^^^^^^^       ^^^^^^^^^^
                                      ALL IN USE         23 THREADS BLOCKED
```

```
# HTTP requester pool exhaustion
WARN  GrizzlyHttpClient - Connection pool to api.example.com:443 is full
      (max=5, active=5, pending=12)
```

#### Step 4: Identify the Root Cause

**Cause 1: Pool size too small for load**

```xml
<!-- DEFAULT database pool size is often 5-10. For production: -->
<db:config name="Database_Config">
    <db:my-sql-connection host="${db.host}" port="${db.port}" database="${db.name}"
                          user="${db.user}" password="${db.password}">
        <db:pooling-profile maxPoolSize="20"
                            minPoolSize="5"
                            acquireIncrement="2"
                            maxWait="10"
                            maxWaitUnit="SECONDS" />
    </db:my-sql-connection>
</db:config>

<!-- DEFAULT HTTP requester pool is 5 per host. For production: -->
<http:request-config name="HTTP_Request_Config">
    <http:request-connection host="${api.host}" port="443" protocol="HTTPS">
        <http:client-socket-properties connectionTimeout="10000" />
    </http:request-connection>
</http:request-config>
<!-- Set max connections via system property: -Dmule.http.client.maxConnections=20 -->
```

**Cause 2: Leaked connections (not returned to pool)**

```java
// LEAKY: connection borrowed but never returned if exception thrown
Connection conn = dataSource.getConnection();
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery("SELECT ...");
// process results...
conn.close();  // NEVER REACHED if exception thrown above

// FIX: use try-with-resources
try (Connection conn = dataSource.getConnection();
     Statement stmt = conn.createStatement();
     ResultSet rs = stmt.executeQuery("SELECT ...")) {
    // process results
}  // auto-closed even on exception
```

**In Mule XML — leaked connections from error handlers that don't close:**
```xml
<!-- LEAKY: if the DB select throws, the connection may not be returned -->
<db:select config-ref="Database_Config">
    <db:sql>SELECT * FROM orders WHERE id = :id</db:sql>
    <db:input-parameters>#[{ id: attributes.queryParams.id }]</db:input-parameters>
</db:select>

<!-- FIX: ensure error handlers don't swallow DB errors silently -->
<error-handler>
    <on-error-propagate type="DB:CONNECTIVITY">
        <logger level="ERROR" message="DB connection error: #[error.description]" />
    </on-error-propagate>
</error-handler>
```

**Cause 3: Slow downstream service holding connections open**

```bash
# Check average response time from the downstream service
# In logs, look for:
grep "response time\|responseTime\|duration" mule_ee.log | tail -20

# If downstream is slow, connections stay borrowed longer, pool fills up faster
# Fix: set aggressive timeouts
```

```xml
<http:request-config name="HTTP_Request_Config">
    <http:request-connection host="${api.host}" port="443" protocol="HTTPS">
        <http:client-socket-properties
            connectionTimeout="5000"
            sendTimeout="10000"
            receiveTimeout="10000" />
    </http:request-connection>
</http:request-config>
```

#### Step 5: Right-Size the Pool

**Pool sizing formula:**
```
Optimal pool size = (Number of concurrent requests) × (Average hold time per request / Average request duration)

Example:
- 50 concurrent API requests
- Each request holds a DB connection for 200ms
- Each request takes 500ms total
- Pool size = 50 × (200/500) = 20 connections

Add 20% buffer: 20 × 1.2 = 24 connections
```

**Database pool sizing rule of thumb:**
```
connections = ((core_count * 2) + effective_spindle_count)

For cloud databases (no spindles):
connections = (vCPU_count * 2) + 1
```

**Warning: More is NOT always better.** Each idle database connection consumes ~5-10MB of RAM on the database server. 100 idle connections from 10 Mule workers = 5-10GB of wasted DB memory.

### How It Works
1. Connection pools maintain a set of pre-established connections to avoid the overhead of creating new ones per request
2. When a flow needs a connection, it borrows one from the pool; when done, it returns it
3. If all connections are in use, the requesting thread blocks (WAITING) until one is returned or the timeout expires
4. HikariCP (used by Mule's DB connector) tracks active, idle, total, and waiting counts via JMX
5. The HTTP requester uses Grizzly's connection pool with per-host limits

### Gotchas
- **Default pool sizes are almost always too small for production** — HikariCP defaults to 10, HTTP requester defaults to 5 per host. These are fine for development but will exhaust under real load.
- **Leaked connections are the #1 cause** — even with a large pool, if connections aren't returned (due to exceptions, missing close(), or error handler issues), the pool will eventually exhaust. Enable HikariCP leak detection:
  ```xml
  <db:pooling-profile maxPoolSize="20" leakDetectionThreshold="60000" />
  ```
  This logs a warning if a connection is held for more than 60 seconds.
- **Database connection limits** — your pool size per Mule worker × number of workers must not exceed the database's max_connections. 4 workers × 20 connections = 80 connections to the DB.
- **HTTP requester pool is per host:port** — if you call 5 different APIs, you have 5 separate pools. Exhaustion of one pool doesn't affect others.
- **Pool exhaustion looks like timeouts** — the error message may say `MULE:TIMEOUT` or `Connection timed out`, not `Pool exhausted`. Check thread dumps to confirm.
- **Restarting the app is a temporary fix** — it resets all pools, but the leak or undersizing will cause the same problem again. Find the root cause.
- **Don't set pool size too high on CloudHub** — each connection uses memory. On a 0.1 vCore worker (512MB heap), 50 DB connections can consume a significant portion of available memory.

### Related
- [Thread Dump Analysis](../thread-dump-analysis/) — how to take and read thread dumps that reveal pool exhaustion
- [Common Error Messages Decoded](../common-error-messages-decoded/) — error messages caused by pool exhaustion
- [Memory Leak Detection Step-by-Step](../memory-leak-detection-step-by-step/) — when pool objects leak into heap
- [HikariCP Pool Sizing](../../performance/connections/db-hikaricp-pool/) — optimal database pool configuration
- [HTTP Connection Pool](../../performance/connections/http-connection-pool/) — HTTP requester pool tuning
- [Connection Timeouts](../../performance/connections/connection-timeouts/) — timeout configuration
