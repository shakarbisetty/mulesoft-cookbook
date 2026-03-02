## Batch Performance Tuning
> Thread profile tuning, block size, maxConcurrency, and memory math for Mule 4 Batch

### When to Use
- Batch job takes too long to process
- Batch job fails with OutOfMemoryError
- Need to process millions of records within an SLA
- Batch job consumes too much memory or disk
- Need to tune batch parameters for a specific vCore size

### The Problem

Mule 4 Batch has four tuning parameters (block size, max concurrency, scheduling strategy, and thread profile) that interact in non-obvious ways. Default settings are conservative. Most developers never tune them, resulting in batch jobs that run 5-10x slower than they could — or tune them too aggressively and crash with OOM.

### Batch Architecture

```
+------------------------------------------------------------------+
|                        Batch Job                                  |
|                                                                   |
|  +------------------+     +------------------+     +------------+ |
|  | Load Phase       | --> | Process Phase    | --> | On Complete | |
|  | (single thread)  |     | (parallel)       |     | (single)   | |
|  |                  |     |                  |     |            | |
|  | Reads input,     |     | Block 1 [50 rec] |     | Summary,   | |
|  | creates records  |     | Block 2 [50 rec] |     | cleanup    | |
|  |                  |     | Block 3 [50 rec] |     |            | |
|  +------------------+     | ...              |     +------------+ |
|                           +------------------+                    |
+------------------------------------------------------------------+

Default block size: 100 records
Default max concurrency: determined by thread pool size
Records per block are processed sequentially within the block
Blocks are processed in parallel up to max concurrency
```

### The Key Parameters

```xml
<batch:job name="orderBatch"
    blockSize="200"
    maxConcurrency="8"
    schedulingStrategy="ORDERED_SEQUENTIAL">

    <batch:process-records>
        <batch:step name="enrichStep">
            <!-- Each record processed here -->
        </batch:step>
        <batch:step name="loadStep" acceptPolicy="ONLY_FAILURES">
            <!-- Only failed records from previous step -->
        </batch:step>
    </batch:process-records>

    <batch:on-complete>
        <logger message="#['Processed: $(payload.processedRecords), Failed: $(payload.failedRecords)']"/>
    </batch:on-complete>
</batch:job>
```

### Parameter 1: Block Size

**What it does:** Number of records per processing block.

```
+------------------+---------------------------------------------------+
| Block Size       | Effect                                            |
+------------------+---------------------------------------------------+
| Small (10-50)    | Low memory, high overhead (more context switches) |
| Medium (100-500) | Balanced (default: 100)                           |
| Large (1000+)    | High memory, low overhead, faster throughput      |
+------------------+---------------------------------------------------+
```

**Memory formula per block:**
```
Block Memory = blockSize x avgRecordSize x processingMultiplier

Example:
  blockSize: 200
  avgRecordSize: 5 KB (JSON record)
  processingMultiplier: 3x (DataWeave transform + error tracking)
  Block Memory: 200 x 5 KB x 3 = 3 MB per block

With maxConcurrency=8:
  Peak Memory: 8 blocks x 3 MB = 24 MB (just for batch data)
```

**Sizing guide:**

```
+----------+------------------+------------------+
| vCore    | Recommended      | Max Safe         |
|          | Block Size       | Block Size       |
+----------+------------------+------------------+
| 0.1-0.2  | 50               | 100              |
| 0.5      | 100-200          | 500              |
| 1.0      | 200-500          | 1000             |
| 2.0      | 500-1000         | 2000             |
| 4.0      | 1000-2000        | 5000             |
+----------+------------------+------------------+

These assume ~5 KB average record size. Adjust for larger records.
```

### Parameter 2: Max Concurrency

**What it does:** Maximum number of blocks processed in parallel.

```xml
<batch:job name="myBatch" maxConcurrency="4">
```

```
+------------------+---------------------------------------------------+
| maxConcurrency   | Effect                                            |
+------------------+---------------------------------------------------+
| 1                | Sequential processing (safest, slowest)           |
| 2-4              | Moderate parallelism (good for DB-heavy batches)  |
| 8-16             | High parallelism (good for API calls)             |
| CPU count x 2    | Maximum useful (diminishing returns beyond this)  |
+------------------+---------------------------------------------------+
```

**Interaction with downstream capacity:**
```
If each record makes an HTTP call to a downstream service:
  maxConcurrency x blockSize = concurrent requests to downstream

Example: maxConcurrency=8, blockSize=200
  = 8 blocks being processed, but records within a block are sequential
  = 8 concurrent requests to downstream (one per block)
```

### Parameter 3: Scheduling Strategy

```xml
<!-- Process blocks in input order (slower, deterministic) -->
<batch:job schedulingStrategy="ORDERED_SEQUENTIAL">

<!-- Process blocks as threads become available (faster, non-deterministic order) -->
<batch:job schedulingStrategy="ROUND_ROBIN">
```

Use `ROUND_ROBIN` unless record processing order matters.

### Parameter 4: Thread Profile

Batch jobs use IO threads by default. You can influence this:

```xml
<!-- Use custom threading via maxConcurrency -->
<batch:job maxConcurrency="4">
    <!-- This limits parallel blocks to 4, regardless of IO pool size -->
</batch:job>
```

### Tuning Methodology

#### Step 1: Measure Baseline

