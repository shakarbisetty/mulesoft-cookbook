## Streaming Strategy Decision Guide
> Choose between file-store repeatable, in-memory repeatable, and non-repeatable streaming with a decision tree

### When to Use
- Payloads larger than 1 MB causing high memory usage or OOM
- Need to decide which streaming strategy to configure for an HTTP listener or requester
- Unsure whether you need repeatable access to the stream
- Application works locally but fails on CloudHub due to memory constraints
- DataWeave transform processes the payload multiple times and you need to understand the cost

### The Problem

Mule 4 defaults to repeatable in-memory streaming, which buffers the entire payload in heap. For small payloads this is fine. For anything above a few MB, you need to explicitly choose a strategy. The wrong choice either wastes memory (in-memory on large payloads), wastes disk I/O (file-store on small payloads), or breaks your flow (non-repeatable when something reads the stream twice).

### The Three Strategies

```
+------------------------+-------------------+--------------------+--------------------+
| Feature                | In-Memory          | File-Store         | Non-Repeatable     |
|                        | Repeatable         | Repeatable         |                    |
+------------------------+-------------------+--------------------+--------------------+
| Data stored in         | JVM heap           | Heap + temp files  | Not stored at all  |
| Re-readable?           | Yes                | Yes                | No (one read only) |
| Memory usage           | High (full payload)| Low (configurable) | Minimal            |
| Disk I/O               | None               | Yes (temp files)   | None               |
| Performance            | Fastest for small  | Slower (disk swap) | Fastest overall    |
| Max payload size       | Limited by heap    | Limited by disk    | Unlimited          |
| Default for            | Most connectors    | None (must config) | Must opt in        |
+------------------------+-------------------+--------------------+--------------------+
```

### The Decision Tree

```
                    Does your flow read the payload more than once?
                    (e.g., logger + transform, or scatter-gather)
                              |
                    +---------+---------+
                    |                   |
                   YES                  NO
                    |                   |
          Is the payload > 1 MB?    Is payload > 10 MB?
                    |                   |
              +-----+-----+      +-----+-----+
              |           |      |           |
             YES          NO    YES          NO
              |           |      |           |
        File-Store    In-Memory  Non-       In-Memory
        Repeatable    Repeatable Repeatable  Repeatable
              |           |      |        (default, fine)
              |           |      |
     Set buffer sizes   Done   Ensure nothing
     (see sizing below)        reads stream twice
```

### Strategy 1: In-Memory Repeatable (Default)

This is what Mule 4 uses when you do not configure anything.

```xml
<!-- Explicit configuration (same as default behavior) -->
<http:listener config-ref="HTTP_Listener" path="/api/*">
    <repeatable-in-memory-stream
        initialBufferSize="256"
        bufferSizeIncrement="256"
        maxInMemorySize="0"
        bufferUnit="KB"/>
</http:listener>
```

**How it works:**
1. Starts with `initialBufferSize` of heap allocated
2. Grows by `bufferSizeIncrement` as data arrives
3. If `maxInMemorySize` is 0 (default), grows without limit until OOM
4. Payload is fully buffered in heap and can be read multiple times

**When to use:** Payloads under 1 MB where multiple reads are needed. Typical for small JSON API responses.

**When NOT to use:** Any payload that could exceed a few MB. The unbounded default is the #1 cause of Mule OOM errors.

### Strategy 2: File-Store Repeatable

```xml
<http:listener config-ref="HTTP_Listener" path="/api/*">
    <repeatable-file-stores-stream
        initialBufferSize="512"
        bufferSizeIncrement="256"
        maxInMemorySize="1024"
        bufferUnit="KB"/>
</http:listener>
```

**How it works:**
1. First `maxInMemorySize` of data is buffered in heap
2. Beyond that threshold, data spills to a temporary file in `java.io.tmpdir`
3. Reads beyond the in-memory portion hit disk
4. Temp file is cleaned up when the event completes

**Buffer sizing guide:**

```
+------------------+-------------------+------------------+------------------+
| Payload Size     | initialBufferSize | bufferSizeIncr.  | maxInMemorySize  |
+------------------+-------------------+------------------+------------------+
| 1-10 MB          | 256 KB            | 256 KB           | 1024 KB (1 MB)   |
| 10-100 MB        | 512 KB            | 512 KB           | 2048 KB (2 MB)   |
| 100 MB - 1 GB    | 1024 KB           | 1024 KB          | 4096 KB (4 MB)   |
| > 1 GB           | 2048 KB           | 2048 KB          | 8192 KB (8 MB)   |
+------------------+-------------------+------------------+------------------+

Rule of thumb: maxInMemorySize = 1-2% of expected payload size
```

**For iterables (arrays, object streams), use repeatable-file-stores-iterable:**
```xml
<http:listener config-ref="HTTP_Listener" path="/api/*">
    <repeatable-file-stores-iterable
        initialBufferSize="100"
        bufferSizeIncrement="100"
        maxInMemoryInstances="500"/>
</http:listener>
```

### Strategy 3: Non-Repeatable

