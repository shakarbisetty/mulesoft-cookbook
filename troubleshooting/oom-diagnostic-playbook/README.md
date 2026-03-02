## OOM Diagnostic Playbook
> From symptom to root cause in 30 minutes — a step-by-step procedure for OutOfMemoryError in Mule 4

### When to Use
- Application crashes with `java.lang.OutOfMemoryError` in logs
- CloudHub worker restarts unexpectedly with no visible error
- CloudHub 2.0 pod shows `OOMKilled` status
- Heap usage graph shows sawtooth pattern climbing to 100%
- Application becomes unresponsive and GC logs show continuous full GC cycles

### The Problem

OutOfMemoryError has at least 6 distinct root causes, each requiring a different fix. Developers waste hours guessing. This playbook uses a timed, systematic approach: identify the OOM type (5 min), collect evidence (10 min), isolate the root cause (10 min), apply the fix (5 min).

### The 30-Minute Clock

```
Minute 0-5:   Identify OOM type from error message
Minute 5-15:  Collect heap dump + GC logs + thread dump
Minute 15-25: Analyze evidence, isolate root cause
Minute 25-30: Apply fix or escalate with evidence
```

### Step 1: Identify the OOM Type (Minutes 0-5)

Search your logs for the exact error message:

```bash
# CloudHub: download logs from Runtime Manager, then:
grep -i "OutOfMemoryError" mule_ee.log | head -5

# On-prem:
grep -i "OutOfMemoryError" $MULE_HOME/logs/*.log | head -5
```

**Decision tree based on error message:**

```
java.lang.OutOfMemoryError: ?
         |
    +----+----+----+----+----+
    |         |         |         |         |
 Java heap  Metaspace  GC overhead  Direct   Unable to
  space                 limit     buffer    create new
    |         |       exceeded     |       native thread
    |         |         |         |         |
  Step 2A   Step 2B   Step 2C   Step 2D   Step 2E
```

### Step 2A: Java Heap Space (Most Common)

**Cause:** Application data exceeds available heap.

```bash
# Enable heap dump on OOM (add to JVM args BEFORE it happens again)
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heapdump.hprof

# If you can catch it live, take a heap dump now:
jcmd <PID> GC.heap_dump /tmp/heapdump.hprof
```

**Analyze the heap dump:**
```bash
# Quick analysis: top objects by retained size
# Using Eclipse MAT (command-line mode):
./ParseHeapDump.sh /tmp/heapdump.hprof org.eclipse.mat.api:suspects

# Or use jcmd for a quick histogram (no dump file needed):
jcmd <PID> GC.class_histogram | head -30
```

**Common culprits in Mule 4:**

| Object in Histogram | Root Cause | Fix |
|---------------------|-----------|-----|
| `byte[]` (huge) | Large payload loaded fully into memory | Enable streaming strategy |
| `char[]` / `String` (many) | String accumulation in DataWeave | Use streaming; avoid `++` in reduce |
| `HashMap$Node` (growing) | Object Store or cache unbounded | Set maxEntries and TTL |
| `WeaveValue` / `KeyValuePair` | DataWeave holding full dataset | Refactor groupBy on large sets |
| `HttpEntity` (many) | HTTP connections not consumed/closed | Always consume or close response body |

### Step 2B: Metaspace

**Cause:** Too many classes loaded (many connectors, hot redeployments leaking classloaders).

```bash
# Check metaspace usage
jcmd <PID> VM.native_memory summary | grep -A 5 "Class"

# Check class count
jcmd <PID> VM.classloader_stats | head -20
```

**Fix:**
```
# Increase metaspace limit in JVM args:
-XX:MaxMetaspaceSize=512m

# If caused by redeployment leaks, restart the worker periodically
# or fix the classloader leak (often a JDBC driver registering itself globally)
```

### Step 2C: GC Overhead Limit Exceeded

**Cause:** JVM spending >98% of time in garbage collection recovering <2% of heap.

This means the heap IS large enough to avoid instant OOM but NOT large enough for the workload. The JVM is in a death spiral.

```bash
# Confirm with GC logs
grep "Full GC" gc.log | tail -10
# If you see Full GC every few seconds -> confirmed
```

**Fix:** Same as 2A (reduce memory usage or increase heap), but this variant tells you the app is right at the edge.

### Step 2D: Direct Buffer Memory

**Cause:** NIO direct buffers exhausted. Common with many concurrent HTTP connections.

```bash
# Check direct buffer usage
jcmd <PID> VM.native_memory summary | grep -A 3 "Internal"
```

**Fix:**
```
# Increase direct memory limit:
-XX:MaxDirectMemorySize=512m

# Or reduce concurrent HTTP connections in your HTTP requester config
```

### Step 2E: Unable to Create New Native Thread

**Cause:** OS thread limit reached. Each Mule thread consumes ~512 KB of native stack.

```bash
# Check current thread count
jcmd <PID> Thread.print | grep "^\"" | wc -l

# Check OS limits
ulimit -u          # max user processes
cat /proc/sys/kernel/threads-max
```

**Fix:**
```bash
# Increase OS limits:
ulimit -u 8192

# Or reduce thread pools in Mule:
# In your Mule app's scheduler config, reduce maxConcurrency
```

### Step 3: Collect Evidence (Minutes 5-15)

Run this collection script on-prem (on CloudHub, download what you can from Runtime Manager):

