## Thread Pool Component Mapping
> Which thread pool (CPU_LITE, IO, CUSTOM) each Mule 4 component uses — the definitive reference

### When to Use
- Designing a flow and need to predict thread pool usage
- Diagnosing pool exhaustion and need to know which component caused it
- Tuning `maxConcurrency` and need to understand which pool it limits
- Migrating from Mule 3 (where each connector had its own pool) to Mule 4 UBER model

### The Problem

Mule 4's UBER thread pool model consolidates threads into three pools: CPU_LITE, IO, and CPU_INTENSIVE. But the documentation doesn't clearly map every component to its pool. Developers put blocking operations on CPU_LITE threads (unknowingly) and exhaust the pool, freezing the entire application. This recipe provides the complete mapping.

### Thread Pool Defaults

```
+------------------+--------------------+----------------------------------------+
| Pool             | Default Size       | Purpose                                |
+------------------+--------------------+----------------------------------------+
| CPU_LITE         | 2 * availableCores | Non-blocking, fast operations           |
| IO               | availableCores     | Blocking I/O (grows dynamically)       |
|                  | (grows to max)     |                                        |
| CPU_INTENSIVE    | 2 * availableCores | Heavy computation                      |
+------------------+--------------------+----------------------------------------+

CloudHub vCore to core mapping:
  0.1 vCore = 1 core   -> CPU_LITE: 2, IO: 1, CPU_INTENSIVE: 2
  0.2 vCore = 1 core   -> CPU_LITE: 2, IO: 1, CPU_INTENSIVE: 2
  0.5 vCore = 1 core   -> CPU_LITE: 2, IO: 1, CPU_INTENSIVE: 2
  1.0 vCore = 2 cores  -> CPU_LITE: 4, IO: 2, CPU_INTENSIVE: 4
  2.0 vCore = 4 cores  -> CPU_LITE: 8, IO: 4, CPU_INTENSIVE: 8
  4.0 vCore = 8 cores  -> CPU_LITE: 16, IO: 8, CPU_INTENSIVE: 16
```

### Complete Component-to-Pool Mapping

#### Sources (Where Flow Execution Starts)

| Component | Initial Pool | Notes |
|-----------|-------------|-------|
| HTTP Listener | CPU_LITE | Receives request, starts on CPU_LITE |
| Scheduler (Cron/Fixed) | CPU_LITE | Trigger fires on CPU_LITE |
| Anypoint MQ Subscriber | CPU_LITE | Message received on CPU_LITE |
| JMS Listener | CPU_LITE | Message received on CPU_LITE |
| VM Listener | CPU_LITE | Internal VM message on CPU_LITE |
| File/SFTP Listener | CPU_LITE | Polling trigger on CPU_LITE |
| Database Listener | CPU_LITE | Watermark poll on CPU_LITE |
| Salesforce Streaming | CPU_LITE | Platform event on CPU_LITE |

#### Processors (Operations Within a Flow)

| Component | Pool | Why |
|-----------|------|-----|
| **Set Variable** | CPU_LITE | In-memory, non-blocking |
| **Set Payload** | CPU_LITE | In-memory, non-blocking |
| **Remove Variable** | CPU_LITE | In-memory, non-blocking |
| **Logger** | CPU_LITE | Synchronous write (but fast) |
| **Choice Router** | CPU_LITE | Expression evaluation only |
| **Scatter-Gather** | CPU_LITE (orchestration) | Spawns routes on their respective pools |
| **First Successful** | CPU_LITE (orchestration) | Routes execute on their pools |
| **Round Robin** | CPU_LITE | Simple routing decision |
| **Flow Reference** | CPU_LITE | Stays on same pool as caller |
| **Async** | CPU_LITE | Spawns work on CPU_LITE (unless child is IO) |
| **For Each** | CPU_LITE (loop) | Each iteration on CPU_LITE, inner ops on their pools |
| **Parallel For Each** | CPU_LITE (orchestration) | Spawns iterations across pools |
| **Until Successful** | CPU_LITE (orchestration) | Retried operation uses its natural pool |
| **Raise Error** | CPU_LITE | Immediate, non-blocking |
| **Try** | CPU_LITE | Orchestration only |

#### Blocking I/O Operations (IO Pool)

| Component | Pool | Why |
|-----------|------|-----|
| **HTTP Request** | IO | Network call, blocks waiting for response |
| **Database Select/Insert/Update/Delete** | IO | JDBC call, blocks on network + DB |
| **Database Stored Procedure** | IO | Same as above |
| **File Read/Write/Copy/Move** | IO | Filesystem I/O |
| **SFTP Read/Write/List** | IO | Network + filesystem I/O |
| **FTP Read/Write/List** | IO | Network + filesystem I/O |
| **JMS Publish** | IO | Network call to broker |
| **Anypoint MQ Publish** | IO | Network call to MQ service |
| **VM Publish** | IO | Cross-flow message passing |
| **SMTP Send** | IO | Network call to mail server |
| **LDAP Search/Add/Modify** | IO | Network call to directory |
| **Salesforce Create/Query/Update** | IO | Network call to SF API |
| **SAP Execute BAPI** | IO | JCo network call |
| **Web Service Consumer** | IO | SOAP network call |
| **Object Store Retrieve/Store** | IO | Potentially networked (OS v2) |
| **Batch Job Execute** | IO | Internal batch engine I/O |
| **OAuth Token Request** | IO | HTTP call for token |

