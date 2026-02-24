## Multi-Model Router
> Route LLM requests to different models based on complexity, cost, or client tier.

### When to Use
- Cost optimization: simple queries to cheaper models, complex ones to premium
- A/B testing different models
- Fallback routing when primary model is unavailable

### Configuration / Code

```xml
<flow name="model-router">
    <http:listener config-ref="HTTP_Listener" path="/v1/chat/completions" method="POST"/>
    <choice>
        <!-- Premium tier clients get GPT-4 -->
        <when expression="#[attributes.headers.x-client-tier == premium]">
            <set-variable variableName="model" value="gpt-4"/>
            <flow-ref name="call-openai"/>
        </when>
        <!-- Long prompts get routed to Claude for larger context -->
        <when expression="#[sizeOf(payload.messages reduce ((m,a=) -> a ++ m.content)) > 10000]">
            <set-variable variableName="model" value="claude-sonnet-4-6-20250514"/>
            <flow-ref name="call-anthropic"/>
        </when>
        <!-- Default: fast and cheap -->
        <otherwise>
            <set-variable variableName="model" value="gpt-4o-mini"/>
            <flow-ref name="call-openai"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Inspect request metadata (client tier, prompt length, use case)
2. Route to the appropriate model/provider based on rules
3. Each provider has its own HTTP requester config
4. Response format is normalized before returning to the client

### Gotchas
- Different models have different response formats — normalize outputs
- Routing logic must be fast to avoid adding latency
- Monitor per-model costs and usage to validate routing effectiveness
- Fallback chains should have timeouts to prevent cascading delays

### Related
- [OpenAI Proxy](../openai-proxy/) — single-model proxy
- [Token Rate Limiting](../token-rate-limiting/) — per-model budgets
