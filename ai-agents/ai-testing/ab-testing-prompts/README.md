## A/B Testing Prompts
> Compare prompt variations to optimize LLM response quality and cost.

### When to Use
- Optimizing prompt wording for better responses
- Comparing system prompt strategies
- Data-driven prompt engineering decisions

### Configuration / Code

```xml
<flow name="ab-test-prompt">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <!-- Random assignment to variant -->
    <set-variable variableName="variant" value="#[if (randomInt(100) < 50) A else B]"/>
    <choice>
        <when expression="#[vars.variant == A]">
            <set-variable variableName="systemPrompt"
                          value="You are a helpful assistant. Be concise and direct."/>
        </when>
        <otherwise>
            <set-variable variableName="systemPrompt"
                          value="You are an expert assistant. Think step by step before answering. Be thorough."/>
        </otherwise>
    </choice>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="#[vars.systemPrompt]"/>
            <ai:message role="user" content="#[payload.message]"/>
        </ai:messages>
    </ai:chat-completions>
    <!-- Track variant performance -->
    <db:insert config-ref="AB_Test_DB">
        <db:sql>INSERT INTO prompt_experiments (variant, tokens_used, response_length, timestamp)
                VALUES (:variant, :tokens, :len, :ts)</db:sql>
        <db:input-parameters>#[{variant: vars.variant, tokens: payload.usage.total_tokens,
            len: sizeOf(payload.choices[0].message.content), ts: now()}]</db:input-parameters>
    </db:insert>
</flow>
```

### How It Works
1. Each request is randomly assigned to a prompt variant (50/50 split)
2. Different system prompts are used for each variant
3. Response metrics (tokens, length) are recorded per variant
4. Statistical analysis determines which variant performs better

### Gotchas
- Need sufficient sample size for statistical significance (100+ per variant)
- User satisfaction is the ultimate metric — proxy metrics may mislead
- Run experiments long enough to account for time-of-day effects
- Only test one variable at a time (system prompt OR temperature, not both)

### Related
- [Prompt Templates](../../inference/prompt-templates/) — managing prompts
- [Response Quality Metrics](../response-quality-metrics/) — quality measurement
