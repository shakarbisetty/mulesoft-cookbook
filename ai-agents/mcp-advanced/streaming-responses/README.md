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
            <http:headers>#[{"Content-Type": "text/event-stream", "Cache-Control": "no-cache"}]</http:headers>
        </http:response>
    </http:listener>
    <db:select config-ref="Database_Config" fetchSize="100">
        <db:sql>SELECT * FROM large_table WHERE status = :status</db:sql>
        <db:input-parameters>#[{status: payload.params.status}]</db:input-parameters>
    </db:select>
    <foreach>
        <set-payload value="#[output text/plain --- data:
