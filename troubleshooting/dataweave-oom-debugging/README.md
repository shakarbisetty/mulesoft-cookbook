## DataWeave OOM Debugging
> Diagnose and fix out-of-memory errors caused by large payloads, recursive transforms, and stream issues in DataWeave

### When to Use
- `java.lang.OutOfMemoryError` during a DataWeave `ee:transform` step
- `java.lang.StackOverflowError` in DataWeave execution
- Application processes small payloads fine but crashes on large ones
- Memory spikes during transform even though input payload size seems reasonable
- `NullPayloadException` or empty payload after reading a stream twice

### Diagnosis Steps

#### Step 1: Check Payload Size Before Transform

Add a logger before the transform to see what you're dealing with:

```xml
<logger level="INFO" message="#['Payload size: ' ++ sizeOf(payload as String) ++ ' chars, type: ' ++ typeOf(payload)]" />
```

For large payloads where `as String` itself would OOM:

```xml
<!-- Check size without loading into memory -->
<logger level="INFO" message="#['Payload class: ' ++ payload.^class default 'null']" />
```

**Size reference for common vCore allocations:**

| vCore | Heap | Safe payload (in-memory) | Safe payload (streaming) |
|-------|------|--------------------------|--------------------------|
| 0.1   | 512MB  | ~50MB  | ~2GB (disk-backed) |
| 0.2   | 1GB    | ~100MB | ~5GB |
| 0.5   | 1.5GB  | ~200MB | ~10GB |
| 1.0   | 3.5GB  | ~500MB | ~50GB |

Rule of thumb: DataWeave needs **3-5x the input payload size** in memory during transformation (input + output + intermediate objects).

#### Step 2: Identify the OOM Trigger

**Trigger 1: Large Array Operations**

```dataweave
%dw 2.0
output application/json

// OOM: flatMap on a 10M element array creates a new array in memory
---
payload.records flatMap ((record) ->
    record.items map ((item) -> {
        recordId: record.id,
        itemName: item.name
    })
)

// FIX: process in chunks or use streaming output
```

**Trigger 2: Recursive Transforms**

```dataweave
%dw 2.0
output application/json

// STACK OVERFLOW: recursive function on deeply nested structure (>500 levels)
fun flatten(obj) =
    obj match {
        case is Object -> obj mapObject ((v, k) -> (k): flatten(v))
        case is Array -> obj flatMap flatten($)
        else -> obj
    }
---
flatten(payload)

// FIX: use DataWeave's built-in flatten() or limit recursion depth
```

**Trigger 3: XML with Huge CDATA or Text Nodes**

```xml
<!-- 500MB XML with embedded Base64 in CDATA blocks -->
<document>
    <attachment><![CDATA[/9j/4AAQSkZJRg...500MB of base64...]]></attachment>
</document>
```

```dataweave
// OOM: entire CDATA content loaded into a single String
payload.document.attachment

// FIX: stream the XML, extract attachment separately
// Or use Java with StAX parser for surgical extraction
```

**Trigger 4: Cartesian Product (accidental cross-join)**

```dataweave
// OOM: 10K × 10K = 100M objects created
payload.orders map ((order) ->
    payload.customers map ((customer) ->  // iterates ALL customers for EACH order
        { orderId: order.id, customerId: customer.id }
    )
)

// FIX: use a lookup map instead of nested iteration
var customerMap = payload.customers groupBy $.id
---
payload.orders map ((order) ->
    { orderId: order.id, customer: customerMap[order.customerId][0] }
)
```

#### Step 3: Enable Streaming

**Repeatable File Store Stream (recommended for large payloads):**

```xml
<http:listener-config name="HTTP_Listener_Config">
    <http:listener-connection host="0.0.0.0" port="8081" />
    <!-- This applies to ALL responses received by this listener -->
    <http:listener-interceptors>
        <http:body>
            <http:repeatable-file-store-stream
                inMemorySize="512"
                bufferUnit="KB"
                maxInMemorySize="1024"
                bufferSizeIncrement="256" />
        </http:body>
    </http:listener-interceptors>
</http:listener-config>

<http:request-config name="HTTP_Request_Config">
    <http:request-connection host="${api.host}" port="443" protocol="HTTPS" />
    <http:response>
        <http:body>
            <http:repeatable-file-store-stream
                inMemorySize="512"
                bufferUnit="KB" />
        </http:body>
    </http:response>
</http:request-config>
```

**Streaming with DataWeave output:**

```dataweave
%dw 2.0
output application/json streaming=true, deferred=true
---
// With streaming=true, DW writes output incrementally instead of building the full result in memory
payload.records map ((record) -> {
    id: record.id,
    name: record.name
})
```

**Non-repeatable stream (use when you only need to read once):**

