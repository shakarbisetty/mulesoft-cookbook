## Memory Leak Detection Step-by-Step
> Find and fix memory leaks in Mule runtime using heap dumps and Eclipse MAT

### When to Use
- Application OOMs repeatedly after running for hours/days (not on startup)
- CloudHub worker memory usage grows steadily over time without leveling off
- `java.lang.OutOfMemoryError: Java heap space` in logs
- Application slows down progressively — GC pauses get longer
- Memory usage doesn't drop after traffic subsides

### Diagnosis Steps

#### Step 1: Enable Heap Dump on OOM

**On-Prem (wrapper.conf or standalone command):**
```
# Add to wrapper.conf
wrapper.java.additional.<next_number>=-XX:+HeapDumpOnOutOfMemoryError
wrapper.java.additional.<next_number>=-XX:HeapDumpPath=/opt/mule/logs/
```

**In Anypoint Studio (VM arguments):**
```
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heapdumps/
```

**On CloudHub:**
CloudHub automatically captures heap dumps on OOM. Download from:
Runtime Manager → Application → Settings → Download heap dump

**Manual heap dump (when app is still running but you suspect a leak):**
```bash
# Find the PID
ps aux | grep mule | grep -v grep

# Take heap dump without killing the process
jmap -dump:live,format=b,file=heap_$(date +%Y%m%d_%H%M%S).hprof <PID>

# Alternative on Java 17+
jcmd <PID> GC.heap_dump /tmp/heap_dump.hprof
```

#### Step 2: Transfer and Open in Eclipse MAT

1. Download Eclipse MAT from https://eclipse.dev/mat/
2. If the heap dump is large (>2GB), increase MAT's own memory:
   ```
   # Edit MemoryAnalyzer.ini
   -Xmx6g
   ```
3. Open MAT → File → Open Heap Dump → select your `.hprof` file
4. Wait for parsing (can take 5-20 minutes for large dumps)
5. MAT will auto-generate indexes on first open

#### Step 3: Run Leak Suspects Report

When the dump opens, MAT shows a pie chart. Click **"Leak Suspects Report"** — this is your starting point.

The report identifies:
- **Problem Suspect 1, 2, 3...** — objects consuming the most retained heap
- **Accumulation Point** — the object holding references that prevent GC
- **Shortest Paths to GC Roots** — the chain keeping objects alive

#### Step 4: Investigate with Dominator Tree

1. Click the **Dominator Tree** icon (tree with percentage)
2. Sort by **Retained Heap** (descending)
3. The top entries are the biggest memory consumers
4. Expand the tree to see what they hold

**What to look for:**

| Top Object | Likely Leak | Fix |
|-----------|-------------|-----|
| `java.util.HashMap` with millions of entries | Static map that's never cleared | Use bounded cache (Caffeine/Guava) or object store with TTL |
| `byte[]` arrays dominating heap | Unclosed input streams or large payloads held in memory | Close streams in finally blocks, use streaming |
| `org.mule.runtime.api.store.ObjectStore` | Object store entries growing without expiry | Set `entryTtl` and `maxEntries` on your object store |
| `java.util.ArrayList` with millions of elements | Collecting records without pagination | Use pagination, streaming, or batch processing |
| `com.mulesoft.mule.runtime.module.batch.*` | Batch records held in memory | Check `blockSize`, ensure batch completes/cleanups run |
| `javax.xml.transform.dom.DOMSource` | Large XML parsed as DOM tree | Switch to `output application/xml streaming=true` |

#### Step 5: Find Leaking References

In Dominator Tree, right-click the suspect object → **"Path to GC Roots" → "exclude weak/soft references"**

This shows the exact chain:
```
Thread: http-listener-worker-12
  └─ com.mycompany.service.CacheManager
      └─ java.util.HashMap (size=2,847,193)          ← THIS IS THE LEAK
          └─ java.util.HashMap$Node[]
              └─ com.mycompany.model.CustomerRecord   ← 2.8M records cached, never evicted
```

#### Step 6: Compare Two Heap Dumps (Differential Analysis)

Take two dumps 30 minutes apart to see what's growing:

