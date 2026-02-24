## Batch Job Failure Analysis
> Diagnose OOM crashes, temp file buildup, and silent data loss in Mule batch jobs

### When to Use
- Batch job OOMs partway through processing
- Disk space fills up on the Mule server during batch execution
- Batch job completes but records are missing or silently dropped
- Batch step timing is unexpectedly slow
- Batch job fails on restart after a crash (corrupted temp files)

### Diagnosis Steps

#### Step 1: Understand Batch Memory Math

```
Memory per batch execution ≈ blockSize × averageRecordSize × 2 (input + output)

Example:
- blockSize = 100 (default)
- averageRecordSize = 50KB (JSON record)
- Memory = 100 × 50KB × 2 = 10MB per block

But with 4 threads processing blocks in parallel:
- Memory = 10MB × 4 = 40MB

Plus DataWeave transform overhead (3-5x):
- Actual memory = 40MB × 4 = 160MB
```

**Sizing guide:**

| vCore | Heap | Recommended blockSize | Max Records In-Flight |
|-------|------|-----------------------|----------------------|
| 0.1   | 512MB  | 50-100   | ~200 (50KB records) |
| 0.2   | 1GB    | 100-200  | ~500 |
| 0.5   | 1.5GB  | 200-500  | ~1,500 |
| 1.0   | 3.5GB  | 500-1000 | ~5,000 |

#### Step 2: Configure Batch Job Correctly

```xml
<batch:job jobName="orderProcessingBatch"
           maxFailedRecords="100"
           blockSize="200">

    <batch:process-records>
        <batch:step name="validateStep"
                    acceptPolicy="ALL">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
{
    id: payload.id,
    valid: payload.amount > 0
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </batch:step>

        <batch:step name="enrichStep"
                    acceptPolicy="NO_FAILURES"
                    acceptExpression="#[payload.valid == true]">
            <http:request method="GET"
                          path="#['/api/customers/' ++ payload.customerId]"
                          config-ref="HTTP_Request_Config" />
        </batch:step>

        <batch:step name="loadStep"
                    acceptPolicy="NO_FAILURES">
            <batch:aggregator size="50">
                <db:bulk-insert config-ref="Database_Config">
                    <db:sql>INSERT INTO processed_orders (id, customer, amount)
                            VALUES (:id, :customer, :amount)</db:sql>
                </db:bulk-insert>
            </batch:aggregator>
        </batch:step>
    </batch:process-records>

    <batch:on-complete>
        <logger level="INFO" message="#[
            'Batch complete: ' ++
            'total=' ++ payload.totalRecords ++
            ' successful=' ++ payload.successfulRecords ++
            ' failed=' ++ payload.failedRecords ++
            ' elapsed=' ++ payload.elapsedTimeInMillis ++ 'ms'
        ]" />
    </batch:on-complete>
</batch:job>
```

**Key configuration parameters:**

| Parameter | Default | Recommended | What It Does |
|-----------|---------|-------------|-------------|
| `blockSize` | 100 | See sizing guide | Records processed per block before writing to temp storage |
| `maxFailedRecords` | 0 | Set explicitly | How many records can fail before the entire job aborts. 0 = abort on first failure |
| `maxConcurrency` | 2× CPU cores | 2-4 for I/O heavy | Max parallel threads processing blocks |
| `schedulingStrategy` | ROUND_ROBIN | ROUND_ROBIN | How records are distributed across threads |

#### Step 3: Analyze Batch Logs

**Enable batch debug logging:**

```xml
<AsyncLogger name="com.mulesoft.mule.runtime.module.batch" level="DEBUG" />
<AsyncLogger name="org.mule.runtime.module.extension.internal.runtime.source" level="DEBUG" />
```

**Key log entries to look for:**

```
# Job started — verify input record count
INFO  BatchJobInstance - Created instance '<jobName>_instance' for job '<jobName>'
INFO  BatchJobInstance - Input phase completed. <N> records processed.

# Block processing — track progress
DEBUG BatchJobInstance - Processing block <blockNum> of step '<stepName>'

# Step completion — check timing per step
INFO  BatchJobInstance - Step '<stepName>' completed: <N> successful, <M> failed (elapsed: <T>ms)

# Job completion — final summary
INFO  BatchJobInstance - Batch job '<jobName>' instance '<instanceId>' completed:
      Total Records: 50000
      Successful:    49850
      Failed:        150                    ← CHECK THIS
      Elapsed:       180000ms
```

**Calculate throughput:**
```
Records per second = totalRecords / (elapsedTimeInMillis / 1000)
50000 / 180 = 278 records/second

Per-step timing shows the bottleneck:
- validateStep: 20s (fast — CPU only)
- enrichStep:   140s (SLOW — HTTP calls, this is the bottleneck)
- loadStep:     20s (bulk insert is efficient)
```

#### Step 4: Diagnose Temp File Issues

**Where batch temp files live:**

| Runtime | Temp File Location |
|---------|-------------------|
| On-Prem | `$MULE_HOME/.mule/<appName>/.mule/batch/instances/` |
| Anypoint Studio | `<workspace>/.mule/<appName>/.mule/batch/instances/` |
| CloudHub | `/tmp/` (ephemeral, lost on restart) |

**Check temp file accumulation:**
```bash
# On-prem: check disk usage
du -sh $MULE_HOME/.mule/*/. mule/batch/instances/
ls -la $MULE_HOME/.mule/*/. mule/batch/instances/ | wc -l

# Each batch instance creates temp files proportional to:
# (number of records × average serialized record size)
```