```xml
<http:request-config name="HTTP_Request_Config">
    <http:request-connection host="${api.host}" port="443" protocol="HTTPS" />
    <http:response>
        <http:body>
            <http:non-repeatable-stream />
        </http:body>
    </http:response>
</http:request-config>
```

#### Step 4: Process Large Data in Chunks

**Pagination approach:**

```xml
<set-variable variableName="offset" value="0" />
<set-variable variableName="pageSize" value="1000" />

<until-successful maxRetries="0">
    <http:request method="GET" path="/api/records">
        <http:query-params>#[{offset: vars.offset, limit: vars.pageSize}]</http:query-params>
    </http:request>
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map ((record) -> {
    id: record.id,
    transformed: upper(record.name)
})]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <!-- Write chunk to output (file, DB, queue) -->
    <file:write path='#["output/chunk_" ++ vars.offset ++ ".json"]' />
    <set-variable variableName="offset" value="#[vars.offset + vars.pageSize]" />
</until-successful>
```

**Batch processing for very large datasets:**

```xml
<batch:job jobName="largeDataBatch" blockSize="200">
    <batch:process-records>
        <batch:step name="transformStep">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.id,
    processed: true
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </batch:step>
    </batch:process-records>
</batch:job>
```

#### Step 5: DataWeave Memory Profiling

**Measure transform memory usage:**

```xml
<!-- Before transform -->
<logger level="INFO" message="#['Heap before: ' ++ (java!java::lang::Runtime::getRuntime().totalMemory() - java!java::lang::Runtime::getRuntime().freeMemory()) / (1024 * 1024) ++ 'MB']" />

<ee:transform>
    <!-- your transform -->
</ee:transform>

<!-- After transform -->
<logger level="INFO" message="#['Heap after: ' ++ (java!java::lang::Runtime::getRuntime().totalMemory() - java!java::lang::Runtime::getRuntime().freeMemory()) / (1024 * 1024) ++ 'MB']" />
```

**GC logging for detailed analysis (on-prem):**
```
# wrapper.conf (Java 17)
wrapper.java.additional.<n>=-Xlog:gc*:file=/opt/mule/logs/gc.log:time,tags:filecount=5,filesize=20m
```

### How It Works
1. DataWeave transforms are executed by the Mule runtime's embedded DataWeave engine
2. By default, the entire input payload is loaded into memory as a DataWeave value (tree structure)
3. The transform produces an output value also in memory, then serializes it to the output stream
4. Memory usage = input tree + output tree + intermediate values (variables, function results)
5. With `streaming=true`, DataWeave uses a pull-based model that reads input and writes output incrementally
6. Repeatable-file-store streams buffer to disk when the in-memory limit is reached

### Gotchas
- **Non-repeatable streams can't be read twice** — if you log `payload` before a transform, the stream is consumed. The transform gets an empty payload. Use `repeatable-file-store-stream` if you need multiple reads.
- **`streaming=true` doesn't help for all transforms** — operations that need the full dataset (sorting, groupBy, distinct) will still load everything into memory even with streaming enabled.
- **Lazy evaluation can surprise you** — DataWeave evaluates lazily in some cases. A variable assigned `payload.records` doesn't immediately consume memory, but iterating it twice may cause issues with non-repeatable streams.
- **`sizeOf()` forces full materialization** — calling `sizeOf(payload)` on a streamed payload loads the entire thing into memory. Use it only on small payloads or after chunking.
- **XML is the worst offender** — XML DOM representation in memory is 5-10x the file size. A 100MB XML file can consume 500MB-1GB of heap. Always stream XML.
- **Default `inMemorySize` for file store streams is 512KB** — if your average payload is 2MB, every request will spill to disk (slow). Increase `inMemorySize` to match your typical payload size.
- **DataWeave `log()` function holds references** — using `log()` in a large transform keeps debug objects in memory. Remove `log()` calls from production transforms.
- **Binary payloads (Base64)** — encoding/decoding Base64 in DataWeave creates a copy. A 100MB binary becomes a 133MB Base64 string plus the original bytes = 233MB minimum.

### Related
- [Memory Leak Detection Step-by-Step](../memory-leak-detection-step-by-step/) — heap dump analysis when the OOM isn't from a single transform
- [Batch Job Failure Analysis](../batch-job-failure-analysis/) — batch-specific memory management
- [Thread Dump Analysis](../thread-dump-analysis/) — when the app hangs during a large transform
- [Repeatable File Store Streaming](../../performance/streaming/repeatable-file-store/) — streaming configuration details
- [Non-Repeatable Stream](../../performance/streaming/non-repeatable-stream/) — when to use non-repeatable streams
- [In-Memory Sizing](../../performance/streaming/in-memory-sizing/) — tuning in-memory buffer sizes
