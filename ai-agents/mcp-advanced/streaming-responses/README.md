## MCP Streaming Responses
> Stream large tool results back to AI agents using Server-Sent Events.

### When to Use
- Tool results too large to return in a single response
- Long-running tool executions needing progress updates
- Database queries returning thousands of rows

### Configuration / Code

```xml
<flow name="mcp-streaming-tool">
    <http:listener config-ref="HTTP_Listener" path="/mcp/tools/query-large-dataset">
        <http:response>
            <http:headers>#[{
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            }]</http:headers>
        </http:response>
    </http:listener>
    <db:select config-ref="Database_Config" fetchSize="100">
        <db:sql>SELECT * FROM large_table WHERE status = :status</db:sql>
        <db:input-parameters>#[{status: payload.params.status}]</db:input-parameters>
    </db:select>
    <!-- Stream results in batches -->
    <foreach batchSize="100">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output text/plain
---
"data: " ++ (write({
    jsonrpc: "2.0",
    result: {
        content: [{type: "text", text: write(payload, "application/json")}],
        isPartial: true,
        progress: {current: vars.counter, description: "Streaming batch..."}
    }
}, "application/json")) ++ "\n\n"
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </foreach>
    <!-- Final event: signal completion -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output text/plain
---
"data: " ++ (write({
    jsonrpc: "2.0",
    result: {content: [{type: "text", text: "Query complete"}], isPartial: false}
}, "application/json")) ++ "\n\n"
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. The HTTP listener returns `text/event-stream` content type for SSE
2. Database query uses `fetchSize="100"` for cursor-based streaming (avoids loading all rows)
3. Each batch of 100 rows is serialized as a JSON-RPC result with `isPartial: true`
4. Progress metadata (`current`, `description`) lets the client show streaming status
5. SSE format requires `data: ` prefix and `\n\n` separator between events
6. Final event sets `isPartial: false` to signal the stream is complete
7. Client accumulates partial results and presents the full dataset to the LLM

### Gotchas
- Set `fetchSize` on the DB query — without it, the entire result loads into memory
- CloudHub load balancers timeout idle connections after 5 minutes — send keepalives
- SSE events must be valid UTF-8 — binary data needs Base64 encoding
- Monitor heap usage during streaming — each batch consumes temporary memory
- Add `Cache-Control: no-cache` to prevent proxies from buffering the stream

### Related
- [MCP Resource Subscriptions](../resource-subscriptions/) — push-based alternative
- [DB Cursor Streaming](../../../performance/streaming/db-cursor-streaming/) — underlying streaming pattern
- [MCP Load Balanced Server](../load-balanced-server/) — scaling streaming endpoints
