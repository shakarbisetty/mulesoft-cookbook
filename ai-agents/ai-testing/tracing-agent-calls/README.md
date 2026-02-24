## Tracing AI Agent Calls
> Instrument AI agent interactions for debugging and performance analysis.

### When to Use
- Debugging complex multi-step agent workflows
- Performance profiling of AI call chains
- Audit trailing for compliance

### Configuration / Code

```xml
<flow name="traced-agent-flow">
    <http:listener config-ref="HTTP_Listener" path="/agent/task" method="POST"/>
    <set-variable variableName="traceId" value="#[uuid()]"/>
    <set-variable variableName="spans" value="#[output application/json --- []]"/>
    <!-- Span 1: LLM reasoning -->
    <set-variable variableName="spanStart" value="#[now()]"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="user" content="#[payload.task]"/>
        </ai:messages>
    </ai:chat-completions>
    <set-variable variableName="spans" value="#[vars.spans ++ [{
        name: llm-reasoning,
        duration: (now() - vars.spanStart) as Number {unit: milliseconds},
        tokens: payload.usage.total_tokens,
        model: payload.model
    }]]"/>
    <!-- Span 2: Tool execution -->
    <set-variable variableName="spanStart" value="#[now()]"/>
    <flow-ref name="execute-tool"/>
    <set-variable variableName="spans" value="#[vars.spans ++ [{
        name: tool-execution,
        duration: (now() - vars.spanStart) as Number {unit: milliseconds},
        tool: vars.toolName
    }]]"/>
    <!-- Log trace -->
    <logger message="#[output application/json --- {traceId: vars.traceId, spans: vars.spans}]"/>
</flow>
```

### How It Works
1. Each agent interaction gets a unique trace ID
2. Individual operations are wrapped in spans with timing
3. Spans capture duration, token usage, and tool names
4. Trace data is logged or sent to an observability platform

### Gotchas
- Manual instrumentation is tedious — consider OpenTelemetry auto-instrumentation
- Trace data volume can be large — sample in production
- Include both LLM latency and tool execution latency for full picture
- Correlate traces with user sessions for end-to-end visibility

### Related
- [Distributed Tracing](../../mcp-advanced/distributed-tracing/) — cross-service tracing
- [Response Quality Metrics](../response-quality-metrics/) — quality tracking
