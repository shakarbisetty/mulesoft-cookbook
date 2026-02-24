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
    <set-payload value="#[output text/plain --- data:
