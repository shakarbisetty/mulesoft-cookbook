## In-Memory Stream Sizing
> Tune initialBufferSize and maxBufferSize for payloads that fit entirely in memory.

### When to Use
- Payloads consistently under 1 MB
- Low-latency APIs where disk I/O is unacceptable
- Known, bounded payload sizes

### Configuration / Code

```xml
<flow name="small-payload-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/data">
        <repeatable-in-memory-stream
            initialBufferSize="128"
            bufferSizeIncrement="64"
            maxBufferSize="512"
            bufferUnit="KB"/>
    </http:listener>
    <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. Mule allocates `initialBufferSize` bytes in heap
2. If payload exceeds it, buffer grows by `bufferSizeIncrement` chunks
3. If payload exceeds `maxBufferSize`, Mule throws STREAM_MAXIMUM_SIZE_EXCEEDED
4. Stream is fully in memory — no disk I/O

### Gotchas
- If payload exceeds `maxBufferSize`, it throws an error — not a graceful fallback
- Over-allocating wastes heap; under-allocating causes errors on larger payloads
- Each concurrent request gets its own buffer — multiply by maxConcurrency for true memory impact

### Related
- [Repeatable File Store](../repeatable-file-store/) — fallback for larger payloads
- [Threshold Per vCore](../threshold-per-vcore/) — size buffers per worker memory
