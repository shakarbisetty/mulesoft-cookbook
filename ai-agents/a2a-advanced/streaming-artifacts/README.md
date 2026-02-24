## A2A Streaming Artifacts
> Stream large artifacts (documents, datasets) between agents using A2A protocol.

### When to Use
- Agents producing large outputs (reports, datasets, code)
- Progressive result delivery for long-running tasks
- Memory-efficient transfer of large payloads

### Configuration / Code

```xml
<flow name="a2a-streaming-response">
    <http:listener config-ref="HTTP_Listener" path="/a2a/tasks/sendSubscribe" method="POST">
        <http:response>
            <http:headers>#[{"Content-Type": "text/event-stream"}]</http:headers>
        </http:response>
    </http:listener>
    <!-- Stream task updates as SSE events -->
    <set-variable variableName="taskId" value="#[payload.params.id]"/>
    <flow-ref name="process-task-async"/>
</flow>

<sub-flow name="process-task-async">
    <!-- Phase 1: Acknowledge with "working" status -->
    <set-payload value='#[output text/plain ---
"data: " ++ (output application/json --- {
    jsonrpc: "2.0",
    result: {id: vars.taskId, status: {state: "working", message: "Processing..."}}
}) ++ "\n\n"
    ]'/>
    <!-- Phase 2: Stream artifact parts -->
    <foreach collection="#[1 to 5]">
        <flow-ref name="generate-report-section"/>
        <set-payload value='#[output text/plain ---
"data: " ++ (output application/json --- {
    jsonrpc: "2.0",
    result: {
        id: vars.taskId,
        status: {state: "working"},
        artifacts: [{
            name: "report",
            parts: [{type: "text", text: payload}],
            metadata: {section: vars.counter, total: 5}
        }]
    }
}) ++ "\n\n"
        ]'/>
    </foreach>
    <!-- Phase 3: Final "completed" event -->
    <set-payload value='#[output text/plain ---
"data: " ++ (output application/json --- {
    jsonrpc: "2.0",
    result: {id: vars.taskId, status: {state: "completed"}}
}) ++ "\n\n"
    ]'/>
</sub-flow>
```

### How It Works
1. Client sends `tasks/sendSubscribe` to request streaming updates
2. Server responds with `Content-Type: text/event-stream` for SSE
3. First event sends `working` status to acknowledge the request
4. Each report section streams as a separate SSE `data:` event with artifact parts
5. Artifacts include metadata (`section`, `total`) for client-side progress tracking
6. Final event sends `completed` status signaling the stream is done
7. Client reconstructs the full document by concatenating artifact parts in order

### Gotchas
- SSE format requires `data: ` prefix and double newline `\n\n` after each event
- Keep individual events under 64 KB — split large sections into multiple events
- Add heartbeat events (empty `data: \n\n`) every 30s to prevent proxy timeouts
- Client must handle reconnection if the stream drops mid-transfer
- CloudHub 2.0 load balancers have a 5-minute idle timeout — send keepalives

### Related
- [MCP Streaming Responses](../../mcp-advanced/streaming-responses/) — similar pattern for MCP tools
- [A2A Push Notifications](../push-notifications/) — webhook-based alternative to streaming
- [A2A Multi-Agent Orchestration](../multi-agent-orchestration/) — streaming in multi-agent flows