1. Open both dumps in MAT
2. Go to the first dump → **"Histogram"** view
3. Click the **"Compare to another Heap Dump"** button
4. Select the second dump
5. Sort by **"Objects delta"** — positive deltas are growing
6. Large positive deltas on domain objects = leak

```
Class Name                          | Objects (Dump 1) | Objects (Dump 2) | Delta
com.mycompany.model.CustomerRecord  | 1,200,000        | 2,800,000        | +1,600,000  ← LEAKING
java.lang.String                    | 3,400,000        | 7,200,000        | +3,800,000  ← STRINGS FROM RECORDS
```

### How It Works
1. The JVM tracks all live objects on the heap with reference chains
2. Garbage Collection (GC) reclaims objects with no path from any GC root (threads, static fields, JNI refs)
3. A memory leak = objects that are still reachable from a GC root but no longer needed by the application
4. Heap dumps capture every object, its fields, and all references at a point in time
5. Eclipse MAT reconstructs the reference graph and calculates "retained heap" — the total memory that would be freed if a given object were garbage collected

### Common Mule Leak Patterns

**1. Unclosed Streams:**
```xml
<!-- LEAKY: stream stays open if transform throws -->
<http:request method="GET" url="http://api.example.com/large-data" />
<ee:transform>
  <ee:message>
    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload.records map { id: $.id }
    ]]></ee:set-payload>
  </ee:message>
</ee:transform>

<!-- FIX: wrap in try with stream close, or use repeatable-file-store-stream -->
<http:request method="GET" url="http://api.example.com/large-data">
  <http:response-validator>
    <http:success-status-code-validator values="200" />
  </http:response-validator>
</http:request>
```

**2. Static Map Accumulation:**
```java
// LEAKY: grows forever
public class MyComponent {
    private static final Map<String, Object> cache = new HashMap<>();  // NEVER CLEARED

    public void process(MuleEvent event) {
        cache.put(event.getMessage().getPayload().toString(), result);
    }
}

// FIX: use Mule Object Store with TTL
```

**3. Object Store Without TTL:**
```xml
<!-- LEAKY: entries never expire -->
<os:object-store name="myStore" persistent="true" />

<!-- FIX: add TTL and max entries -->
<os:object-store name="myStore" persistent="true"
    entryTtl="30" entryTtlUnit="MINUTES"
    maxEntries="10000"
    expirationInterval="5" expirationIntervalUnit="MINUTES" />
```

### Gotchas
- **Heap dump file size equals heap size** — a 4GB heap produces a ~4GB `.hprof` file. Ensure you have enough disk space before taking the dump.
- **Need matching JDK version to open** — a dump from Java 17 may not open correctly in MAT bundled with Java 8. Use the standalone MAT with the matching JDK.
- **`jmap -dump` pauses the JVM** — on production with large heaps (8GB+), this pause can last 10-30 seconds. Schedule during low traffic if possible.
- **`live` flag in `jmap -dump:live` triggers a full GC first** — this gives a cleaner dump (only reachable objects) but adds GC pause time. Omit `live` if you need the dump faster.
- **CloudHub heap dump download can fail** for very large heaps — if the download times out, try connecting via VPN and downloading from the worker directly.
- **Compressed OOPs** — if heap > 32GB, the JVM disables compressed ordinary object pointers, and objects use more memory than expected. Keep heap ≤ 32GB.
- **Don't confuse high memory usage with a leak** — a stable plateau (even if high) is not a leak. A leak shows continuous growth over hours/days.
- **Non-repeatable streams** — if you read a stream once, it's gone. This isn't a leak, but it will cause `NullPayloadException` on second access.

### Related
- [Thread Dump Analysis](../thread-dump-analysis/) — when the problem is thread starvation, not memory
- [DataWeave OOM Debugging](../dataweave-oom-debugging/) — when the OOM is specifically during DataWeave transforms
- [Batch Job Failure Analysis](../batch-job-failure-analysis/) — batch-specific memory issues
- [Heap Sizing per vCore](../../performance/memory/heap-sizing-vcore/) — setting correct heap sizes
- [Memory Leak Detection](../../performance/memory/memory-leak-detection/) — proactive monitoring setup
