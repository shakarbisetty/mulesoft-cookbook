## Non-Repeatable Stream
> Disable repeatable streaming for fire-and-forget flows to eliminate I/O overhead.

### When to Use
- One-way flows where the payload is read exactly once
- Maximum throughput with minimal memory/disk usage
- VM publish, JMS publish, or logging-only flows

### Configuration / Code

```xml
<flow name="fire-and-forget-flow">
    <http:listener config-ref="HTTP_Listener" path="/ingest">
        <non-repeatable-stream/>
    </http:listener>
    <!-- Payload read once — no buffering overhead -->
    <vm:publish config-ref="VM_Config" queueName="processing">
        <vm:content>#[payload]</vm:content>
    </vm:publish>
</flow>
```

### How It Works
1. Payload is consumed directly from the source without buffering
2. No temp files, no in-memory copies — minimal resource usage
3. Once consumed, the stream cannot be rewound

### Gotchas
- Reading the payload a second time throws an error — the stream is consumed
- Do NOT use if any component after the first needs to read the payload again
- Logger with `#[payload]` counts as a read — move it before the main consumer or remove it

### Related
- [Repeatable File Store](../repeatable-file-store/) — when multiple reads are needed
- [In-Memory Sizing](../in-memory-sizing/) — small payloads that fit in heap
