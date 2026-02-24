## Thread Dump Analysis
> Take and interpret JVM thread dumps to diagnose deadlocks, pool exhaustion, and blocked threads in Mule runtime

### When to Use
- Application appears frozen or unresponsive but the process is still running
- API response times spike suddenly with no deployment change
- CloudHub worker shows high CPU but flows aren't completing
- Suspected deadlock between database connections and HTTP threads
- Connection pool exhaustion warnings in logs

### Diagnosis Steps

#### Step 1: Take a Thread Dump

**On CloudHub (Runtime Manager UI):**
1. Navigate to Runtime Manager → Applications → your app
2. Click the application name to open details
3. Go to the **Insight** tab (or **Settings → Thread Dump** on older versions)
4. Click **Download Thread Dump**
5. Save the `.txt` file locally

**On CloudHub via Anypoint CLI:**
```bash
anypoint-cli runtime-mgr:application:download-thread-dump <app-name> <output-file>
```

**On-Prem with jstack (recommended):**
```bash
# Find the Mule JVM process ID
ps aux | grep -i mule | grep -v grep

# Take thread dump (run as same user as the Mule process)
jstack -l <PID> > thread_dump_$(date +%Y%m%d_%H%M%S).txt
```

**On-Prem with kill -3 (when jstack isn't available):**
```bash
# Sends SIGQUIT — dumps threads to stdout (check wrapper.log or console output)
kill -3 <PID>
```

**CRITICAL: Take 3 dumps, 10 seconds apart:**
```bash
for i in 1 2 3; do
  jstack -l <PID> > thread_dump_${i}.txt
  echo "Dump $i taken at $(date)"
  sleep 10
done
```

Three dumps let you distinguish between a thread that's permanently stuck vs. temporarily waiting.

#### Step 2: Understand Thread States

| State | Meaning | Concern Level |
|-------|---------|---------------|
| `RUNNABLE` | Thread is executing or ready to execute | Normal unless CPU is pegged |
| `BLOCKED` | Waiting to acquire a monitor lock | High — another thread holds the lock |
| `WAITING` | Waiting indefinitely (e.g., `Object.wait()`, `LockSupport.park()`) | High if many threads in this state |
| `TIMED_WAITING` | Waiting with a timeout (e.g., `Thread.sleep()`, `Object.wait(timeout)`) | Normal for polling threads |

#### Step 3: Read the Thread Dump

**Sample thread dump snippet (annotated):**
```
"http-listener-worker-1" #42 daemon prio=5 os_prio=0 tid=0x00007f... nid=0x2a1a
   java.lang.Thread.State: BLOCKED (on object monitor)          ← THIS THREAD IS STUCK
        at com.mulesoft.service.MyProcessor.process(MyProcessor.java:87)
        - waiting to lock <0x00000000c0035a08> (a java.util.HashMap)   ← WANTS THIS LOCK
        - locked <0x00000000c0035b10> (a java.util.ArrayList)          ← ALREADY HOLDS THIS
        at org.mule.runtime.core.internal.processor.chain...

"http-listener-worker-3" #44 daemon prio=5 os_prio=0 tid=0x00007f... nid=0x2a1c
   java.lang.Thread.State: BLOCKED (on object monitor)          ← ALSO STUCK
        at com.mulesoft.service.MyProcessor.update(MyProcessor.java:112)
        - waiting to lock <0x00000000c0035b10> (a java.util.ArrayList) ← WANTS THE LOCK worker-1 HOLDS
        - locked <0x00000000c0035a08> (a java.util.HashMap)            ← HOLDS THE LOCK worker-1 WANTS

Found one Java-level deadlock:                                   ← JVM DETECTED IT
=============================
"http-listener-worker-1":
  waiting to lock monitor 0x00007f..., which is held by "http-listener-worker-3"
"http-listener-worker-3":
  waiting to lock monitor 0x00007f..., which is held by "http-listener-worker-1"
```

#### Step 4: Identify Common Patterns

**Pattern: Deadlock (as above)**
- Look for the `Found one Java-level deadlock` section at the bottom of the dump
- Two or more threads each holding a lock the other needs
- Fix: ensure consistent lock ordering, or use `java.util.concurrent` locks with `tryLock(timeout)`

**Pattern: Pool Exhaustion (all threads WAITING on a pool)**
```
"http-listener-worker-1" WAITING
    at sun.misc.Unsafe.park(Native Method)
    at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
    at com.zaxxer.hikari.pool.HikariPool.getConnection(HikariPool.java:162)  ← WAITING FOR DB CONNECTION

"http-listener-worker-2" WAITING
    at com.zaxxer.hikari.pool.HikariPool.getConnection(HikariPool.java:162)  ← SAME

"http-listener-worker-3" WAITING
    at com.zaxxer.hikari.pool.HikariPool.getConnection(HikariPool.java:162)  ← ALL THREADS STARVED
```
- All worker threads waiting on `HikariPool.getConnection` = database connection pool is exhausted
- Fix: increase pool size, add connection timeouts, find leaked connections

**Pattern: Thread Starvation (uber pool fully occupied)**
```
# Count threads by pool name:
grep "^\"" thread_dump.txt | sed 's/".*//' | sort | uniq -c | sort -rn
```
Expected output:
```
     64  "http-listener-worker       ← all 64 slots occupied
      8  "cpu-light
      4  "io
      2  "scheduler
```

#### Step 5: Compare Across 3 Dumps

```bash
# Extract thread states from each dump
for f in thread_dump_*.txt; do
  echo "=== $f ==="
  grep "java.lang.Thread.State:" "$f" | sort | uniq -c | sort -rn
done
```

If the same threads are BLOCKED across all 3 dumps → permanent block (deadlock or resource starvation).
If threads rotate through BLOCKED/RUNNABLE → temporary contention (may resolve with tuning).

### How It Works
1. `jstack` attaches to the JVM and requests a full thread snapshot at a safe point
2. The JVM pauses briefly (usually <100ms) to collect all thread stack traces
3. Each thread's current state, lock holdings, and call stack are recorded
4. The `kill -3` approach uses the JVM's built-in signal handler to write the same data to stdout
5. CloudHub wraps this into a downloadable file via the Runtime Manager API

### Gotchas
- **Always take 3 dumps 10 seconds apart** — a single dump is a snapshot and can be misleading; comparing 3 dumps reveals whether a thread is permanently stuck or just momentarily waiting
- **Production impact is minimal but real** — the JVM pauses briefly during dump collection; on a heavily loaded system with 500+ threads, this pause can reach 200-500ms
- **`jstack` must run as the same OS user** that owns the Mule process, or as root
- **`kill -3` output goes to stdout/stderr** — check `wrapper.log`, not `mule_ee.log`
- **CloudHub thread dumps may be truncated** for very large thread counts (1000+ threads)
- **Don't confuse `TIMED_WAITING` with a problem** — scheduler threads, polling consumers, and keep-alive threads normally sit in `TIMED_WAITING`
- **On Java 17+**, use `jcmd <PID> Thread.print` instead of `jstack` for more reliable output

### Related
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — when thread dumps show all threads waiting on a pool
- [Memory Leak Detection Step-by-Step](../memory-leak-detection-step-by-step/) — when the issue is memory, not threads
- [Batch Job Failure Analysis](../batch-job-failure-analysis/) — batch-specific thread pool issues
- [HTTP Connection Pool Tuning](../../performance/connections/http-connection-pool/) — tuning the pools that threads wait on