#### CPU_INTENSIVE Operations

| Component | Pool | Why |
|-----------|------|-----|
| **DataWeave Transform (large payload)** | CPU_INTENSIVE | Heavy computation on data > threshold |
| **DataWeave Transform (small payload)** | CPU_LITE | Small transforms stay on calling thread |
| **XML Module Validate** | CPU_INTENSIVE | Schema validation is CPU-heavy |
| **Crypto Module (encrypt/decrypt)** | CPU_INTENSIVE | Cryptographic operations |
| **Custom Java (ProcessorComponent)** | Depends on annotation | Default: CPU_LITE. Use @ProcessingType |

### The Thread Handoff Model

```
Request arrives at HTTP Listener
         |
    [CPU_LITE] Set Variable, Logger, Choice Router
         |
    [HANDOFF to IO] Database Select (blocks waiting for DB)
         |
    [HANDOFF back to CPU_LITE] Set Payload with result
         |
    [HANDOFF to CPU_INTENSIVE] DataWeave transform (large)
         |
    [HANDOFF back to CPU_LITE] HTTP Response sent
```

Each handoff has a small cost (~0.05ms). For most flows, this is negligible. For extremely high-throughput flows processing thousands of messages per second, excessive handoffs can become measurable.

### Detecting Pool Exhaustion in Thread Dumps

```bash
# Count active vs. waiting threads per pool
for pool in cpuLight io cpuIntensive; do
  echo "=== $pool ==="
  grep -A 1 "\[MuleRuntime\]\.$pool" dump.txt | \
    grep "Thread.State" | sort | uniq -c | sort -rn
done
```

**Healthy output:**
```
=== cpuLight ===
      6 TIMED_WAITING     <- Idle, waiting for work
      2 RUNNABLE          <- Processing
=== io ===
      3 TIMED_WAITING     <- Waiting for I/O response (normal)
      1 RUNNABLE          <- Active I/O
=== cpuIntensive ===
      8 TIMED_WAITING     <- Idle (expected, DW transforms are usually fast)
```

**Exhausted CPU_LITE:**
```
=== cpuLight ===
      0 TIMED_WAITING     <- No idle threads
      2 BLOCKED           <- Threads stuck
      6 WAITING           <- Threads parked waiting for resources
```

### Tuning Thread Pools

```xml
<!-- In your Mule application's global config (scheduler-pools.conf) -->
<!-- Place in src/main/resources/scheduler-pools.conf -->

# CPU_LITE pool
org.mule.runtime.scheduler.cpuLight.threadPool.size=8
org.mule.runtime.scheduler.cpuLight.workQueue.size=256

# IO pool
org.mule.runtime.scheduler.io.threadPool.coreSize=4
org.mule.runtime.scheduler.io.threadPool.maxSize=64
org.mule.runtime.scheduler.io.workQueue.size=256

# CPU_INTENSIVE pool
org.mule.runtime.scheduler.cpuIntensive.threadPool.size=8
org.mule.runtime.scheduler.cpuIntensive.workQueue.size=256
```

### Custom Processing Type for Java Components

```java
import org.mule.runtime.extension.api.annotation.param.MediaType;
import org.mule.runtime.api.scheduler.SchedulerService;

// Tell Mule to run this on the IO pool
@org.mule.runtime.extension.api.annotation.execution.Execution(
    org.mule.runtime.api.meta.model.ExecutionType.BLOCKING
)
public class MyBlockingProcessor implements Processor {
    // This will execute on IO pool, not CPU_LITE
}

// Options:
// ExecutionType.CPU_LITE     -> CPU_LITE pool (default)
// ExecutionType.BLOCKING     -> IO pool
// ExecutionType.CPU_INTENSIVE -> CPU_INTENSIVE pool
```

### Gotchas
- **DataWeave pool assignment depends on payload size** — small transforms (under ~64 KB) run on CPU_LITE. Larger transforms are moved to CPU_INTENSIVE. You cannot explicitly control this threshold.
- **`maxConcurrency` on a flow limits CPU_LITE threads** — setting `maxConcurrency="4"` means only 4 events can be processed simultaneously on that flow, regardless of pool sizes.
- **Flow Reference does NOT cross pool boundaries** — the referenced flow runs on the same thread as the caller. It does NOT start a new CPU_LITE thread.
- **Async scope does NOT mean IO pool** — `<async>` starts work on CPU_LITE. The inner components use their natural pools based on their type.
- **CloudHub 0.1/0.2 vCore only has 1 core** — CPU_LITE gets 2 threads, IO gets 1 thread. A single slow DB query can block ALL IO operations.
- **Batch processing has its own thread management** — batch jobs use IO threads for the process phase but manage their own concurrency internally.
- **The IO pool can grow unbounded** — unlike CPU_LITE (fixed size), IO threads are created on demand. High concurrency to slow backends can create hundreds of IO threads, consuming stack memory.

### Related
- [Thread Dump Reading Guide](../thread-dump-reading-guide/) — how to read the thread dumps
- [Thread Dump Analysis](../thread-dump-analysis/) — foundational thread dump recipe
- [Flow Profiling Methodology](../flow-profiling-methodology/) — find the slowest component
- [Connection Pool Sizing](../connection-pool-sizing/) — sizing the connection pools that IO threads use
