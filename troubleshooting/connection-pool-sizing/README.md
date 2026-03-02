## Connection Pool Sizing
> The math behind optimal pool configuration for HTTP, database, and SFTP connections

### When to Use
- Getting "Connection pool exhausted" or "Timeout waiting for connection" errors
- Application slows down under load but CPU and memory are fine
- Thread dump shows multiple threads waiting on `getConnection()`
- Need to calculate the right pool size for your vCore and concurrency
- Deploying a new integration and want to get pool sizing right the first time

### The Problem

Connection pools that are too small cause thread starvation — requests queue up waiting for a connection. Pools that are too large waste memory and can overwhelm downstream services with more concurrent connections than they can handle. The right size depends on your concurrency, response times, and vCore allocation.

### The Universal Pool Sizing Formula

```
Optimal Pool Size = (Concurrent Requests) x (Avg Response Time / 1000) x Safety Multiplier

Where:
  Concurrent Requests = max simultaneous requests your app handles
  Avg Response Time   = downstream service response time in milliseconds
  Safety Multiplier   = 1.5 (accounts for bursts and variance)

Example:
  50 concurrent requests x (200ms / 1000) x 1.5 = 15 connections
```

**But there's a ceiling:**
```
Max Sensible Pool Size = IO Thread Pool Size x 2

Because: each IO thread can only use one connection at a time.
If you have 8 IO threads, having 50 connections is wasteful.
```

### Pool Sizing by Component

#### HTTP Requester Connection Pool

```xml
<http:request-config name="Backend_Service">
    <http:request-connection host="api.example.com" port="443" protocol="HTTPS">
        <http:client-socket-properties>
            <sockets:tcp-client-socket-properties
                connectionTimeout="5000"
                clientTimeout="30000"/>
        </http:client-socket-properties>
    </http:request-connection>
    <!-- Connection pool settings -->
    <http:request-connection>
        <!-- Max connections to this host -->
        <pooling-profile
            maxActive="20"
            maxIdle="10"
            maxWait="30000"
            exhaustedAction="WHEN_EXHAUSTED_WAIT"
            initialisationPolicy="INITIALISE_NONE"/>
    </http:request-connection>
</http:request-config>
```

**Sizing guide:**

```
+----------+------------------+------------------+------------------+
| vCore    | Low Latency      | Medium Latency   | High Latency     |
|          | (<100ms response) | (100-500ms)      | (>500ms)         |
+----------+------------------+------------------+------------------+
| 0.1-0.2  | maxActive=5      | maxActive=5      | maxActive=3      |
|          | maxIdle=2        | maxIdle=3        | maxIdle=2        |
+----------+------------------+------------------+------------------+
| 0.5      | maxActive=10     | maxActive=8      | maxActive=5      |
|          | maxIdle=4        | maxIdle=4        | maxIdle=3        |
+----------+------------------+------------------+------------------+
| 1.0      | maxActive=20     | maxActive=15     | maxActive=10     |
|          | maxIdle=8        | maxIdle=6        | maxIdle=5        |
+----------+------------------+------------------+------------------+
| 2.0      | maxActive=30     | maxActive=25     | maxActive=15     |
|          | maxIdle=10       | maxIdle=8        | maxIdle=6        |
+----------+------------------+------------------+------------------+
| 4.0      | maxActive=50     | maxActive=40     | maxActive=25     |
|          | maxIdle=15       | maxIdle=12       | maxIdle=10       |
+----------+------------------+------------------+------------------+
```

#### Database Connection Pool (Generic JDBC / HikariCP)

Mule's Database connector uses a connection pool internally.

```xml
<db:config name="Database_Config">
    <db:my-sql-connection host="db.example.com" port="3306"
        database="mydb" user="app_user" password="${db.password}">
        <db:pooling-profile
            maxPoolSize="10"
            minPoolSize="2"
            acquireIncrement="2"
            maxIdleTime="600"
            acquireTimeout="30"/>
    </db:my-sql-connection>
</db:config>
```

**The HikariCP formula (if using custom HikariCP):**
```
Pool Size = (2 * number_of_cores) + number_of_disks

For a typical CloudHub deployment (no direct disk access):
  1 vCore (2 cores):  (2 * 2) + 1 = 5 connections
  2 vCore (4 cores):  (2 * 4) + 1 = 9 connections
  4 vCore (8 cores):  (2 * 8) + 1 = 17 connections
```

**Key parameters explained:**

