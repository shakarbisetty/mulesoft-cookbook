## Response Quality Metrics
> Measure and track LLM response quality for continuous improvement.

### When to Use
- Monitoring AI response quality in production
- Comparing prompt versions for A/B testing
- Establishing quality baselines for AI features

### Configuration / Code

```xml
<flow name="quality-tracked-chat">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <flow-ref name="chat-completion-flow"/>
    <set-variable variableName="response" value="#[payload.choices[0].message.content]"/>
    <!-- Calculate quality metrics -->
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    responseLength: sizeOf(vars.response),
    tokenEfficiency: sizeOf(vars.response) / payload.usage.total_tokens,
    containsDisclaimer: vars.response contains "I am not sure" or vars.response contains "I cannot",
    model: payload.model,
    promptTokens: payload.usage.prompt_tokens,
    completionTokens: payload.usage.completion_tokens,
    timestamp: now()
}]]></ee:set-payload></ee:message>
    </ee:transform>
    <db:insert config-ref="Metrics_DB">
        <db:sql>INSERT INTO response_metrics (response_length, token_efficiency, has_disclaimer, model, timestamp)
                VALUES (:len, :eff, :disc, :model, :ts)</db:sql>
        <db:input-parameters>#[{len: payload.responseLength, eff: payload.tokenEfficiency, disc: payload.containsDisclaimer, model: payload.model, ts: payload.timestamp}]</db:input-parameters>
    </db:insert>
</flow>
```

### How It Works
1. Every LLM response is analyzed for quality signals
2. Metrics include length, token efficiency, and disclaimer presence
3. Metrics are stored in a database for trend analysis
4. Dashboards track quality over time and across prompt versions

### Gotchas
- Automated quality metrics are proxies — complement with human evaluation
- Token efficiency varies by language and topic — normalize comparisons
- Disclaimer rate increasing may indicate prompt degradation
- A/B testing requires statistically significant sample sizes

### Related
- [MUnit Mock LLM](../munit-mock-llm/) — testing AI flows
- [A/B Testing Prompts](../ab-testing-prompts/) — prompt experiments