```xml
<http:listener config-ref="HTTP_Listener" path="/api/*">
    <non-repeatable-stream/>
</http:listener>
```

**How it works:**
1. Data flows through without any buffering
2. Once read, it is gone — cannot be read again
3. Lowest possible memory footprint

**When to use:**
- High-throughput proxy patterns (receive and forward without transforming)
- File transfer endpoints (stream directly to target)
- When you're absolutely sure nothing reads the payload twice

**When NOT to use:**
- If you have a Logger component in the flow (Logger reads the payload, consuming the stream)
- If error handling needs access to the original payload
- If using scatter-gather or any component that fans out the message

### Diagnostic Steps: Identifying Streaming Issues

#### Step 1: Check if Streaming is the Cause of OOM

```bash
# In heap dump class histogram, look for:
jcmd <PID> GC.class_histogram | grep -i "cursor\|buffer\|stream"

# High counts of these indicate in-memory buffering:
#   org.mule.runtime.core.internal.streaming.bytes.InMemoryCursorStreamProvider
#   org.mule.runtime.core.internal.streaming.bytes.PoolingByteBufferManager$InternalByteBuffer
```

#### Step 2: Check Temp File Usage (File-Store Strategy)

```bash
# File-store streaming writes to java.io.tmpdir
ls -la /tmp/mule-streaming-* 2>/dev/null | wc -l

# If these files accumulate and aren't cleaned up, you have a resource leak:
find /tmp -name "mule-streaming-*" -mmin +60 -ls
```

#### Step 3: Detect Non-Repeatable Stream Errors

These errors in logs mean something tried to re-read a consumed stream:
```
MULE:STREAM_MAXIMUM_SIZE_EXCEEDED
"Cannot read stream content: stream has already been consumed"
"Payload is a CursorStreamProvider that has already been closed"
```

**Fix: switch from non-repeatable to file-store repeatable.**

### Common Scenarios and Recommended Strategies

| Scenario | Strategy | Configuration |
|----------|----------|---------------|
| REST API receiving JSON < 1 MB | In-Memory (default) | No config needed |
| REST API receiving JSON 1-50 MB | File-Store Repeatable | maxInMemorySize=1 MB |
| File upload endpoint (any size) | File-Store Repeatable | maxInMemorySize=2 MB |
| Proxy / passthrough (no transform) | Non-Repeatable | `<non-repeatable-stream/>` |
| Batch processing large CSV | File-Store Repeatable | maxInMemorySize=4 MB |
| Event-driven (Anypoint MQ, JMS) | File-Store Repeatable | maxInMemorySize=1 MB |
| SFTP large file download | Non-Repeatable or File-Store | Depends on re-read need |

### Mule XML: Complete Example with File-Store Streaming

```xml
<http:listener-config name="HTTPS_Listener">
    <http:listener-connection host="0.0.0.0" port="8081"/>
</http:listener-config>

<flow name="largePayloadFlow">
    <http:listener config-ref="HTTPS_Listener" path="/upload">
        <!-- Keeps only 1 MB in heap, rest goes to disk -->
        <repeatable-file-stores-stream
            initialBufferSize="256"
            bufferSizeIncrement="256"
            maxInMemorySize="1024"
            bufferUnit="KB"/>
    </http:listener>

    <logger level="INFO" message="Received #[attributes.headers.'content-length'] bytes"/>

    <!-- DataWeave transform — stream is repeatable so this works -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map {
    id: $.id,
    processed: true
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Second read of original payload would work because it's repeatable -->
    <logger level="INFO" message="Transform complete"/>
</flow>
```

### Gotchas
- **Logger counts as a read** — `#[payload]` in a Logger message consumes the stream. With non-repeatable, this means the next component gets an empty payload. With in-memory, this forces full buffering.
- **Streaming strategy is per source/operation, not per flow** — you configure it on the HTTP listener, HTTP requester, Database select, etc. Each one has its own strategy.
- **File-store temp files need disk space** — on CloudHub, temp disk is limited (~10 GB on 1-vCore). Processing many large files concurrently can exhaust temp space. Monitor with `df -h /tmp`.
- **`maxInMemorySize=0` in file-store does NOT mean "no memory"** — it means unlimited in-memory, defeating the purpose. Always set an explicit limit.
- **DataWeave `output` directive affects buffering** — `output application/json deferred=true` enables lazy serialization but does not change the streaming strategy of the input.
- **Scatter-gather duplicates the stream** — each route gets its own copy. With large payloads, this multiplies memory usage by the number of routes.
- **CloudHub 2.0 ephemeral storage** — temp files do not survive pod restarts. Long-running file-store streaming operations can lose data on pod reschedule.

### Related
- [Memory Budget Breakdown](../memory-budget-breakdown/) — how much memory each vCore provides
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — when streaming choice has already caused OOM
- [DataWeave OOM Debugging](../dataweave-oom-debugging/) — DataWeave-specific streaming patterns
- [Batch Performance Tuning](../batch-performance-tuning/) — streaming in batch contexts
