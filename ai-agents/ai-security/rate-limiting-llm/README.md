## Rate Limiting for LLM APIs
> Apply per-team and per-model rate limits to control AI costs.

### When to Use
- Preventing runaway AI costs from uncontrolled usage
- Fair usage enforcement across teams
- Budget allocation for different AI models

### Configuration / Code

```xml
<flow name="rate-limited-ai">
    <http:listener config-ref="HTTP_Listener" path="/ai/chat" method="POST"/>
    <set-variable variableName="teamId" value="#[attributes.headers.'x-team-id']"/>
    <!-- Check rate limit -->
    <os:retrieve key="#[vars.teamId ++ ':count']" objectStore="rate-limit-store" target="count">
        <os:default-value>#[0]</os:default-value>
    </os:retrieve>
    <choice>
        <when expression="#[vars.count >= 1000]">
            <set-payload value='#[output application/json --- {
                error: "Rate limit exceeded",
                limit: 1000,
                resetAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
            }]'/>
            <set-variable variableName="httpStatus" value="429"/>
        </when>
        <otherwise>
            <!-- Increment counter -->
            <os:store key="#[vars.teamId ++ ':count']" objectStore="rate-limit-store">
                <os:value>#[vars.count + 1]</os:value>
            </os:store>
            <!-- Forward to LLM -->
            <flow-ref name="call-llm"/>
            <!-- Track token usage -->
            <os:retrieve key="#[vars.teamId ++ ':tokens']" objectStore="rate-limit-store" target="totalTokens">
                <os:default-value>#[0]</os:default-value>
            </os:retrieve>
            <os:store key="#[vars.teamId ++ ':tokens']" objectStore="rate-limit-store">
                <os:value>#[vars.totalTokens + payload.usage.total_tokens]</os:value>
            </os:store>
        </otherwise>
    </choice>
</flow>

<!-- Reset counters daily -->
<flow name="rate-limit-reset">
    <scheduler>
        <scheduling-strategy><cron expression="0 0 0 * * ?"/></scheduling-strategy>
    </scheduler>
    <os:clear objectStore="rate-limit-store"/>
    <logger message="Rate limit counters reset" level="INFO"/>
</flow>
```

**Object Store configuration:**
```xml
<os:object-store name="rate-limit-store"
                 persistent="true"
                 entryTtl="86400"
                 entryTtlUnit="SECONDS"
                 maxEntries="10000"/>
```

### How It Works
1. Each request includes `x-team-id` header identifying the calling team
2. Object Store tracks request count per team with a daily TTL
3. When count exceeds 1000, the flow returns HTTP 429 with reset time
4. Under the limit, the counter increments and the request forwards to the LLM
5. Token usage is also tracked per team for cost reporting
6. A scheduled flow resets all counters daily at midnight
7. Object Store persistence ensures counters survive application restarts

### Gotchas
- Use persistent Object Store — in-memory resets on redeployment, losing counters
- Set `entryTtl` to match your rate limit window (86400s = 24 hours)
- Token counting depends on LLM response format — OpenAI returns `usage.total_tokens`, others vary
- For CloudHub 2.0 multi-replica, use Anypoint MQ or distributed Object Store for shared state
- Consider separate limits per model (GPT-4 is 30x more expensive than GPT-3.5)

### Related
- [Token Usage Tracking](../../ai-gateway/token-usage-tracking/) — detailed cost monitoring
- [Model Fallback Chain](../../ai-gateway/model-fallback-chain/) — cost optimization via model routing
- [Credential Vault for AI](../credential-vault-ai/) — securing API keys per team
