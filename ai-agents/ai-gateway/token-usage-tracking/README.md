## Token Usage Tracking
> Track and report LLM token consumption per team, application, and model.

### When to Use
- Cost allocation for AI usage across departments
- Budget enforcement and usage alerts
- Capacity planning for AI infrastructure

### Configuration / Code

```xml
<flow name="tracked-llm-call">
    <http:listener config-ref="HTTP_Listener" path="/v1/chat/completions" method="POST"/>
    <set-variable variableName="startTime" value="#[now()]"/>
    <set-variable variableName="teamId" value="#[attributes.headers.x-team-id]"/>
    <!-- Forward to LLM -->
    <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST"/>
    <!-- Track usage -->
    <db:insert config-ref="Usage_DB">
        <db:sql>INSERT INTO token_usage (team_id, model, prompt_tokens, completion_tokens, total_tokens, cost_usd, timestamp)
                VALUES (:team, :model, :prompt, :completion, :total, :cost, :ts)</db:sql>
        <db:input-parameters>#[{
            team: vars.teamId,
            model: payload.model,
            prompt: payload.usage.prompt_tokens,
            completion: payload.usage.completion_tokens,
            total: payload.usage.total_tokens,
            cost: (payload.usage.prompt_tokens * 0.00001) + (payload.usage.completion_tokens * 0.00003),
            ts: now()
        }]</db:input-parameters>
    </db:insert>
</flow>
```

### How It Works
1. Every LLM call passes through the tracking proxy
2. Response includes `usage` object with token counts
3. Token counts and estimated costs are stored in a tracking database
4. Reports aggregate by team, model, and time period

### Gotchas
- Cost calculation varies by model — maintain a pricing table
- Streaming responses report usage in the final chunk only
- Tracking adds ~5ms latency per call (database insert)
- Use async inserts for high-throughput scenarios

### Related
- [Flex AI Proxy](../flex-ai-proxy/) — centralized AI gateway
- [Rate Limiting LLM](../../ai-security/rate-limiting-llm/) — usage limits
