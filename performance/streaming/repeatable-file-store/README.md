## Repeatable File Store Streaming
> Configure file-based repeatable streaming with tuned buffer sizes for large payloads.

### When to Use
- Processing payloads >256 KB that need multiple reads
- CloudHub deployments where heap is limited
- File integrations handling 10 MB–1 GB CSV/XML files

### Configuration / Code

```xml
<flow name="large-file-flow">
    <http:listener config-ref="HTTP_Listener" path="/upload">
        <repeatable-file-store-stream
            inMemorySize="512"
            bufferSizeIncrement="256"
            maxInMemorySize="1024"
            bufferUnit="KB"/>
    </http:listener>
    <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map { id: $.id, name: upper($.name) }]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <logger level="INFO" message="Processed #[sizeOf(payload)] records"/>
</flow>
```

**Per vCore sizing:**
| vCore | inMemorySize | maxInMemorySize |
|-------|-------------|-----------------|
| 0.1 | 64 KB | 128 KB |
| 0.5 | 256 KB | 512 KB |
| 1.0 | 1 MB | 2 MB |
| 4.0 | 4 MB | 8 MB |

### How It Works
1. Mule reads the first `inMemorySize` bytes into heap
2. Overflow spills to a temp file on disk
3. Subsequent reads rewind the stream from the file
4. Temp files are cleaned up when the event completes

### Gotchas
- Temp files go to `java.io.tmpdir` — monitor disk on CloudHub
- File I/O adds 5–20 ms latency per read
- `bufferUnit` defaults to BYTE if omitted — creates tiny buffers
- Stream is only repeatable within the same event

### Related
- [Non-Repeatable Stream](../non-repeatable-stream/) — disable for one-time reads
- [In-Memory Sizing](../in-memory-sizing/) — tune when payloads fit in memory
- [Large Payload OOM](../../memory/large-payload-oom/) — streaming for 100 MB+ files