```xml
<!-- Add timing to your batch job -->
<batch:job name="orderBatch">
    <batch:process-records>
        <batch:step name="processStep">
            <set-variable variableName="stepStart" value="#[now()]"/>

            <!-- Your processing logic -->

            <logger level="DEBUG" message="#['Record processed in $(now() as Number - vars.stepStart as Number)ms']"/>
        </batch:step>
    </batch:process-records>

    <batch:on-complete>
        <logger level="INFO" message="#[output application/json --- {
            totalRecords: payload.processedRecords + payload.failedRecords,
            successful: payload.processedRecords,
            failed: payload.failedRecords,
            elapsedMs: payload.elapsedTimeInMillis,
            recordsPerSecond: (payload.processedRecords / (payload.elapsedTimeInMillis / 1000)) as Number {format: '0.0'}
        }]"/>
    </batch:on-complete>
</batch:job>
```

#### Step 2: Identify the Bottleneck

```
If CPU is high during batch -> processing-bound
  Fix: Increase blockSize (fewer context switches)
  Fix: Optimize DataWeave transforms

If CPU is low during batch -> I/O-bound
  Fix: Increase maxConcurrency (more parallel I/O)
  Fix: Use batch aggregator to batch downstream calls

If memory climbs steadily -> records not being released
  Fix: Decrease blockSize
  Fix: Ensure streaming is enabled on input
```

#### Step 3: Optimize I/O-Bound Batches

Use batch aggregator to reduce downstream calls:

```xml
<batch:step name="loadStep">
    <!-- Instead of one API call per record, batch them -->
    <batch:aggregator size="100">
        <!-- This fires once per 100 records -->
        <http:request config-ref="Bulk_API" method="POST" path="/bulk">
            <http:body>#[output application/json --- payload]</http:body>
        </http:request>
    </batch:aggregator>
</batch:step>
```

**Before optimization:**
```
10,000 records x 1 API call each x 100ms per call = 1,000 seconds
```

**After batch aggregator (batches of 100):**
```
100 bulk API calls x 200ms per call = 20 seconds (50x faster)
```

#### Step 4: Tune for Your vCore

```
+----------+-------------+-----------------+------------------+
| vCore    | blockSize   | maxConcurrency  | Expected         |
|          |             |                 | Throughput       |
+----------+-------------+-----------------+------------------+
| 0.1      | 50          | 1               | 10-50 rec/s      |
| 0.2      | 100         | 2               | 50-200 rec/s     |
| 0.5      | 200         | 4               | 200-500 rec/s    |
| 1.0      | 500         | 8               | 500-2000 rec/s   |
| 2.0      | 1000        | 8               | 2000-5000 rec/s  |
| 4.0      | 2000        | 16              | 5000-10000 rec/s |
+----------+-------------+-----------------+------------------+

Throughput depends heavily on processing complexity.
Simple transforms = upper range. API calls per record = lower range.
```

### Memory Math for Batch

```
Total Batch Memory = Load Phase + Process Phase + Overhead

Load Phase:
  = Total input size (if loaded in memory)
  = ~0 (if using streaming input)

Process Phase:
  = maxConcurrency x blockSize x avgRecordSize x multiplier

Overhead:
  = ~50 MB (batch engine bookkeeping, temp files, error tracking)

Example: 100,000 records at 5 KB each, blockSize=500, maxConcurrency=8
  Load: 100,000 x 5 KB = 500 MB (if in memory) or ~10 MB (if streaming)
  Process: 8 x 500 x 5 KB x 3 = 60 MB
  Overhead: 50 MB
  Total: ~120 MB (with streaming) or ~610 MB (without streaming)
  Minimum vCore: 0.5 (streaming) or 2.0 (no streaming)
```

### Batch Input Streaming

```xml
<!-- Stream the input to avoid loading everything in memory -->
<flow name="batchTrigger">
    <scheduler>
        <scheduling-strategy><cron expression="0 0 2 * * ?"/></scheduling-strategy>
    </scheduler>

    <db:select config-ref="DB" fetchSize="500"
        streamingStrategy="REPEATABLE">
        <db:sql>SELECT * FROM orders WHERE processed = false</db:sql>
    </db:select>

    <batch:execute job="orderBatch"/>
</flow>
```

### Gotchas
- **Batch temp files can fill disk** — batch jobs write to `java.io.tmpdir`. On CloudHub with limited temp space, large batches can exhaust disk. Monitor with `df -h /tmp`.
- **Default blockSize of 100 is too small for most use cases** — for I/O-bound batches, increasing to 500-1000 can improve throughput by 3-5x.
- **maxConcurrency > IO thread pool = no benefit** — if you set maxConcurrency=16 but only have 8 IO threads, you won't get 16-way parallelism. Threads are the real bottleneck.
- **Batch aggregator size vs. blockSize** — the aggregator fires when it collects `size` records. If `size` > `blockSize`, the aggregator never fires within a single block. Set aggregator `size` <= `blockSize`.
- **Error handling in batch does NOT stop processing** — by default, a failed record is marked as failed and processing continues. If you want to stop on first error, use `maxFailedRecords="0"`.
- **Batch on-complete sees only summary** — in the `on-complete` phase, `payload` is a `BatchJobResult` object, not the original data. You cannot access individual records here.
- **Batch jobs and memory leaks** — each batch execution creates objects that should be GC'd after completion. If you run batch jobs continuously (every minute), watch for memory growth between runs.
- **CloudHub 2.0 pod restarts kill batch mid-process** — batch jobs have no built-in checkpointing. If the pod restarts, you must restart the entire batch from the beginning. Implement your own checkpointing for critical batches.

### Related
- [Memory Budget Breakdown](../memory-budget-breakdown/) — calculate available memory for batch
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — when batch causes OOM
- [Thread Pool Component Mapping](../thread-pool-component-mapping/) — batch thread usage
- [Batch Job Failure Analysis](../batch-job-failure-analysis/) — diagnosing failed batches
