## Distributed Tracing for MCP Calls
> Trace AI agent tool calls end-to-end across MCP server, backends, and databases.

### When to Use
- Debugging slow tool executions
- Understanding the full call chain from AI agent to data source
- Performance optimization and bottleneck identification

### Configuration / Code

```xml
<flow name="mcp-traced-tool">
    <http:listener config-ref="HTTP_Listener" path="/mcp/tools/get-customer"/>
    <!-- Extract trace context from MCP request -->
    <set-variable variableName="traceId"
                  value="#[attributes.headers.traceparent default correlationId]"/>
    <logger message="MCP tool call started | traceId=#[vars.traceId] | tool=get-customer"/>
    <!-- Call backend with trace propagation -->
    <http:request config-ref="CRM_API" path="/customers/#[payload.params.customerId]">
        <http:headers>#[{"traceparent": vars.traceId}]</http:headers>
    </http:request>
    <logger message="MCP tool call completed | traceId=#[vars.traceId] | duration=#[now() - vars.startTime]"/>
</flow>
```

### How It Works
1. AI agent includes W3C Trace Context headers in MCP requests
2. MCP server extracts and propagates trace context to all downstream calls
3. Each hop adds its span to the distributed trace
4. Observability platform (Jaeger, Datadog) visualizes the full trace

### Gotchas
- MCP protocol does not mandate tracing — implement as a convention
- Trace context must be propagated through all async boundaries
- High-cardinality spans (per-record tracing) cause storage issues
- Sampling is essential for production — trace 1-10% of requests

### Related
- [Load Balanced Server](../load-balanced-server/) — multi-replica tracing
- [OTel Telemetry Export](../../../api-management/analytics/otel-telemetry-export/) — OTLP export
