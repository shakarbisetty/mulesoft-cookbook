## Thread Dump Reading Guide
> Practical UBER thread pool analysis for Mule 4 — how to read, interpret, and act on thread dumps

### When to Use
- Application is slow but CPU and memory look normal
- Some API requests hang while others succeed
- CloudHub shows "Application not responding" intermittently
- You have a thread dump file but don't know how to read it
- Need to identify which component is blocking the flow

### The Problem

Mule 4 uses the UBER (Unified Backend Event Reactor) thread pool model introduced in runtime 4.3+. Unlike Mule 3 which had separate thread pools per connector, Mule 4 uses three shared pools. Understanding which pool is starved and why requires knowing the UBER model, reading thread states, and correlating threads across multiple dumps.

### The UBER Thread Pool Model

```
+-------------------------------------------------------------------+
|                     UBER Thread Pool Architecture                  |
+-------------------------------------------------------------------+
|                                                                   |
|  +-----------------+  +-----------------+  +-----------------+    |
|  |   CPU_LITE      |  |      IO         |  |   CPU_INTENSIVE |    |
|  |   (cpu-light)   |  |   (io-thread)   |  |  (cpu-intensive)|    |
|  +-----------------+  +-----------------+  +-----------------+    |
|  | Default: 2*cores|  | Default: cores  |  | Default: 2*cores|    |
|  | Max: 2*cores    |  | (grows on       |  | Max: 2*cores    |    |
|  |                 |  |  demand)        |  |                 |    |
|  | For: fast, non- |  | For: blocking   |  | For: heavy      |    |
|  | blocking ops    |  | I/O operations  |  | computation     |    |
|  +-----------------+  +-----------------+  +-----------------+    |
|        |                    |                     |               |
|  Flow start/end      DB queries             DataWeave on         |
|  Lightweight DW      HTTP requests          large payloads       |
|  Choice router       File operations        Custom Java with     |
|  Set Variable        JMS/AMQP               heavy processing     |
|  Logger              SFTP/FTP                                    |
|                      SMTP                                        |
+-------------------------------------------------------------------+
```

### How to Take Thread Dumps

```bash
# On-prem: take 3 dumps, 10 seconds apart
PID=$(pgrep -f "MuleContainerBootstrap" | head -1)
for i in 1 2 3; do
  jcmd $PID Thread.print > "dump_${i}_$(date +%H%M%S).txt"
  echo "Dump $i at $(date)"
  [ $i -lt 3 ] && sleep 10
done

# Java 17+ alternative
for i in 1 2 3; do
  jcmd $PID Thread.dump_to_file -format=json "dump_${i}.json"
  [ $i -lt 3 ] && sleep 10
done
```

### Reading a Thread Dump: Line by Line

**Thread header:**
```
"[MuleRuntime].cpuLight.06" #87 daemon prio=5 os_prio=0 cpu=245.12ms elapsed=3847.21s
   tid=0x00007f4a3c012800 nid=0x5e java.lang.Thread.State: RUNNABLE
```

Decoded:
```
"[MuleRuntime].cpuLight.06"    <- Pool name (cpuLight) and thread number (06)
#87                            <- JVM thread ID
daemon                         <- Daemon thread (won't prevent JVM shutdown)
prio=5                         <- Java priority (1-10, 5 is normal)
cpu=245.12ms                   <- CPU time consumed by this thread
elapsed=3847.21s               <- Wall-clock time since thread creation
tid=0x00007f4a3c012800         <- Java thread ID (hex)
nid=0x5e                       <- Native OS thread ID (hex) — convert: printf '%d\n' 0x5e = 94
Thread.State: RUNNABLE         <- Current state (see table below)
```

**Thread states explained:**

| State | What It Means | When It's a Problem |
|-------|--------------|---------------------|
| RUNNABLE | Executing or ready to execute | Only if CPU is pegged at 100% |
| BLOCKED | Waiting for a synchronized lock | If same thread blocked across 3 dumps |
| WAITING | Parked indefinitely (LockSupport.park) | If all pool threads are WAITING |
| TIMED_WAITING | Waiting with timeout (sleep, poll) | Almost never — this is normal |

### Pool Analysis Cheat Sheet

**Count threads per pool:**
```bash
grep "^\"\[MuleRuntime\]" dump_1.txt | \
  sed 's/.*\[MuleRuntime\]\.\([^.]*\)\..*/\1/' | \
  sort | uniq -c | sort -rn
```

Expected output:
```
     16 cpuLight       <- 2 * 8 cores = 16 (normal)
      8 io             <- 8 cores base (normal)
     16 cpuIntensive   <- 2 * 8 cores = 16 (normal)
      4 scheduler      <- scheduler threads (normal)
```

**Count thread states per pool:**
```bash
grep -A 1 "^\"\[MuleRuntime\]\.cpuLight" dump_1.txt | \
  grep "Thread.State" | sort | uniq -c
```

Problem indicators:
```
     16 WAITING        <- ALL cpuLight threads waiting = pool exhaustion
      0 RUNNABLE       <- No threads processing = complete starvation
```

### Diagnostic Scenarios

#### Scenario 1: CPU_LITE Pool Exhaustion

**Symptom:** All `cpuLight` threads show WAITING or BLOCKED.

```
"[MuleRuntime].cpuLight.01" BLOCKED
    at org.mule.runtime.core.internal.processor...
    - waiting to lock <0x000000076ab01234>
    at org.mule.runtime.core.internal.construct.FlowBackPressureHandler...

"[MuleRuntime].cpuLight.02" BLOCKED
    at org.mule.runtime.core.internal.processor...
    - waiting to lock <0x000000076ab01234>
```

**Root cause:** A blocking operation (DB query, HTTP call, file I/O) running on a CPU_LITE thread. This blocks the entire pool because CPU_LITE has limited threads and is meant for non-blocking work only.

**Fix:** Ensure blocking operations use the IO pool by configuring `maxConcurrency` or wrapping in an async scope:
```xml
<!-- Move blocking work to IO pool -->
<flow name="myFlow" maxConcurrency="8">
    <http:listener config-ref="HTTP" path="/api"/>
    <!-- CPU_LITE: fast operations -->
    <set-variable variableName="requestId" value="#[uuid()]"/>

    <!-- IO pool: blocking operations -->
    <db:select config-ref="Database">
        <db:sql>SELECT * FROM orders WHERE id = :id</db:sql>
        <db:input-parameters>#[{id: vars.requestId}]</db:input-parameters>
    </db:select>
</flow>
```

#### Scenario 2: IO Pool Saturation

**Symptom:** Many IO threads show TIMED_WAITING on HTTP connection.

```
"[MuleRuntime].io.12" TIMED_WAITING
    at sun.misc.Unsafe.park(Native Method)
    at java.util.concurrent.locks.LockSupport.parkNanos(LockSupport.java:215)
    at com.ning.http.client.providers.grizzly.GrizzlyAsyncHttpProvider...
```

**Root cause:** Downstream service is slow, consuming all IO threads waiting for responses.

**Fix:** Add response timeouts and configure circuit breaker:
```xml
<http:request-config name="Slow_Service">
    <http:request-connection host="slow.example.com" port="443" protocol="HTTPS">
        <http:client-socket-properties>
            <sockets:tcp-client-socket-properties
                connectionTimeout="5000"
                clientTimeout="10000"/>
        </http:client-socket-properties>
    </http:request-connection>
</http:request-config>
```

#### Scenario 3: Deadlock

**Symptom:** Thread dump explicitly reports deadlock at the bottom.

```
Found one Java-level deadlock:
=============================
"[MuleRuntime].cpuLight.01":
  waiting to lock 0x000000076ab01234
  which is held by "[MuleRuntime].cpuLight.05"
"[MuleRuntime].cpuLight.05":
  waiting to lock 0x000000076ab05678
  which is held by "[MuleRuntime].cpuLight.01"
```

**Fix:** Deadlocks in Mule flows are almost always caused by custom Java components using `synchronized`. Replace with `java.util.concurrent.locks.ReentrantLock` with `tryLock(timeout)`.

### Comparing Multiple Dumps

```bash
# For each dump, extract cpuLight thread names and states
for f in dump_*.txt; do
  echo "=== $f ==="
  grep -A 1 "cpuLight" "$f" | grep "Thread.State" | sort | uniq -c
done

# Compare specific thread across dumps:
for f in dump_*.txt; do
  echo "=== $f ==="
  grep -A 15 "cpuLight.01" "$f" | head -10
done
```

**Interpretation:**
```
Thread in same state + same stack across all 3 dumps:
  -> Permanently stuck (deadlock, infinite loop, or waiting on unresponsive resource)

Thread in different states across dumps:
  -> Normal operation, thread is processing different requests

Thread oscillating between RUNNABLE and BLOCKED:
  -> Lock contention (high concurrency on a shared resource)
```

### Gotchas
- **Thread names changed between Mule 4.2 and 4.3+** — before 4.3, threads were named by connector (e.g., `http-listener-worker-1`). After 4.3 with UBER, they're `[MuleRuntime].cpuLight.NN`. Make sure you know your runtime version.
- **Custom thread pools don't show as `[MuleRuntime]`** — if you configured a custom thread pool in a `<scheduler>`, those threads have different names. Grep for your custom pool name.
- **`TIMED_WAITING` on scheduler threads is normal** — Mule's internal schedulers (cron, polling) sit in TIMED_WAITING between executions. Don't count these as problems.
- **IO pool can grow beyond initial size** — unlike CPU_LITE which is fixed at 2*cores, the IO pool grows dynamically. Finding 50+ IO threads isn't necessarily wrong if you have 50 concurrent blocking operations.
- **`nid` is crucial for correlating with `top -H`** — if you see high CPU, run `top -H -p <PID>`, find the thread with high CPU, convert its OS thread ID to hex, and search for `nid=0x<hex>` in the dump.
- **CloudHub thread dumps may be incomplete** — if the app is truly hung, the Runtime Manager UI may timeout trying to collect the dump. Use Anypoint CLI with a longer timeout.

### Quick Reference: Convert nid to OS Thread

```bash
# Find the hot thread in top
top -H -p <PID>
# Note the TID column (e.g., 12345)

# Convert to hex
printf '0x%x\n' 12345
# Output: 0x3039

# Search thread dump
grep "nid=0x3039" dump_1.txt
```

### Related
- [Thread Pool Component Mapping](../thread-pool-component-mapping/) — which pool each Mule component uses
- [Thread Dump Analysis](../thread-dump-analysis/) — foundational thread dump recipe
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — when threads wait on connection pools
- [Flow Profiling Methodology](../flow-profiling-methodology/) — find the slowest component
