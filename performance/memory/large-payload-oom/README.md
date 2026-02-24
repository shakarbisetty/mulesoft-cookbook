## Large Payload OOM Prevention
> Process 100MB+ files without OutOfMemoryError.

### When to Use
- Mule applications on CloudHub experiencing memory issues
- Tuning JVM for production workloads
- Preventing OutOfMemoryError under load

### Configuration / Code

```
# JVM args for CloudHub (set in Runtime Manager > Settings > JVM Arguments)
```

```xml
<!-- Strategy: streaming + chunking for 100MB+ files -->
<flow name="large-file-processor" maxConcurrency="2">
    <file:listener config-ref="File_Config" directory="${file.input.dir}">
        <repeatable-file-store-stream
            inMemorySize="1"
            bufferUnit="MB"/>
        <scheduling-strategy><fixed-frequency frequency="60000"/></scheduling-strategy>
    </file:listener>

    <!-- Stream directly to batch — never load fully into memory -->
    <batch:job jobName="large-file-batch" blockSize="200" maxConcurrency="4">
        <batch:process-records>
            <batch:step name="transform-step">
                <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.id,
    data: payload.data
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </batch:step>
            <batch:step name="upsert-step">
                <batch:aggregator size="200">
                    <db:bulk-insert config-ref="Database_Config">
                        <db:sql>INSERT INTO records (id, data) VALUES (:id, :data)</db:sql>
                    </db:bulk-insert>
                </batch:aggregator>
            </batch:step>
        </batch:process-records>
    </batch:job>
</flow>
```

### How It Works
1. File listener uses repeatable-file-store-stream with small in-memory buffer
2. `maxConcurrency="2"` limits parallel file processing to prevent memory spikes
3. Batch job processes records in blocks of 200 — constant memory per block
4. Aggregator batches DB writes for efficiency

### Gotchas
- Never call `sizeOf(payload)` on a streamed file — it loads everything into memory
- `maxConcurrency` on the flow limits concurrent file processing
- DataWeave transforms can be memory-intensive — use streaming-compatible functions
- Avoid `payload as String` or `write(payload)` on large files

### Related
- [Repeatable File Store](../../streaming/repeatable-file-store/) — streaming config
- [Block Size Optimization](../../batch/block-size-optimization/) — batch tuning