```bash
#!/bin/bash
DUMP_DIR="/tmp/oom_evidence_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DUMP_DIR"
PID=$(pgrep -f "mule" | head -1)

echo "Collecting evidence for PID $PID into $DUMP_DIR"

# 1. Heap dump (skip if already have one from -XX:+HeapDumpOnOutOfMemoryError)
jcmd $PID GC.heap_dump "$DUMP_DIR/heap.hprof" 2>/dev/null || echo "Heap dump failed"

# 2. Thread dump (3x, 10s apart)
for i in 1 2 3; do
  jcmd $PID Thread.print > "$DUMP_DIR/threads_$i.txt"
  sleep 10
done

# 3. Class histogram
jcmd $PID GC.class_histogram > "$DUMP_DIR/class_histogram.txt"

# 4. Native memory (if tracking enabled)
jcmd $PID VM.native_memory summary > "$DUMP_DIR/native_memory.txt" 2>/dev/null

# 5. GC log (copy last 10 MB)
tail -c 10000000 /tmp/gc.log > "$DUMP_DIR/gc_tail.log" 2>/dev/null

# 6. System info
free -m > "$DUMP_DIR/system_memory.txt"
top -bn1 -p $PID > "$DUMP_DIR/top_snapshot.txt"

echo "Evidence collected in $DUMP_DIR"
ls -la "$DUMP_DIR"
```

### Step 4: Analyze and Isolate (Minutes 15-25)

**Check 1: Is memory growing over time, or spiking on specific requests?**
```bash
# If GC log exists, extract heap usage over time:
grep "\[gc,heap" gc.log | grep "after" | tail -50
```

- **Steady growth** = memory leak (static collections, event listeners, unclosed resources)
- **Sudden spike** = large payload or expensive transform on a specific request

**Check 2: What's consuming the heap?**
```bash
# Top 10 object types by instance count:
head -15 class_histogram.txt

# Look for:
# - byte[] with huge total size -> payload in memory
# - app-specific classes with unexpectedly high counts -> leak
# - WeaveValue or CursorStreamProvider -> DataWeave memory use
```

**Check 3: Is it a leak or just undersized?**
```
If the application worked fine for hours/days then crashed:
  -> Likely a leak. Look for growing collections in heap dump.

If the application crashes on specific large requests:
  -> Undersized. Calculate required memory (see memory-budget-breakdown).

If the application crashes immediately on startup:
  -> Too many connectors for vCore size. Reduce connectors or increase vCore.
```

### Step 5: Apply the Fix (Minutes 25-30)

**Quick fixes by root cause:**

| Root Cause | Fix | Deployment Change |
|-----------|-----|-------------------|
| Large payload in memory | Add repeatable streaming strategy | Redeploy with strategy |
| DataWeave groupBy on big data | Stream input, use batch processing | Code change + redeploy |
| Unbounded Object Store | Set `maxEntries` and `entryTtl` | Config change + redeploy |
| Too many connectors on small vCore | Increase vCore | Redeployment setting change |
| JDBC connection leak | Close connections in error handlers | Code change + redeploy |
| Metaspace from hot redeployment | Restart worker | Operational action |
| Undersized for workload | Increase vCore | Redeployment setting change |

**Mule XML: Add streaming strategy to HTTP listener (most common fix):**
```xml
<http:listener-config name="HTTP_Listener">
    <http:listener-connection host="0.0.0.0" port="8081"/>
</http:listener-config>

<flow name="myFlow">
    <http:listener config-ref="HTTP_Listener" path="/api/*">
        <repeatable-file-stores-stream
            initialBufferSize="256"
            bufferSizeIncrement="256"
            maxInMemorySize="1024"
            bufferUnit="KB"/>
    </http:listener>
    <!-- rest of flow -->
</flow>
```

**Mule XML: Bound your Object Store:**
```xml
<os:object-store name="myStore"
    maxEntries="1000"
    entryTtl="30"
    entryTtlUnit="MINUTES"
    expirationInterval="5"
    expirationIntervalUnit="MINUTES"/>
```

### Gotchas
- **CloudHub 2.0 OOMKilled has no heap dump** — the container is killed by the kernel before the JVM can write a dump. You must enable `-XX:+HeapDumpOnOutOfMemoryError` AND set a dump path that persists, or use continuous heap monitoring.
- **Heap dumps on production are risky** — taking a heap dump pauses the JVM. On a 4 GB heap, this can take 30-60 seconds. Schedule during low traffic or on a single worker behind a load balancer.
- **GC logs are not enabled by default on CloudHub** — you must add JVM args explicitly in Runtime Manager > Settings > JVM Args.
- **The sawtooth pattern is normal** — heap usage going up and down is healthy GC. It's only a problem when the baseline (valley of the sawtooth) keeps rising over time.
- **DataWeave `reduce` with string concatenation** creates O(n^2) memory usage because strings are immutable. Use `joinBy` instead.
- **Object Store v2 on CloudHub has a 10 MB per value limit** — storing large objects silently fails or throws unexpected errors.

### Related
- [Memory Budget Breakdown](../memory-budget-breakdown/) — understand how much memory you actually have
- [Streaming Strategy Decision Guide](../streaming-strategy-decision-guide/) — pick the right streaming approach
- [DataWeave OOM Debugging](../dataweave-oom-debugging/) — DataWeave-specific memory patterns
- [Memory Leak Detection Step-by-Step](../memory-leak-detection-step-by-step/) — detailed heap dump analysis