**Temp file math:**
```
Temp disk usage ≈ totalRecords × avgRecordSize × 2 (input queue + output queue)

Example: 1M records × 5KB each × 2 = 10GB of temp files
```

**Clean up orphaned temp files (after confirming no batch is running):**
```bash
# Stop the application first
# Remove batch temp directories
rm -rf $MULE_HOME/.mule/<appName>/.mule/batch/instances/*
# Restart the application
```

#### Step 5: Handle OOM in Batch Jobs

**Immediate fix — reduce memory footprint:**

```xml
<!-- Reduce block size to lower memory per block -->
<batch:job jobName="orderBatch" blockSize="50">

<!-- Use streaming in transforms within batch steps -->
<batch:step name="transformStep">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json streaming=true
---
// Only keep the fields you need — don't pass the entire record through
{
    id: payload.id,
    amount: payload.amount
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</batch:step>
```

**Split large inputs before batch:**

```xml
<!-- Instead of feeding 10M records into one batch job: -->
<foreach collection="#[payload splitAt 10000]">
    <batch:job jobName="chunkBatch" blockSize="200">
        <batch:process-records>
            <!-- process chunk of 10K records -->
        </batch:process-records>
    </batch:job>
</foreach>
```

#### Step 6: Diagnose Silent Data Loss

**maxFailedRecords=-1 swallows ALL errors:**

```xml
<!-- DANGEROUS: no records will ever cause the job to fail -->
<batch:job jobName="dangerousBatch" maxFailedRecords="-1">
    <!-- Even if every record fails, the job reports "completed" -->
</batch:job>
```

**Fix: always check batch:on-complete and log failures:**

```xml
<batch:on-complete>
    <choice>
        <when expression="#[payload.failedRecords > 0]">
            <logger level="ERROR" message="#[
                'BATCH FAILURES: ' ++ payload.failedRecords ++ ' of ' ++ payload.totalRecords ++
                ' records failed in job ' ++ payload.batchJobInstanceId
            ]" />
            <!-- Send alert, write to error queue, etc. -->
        </when>
    </choice>
</batch:on-complete>
```

**Record-level error tracking:**

```xml
<batch:step name="processStep">
    <try>
        <!-- risky operation -->
        <http:request method="POST" path="/api/process" config-ref="HTTP_Config">
            <http:body>#[payload]</http:body>
        </http:request>
        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR" message="#[
                    'Record ' ++ payload.id ++ ' failed: ' ++ error.description
                ]" />
                <!-- Record is marked as FAILED and skipped by subsequent steps -->
            </on-error-continue>
        </error-handler>
    </try>
</batch:step>
```

### How It Works
1. **Input phase**: Mule reads all input records and serializes them to temp files (disk-backed queue)
2. **Processing phase**: Records are read from the queue in blocks (`blockSize` at a time)
3. Each block is processed by a thread through all batch steps sequentially
4. Multiple blocks are processed in parallel (up to `maxConcurrency` threads)
5. After each step, the record's status (SUCCESS/FAILURE) and transformed payload are written back to temp storage
6. **On-complete phase**: Summary statistics are calculated and the callback is invoked
7. Temp files are cleaned up after on-complete finishes (if the JVM doesn't crash)

### Gotchas
- **Batch temp files are NOT cleaned on JVM crash** — if the Mule process is killed (OOM kill, `kill -9`, power failure), temp files remain on disk. They accumulate across restarts and can fill the disk. Set up a cron job or startup script to clean orphaned batch files.
- **`maxFailedRecords=-1` swallows ALL errors silently** — this is the most common cause of "where did my records go?" Always set an explicit limit and check `payload.failedRecords` in `on-complete`.
- **Batch aggregator size vs. block size** — the aggregator collects records across blocks. If `aggregatorSize=100` and `blockSize=50`, the aggregator triggers every 2 blocks. But the last partial aggregation only fires at the end of the job, not at the end of each block.
- **Batch jobs serialize/deserialize records between steps** — this means records must be serializable. Custom Java objects without `Serializable` will fail between steps. Use Maps or DataWeave objects instead.
- **CloudHub batch temp files use ephemeral storage** — the `/tmp` partition on CloudHub workers is limited (typically 2-4GB depending on vCore). Large batch jobs can exhaust this space. Consider using the persistent queue or splitting into smaller jobs.
- **Batch steps are NOT transactional by default** — if step 2 fails, step 1's changes are already committed. Use the Saga pattern or compensating transactions for data consistency.
- **Parallel batch instances** — if the batch trigger fires while a previous instance is still running, you get two instances consuming double the memory and temp disk. Use `maxConcurrency=1` on the trigger or implement instance locking.
- **on-complete payload is metadata only** — `payload` in `on-complete` contains statistics (totalRecords, failedRecords, etc.), NOT the actual records. You cannot access individual records in on-complete.

### Related
- [DataWeave OOM Debugging](../dataweave-oom-debugging/) — when the OOM is in a transform within a batch step
- [Memory Leak Detection Step-by-Step](../memory-leak-detection-step-by-step/) — heap dump analysis for batch memory issues
- [Thread Dump Analysis](../thread-dump-analysis/) — diagnosing batch thread pool issues
- [Block Size Optimization](../../performance/batch/block-size-optimization/) — detailed block size tuning
- [Aggregator Commit Sizing](../../performance/batch/aggregator-commit-sizing/) — aggregator tuning
- [Max Failed Records](../../performance/batch/max-failed-records/) — failure threshold strategies
- [Batch Concurrency](../../performance/batch/batch-concurrency/) — thread pool configuration