| Parameter | What It Does | Recommendation |
|-----------|-------------|----------------|
| maxPoolSize | Max connections open simultaneously | Start with formula, tune from there |
| minPoolSize | Connections kept open even when idle | 2-3 (enough for baseline traffic) |
| acquireIncrement | How many connections to add when pool grows | 2 (not too aggressive) |
| maxIdleTime | Seconds before idle connection is closed | 300-600 (match DB idle timeout) |
| acquireTimeout | Seconds to wait for a connection before failing | 30 (fail fast, don't hang) |

#### SFTP Connection Pool

```xml
<sftp:config name="SFTP_Config">
    <sftp:connection host="sftp.example.com" port="22"
        username="integrator" password="${sftp.password}">
        <pooling-profile
            maxActive="5"
            maxIdle="2"
            maxWait="30000"
            exhaustedAction="WHEN_EXHAUSTED_WAIT"/>
    </sftp:connection>
</sftp:config>
```

SFTP connections are expensive (SSH handshake + authentication). Keep pools small (3-5 connections) and reuse aggressively.

### Diagnostic Steps: Pool Exhaustion

#### Step 1: Confirm Pool Exhaustion

Look for these log messages:
```
# HTTP Requester pool
"Timeout waiting for connection from pool"
"Connection pool shut down"

# Database pool
"Cannot acquire connection from pool"
"Pool exhausted - could not acquire connection"
"HikariPool-1 - Connection is not available, request timed out after 30000ms"

# Generic pool
"MULE:CONNECTIVITY" error type
```

#### Step 2: Measure Current Pool Usage

```bash
# Thread dump: count threads waiting on pool
grep -c "getConnection\|acquireConnection\|borrowObject" dump.txt

# JMX (if enabled): query HikariCP metrics
# Add to JVM args: -Dcom.mchange.v2.log.MLog=com.mchange.v2.log.jdk14logging.Jdk14MLog
```

#### Step 3: Correlate with Downstream Response Times

```bash
# Search logs for slow responses
grep "response.*time\|elapsed\|duration" mule_ee.log | \
  awk '{print $NF}' | sort -n | tail -20
```

If downstream response times have increased, the pool may be the right size but the downstream is the bottleneck. Increasing pool size in this case will only push more load onto an already-struggling service.

### The Exhausted Action Decision

```xml
<!-- What happens when all connections are in use? -->
<pooling-profile exhaustedAction="WHEN_EXHAUSTED_WAIT"/>
```

| Action | Behavior | When to Use |
|--------|----------|-------------|
| WHEN_EXHAUSTED_WAIT | Block until a connection is returned | Default. Request queues but eventually succeeds. |
| WHEN_EXHAUSTED_FAIL | Throw error immediately | When you want fast failure for circuit breakers. |
| WHEN_EXHAUSTED_GROW | Create a new connection beyond maxActive | Dangerous. Can overwhelm downstream. |

### Gotchas
- **Pool size > downstream capacity = DDoS your own backend** — if the database can handle 20 concurrent queries and you set maxActive=50, you'll overload the database during traffic spikes.
- **maxIdle too high = stale connections** — connections sitting idle for too long may be closed by the server (firewall, DB timeout). Set `maxIdleTime` shorter than the server's idle timeout.
- **maxIdle too low = connection churn** — if idle connections are closed aggressively, every request pays the cost of establishing a new connection (TCP + TLS handshake + authentication).
- **Connection leak detection** — if pool exhausts but the app isn't under high load, connections are being leaked. Check that error handlers aren't skipping connection release. Some connectors require explicit close operations.
- **CloudHub shared IP pool** — all your workers share the same outbound IP range. Downstream firewalls may rate-limit by IP, not by application. Two applications with 20-connection pools each = 40 connections from the same IP.
- **DNS caching affects pool behavior** — Java caches DNS by default (30 seconds for positive, forever for negative). If a downstream host changes IP, pooled connections to the old IP will fail until the cache expires. Set `-Dnetworkaddress.cache.ttl=60`.
- **TLS session resumption** — HTTPS connection pools benefit from TLS session resumption. Keeping minPoolSize >= 1 ensures the TLS session cache stays warm.

### Related
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — when the pool is already exhausted
- [Thread Pool Component Mapping](../thread-pool-component-mapping/) — which thread pool each component uses
- [Timeout Hierarchy](../timeout-hierarchy/) — understanding the timeout layers
- [504 Gateway Timeout Diagnosis](../504-gateway-timeout-diagnosis/) — when pool wait times cause gateway timeouts
