## Token-Based Rate Limiting for LLMs
> Rate-limit LLM API calls based on token consumption rather than request count.

### When to Use
- Controlling LLM costs by limiting token budgets per client
- Fair usage enforcement when different requests consume vastly different token counts
- Budget allocation across teams or applications

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: token-rate-limit
spec:
  targetRef:
    name: openai-proxy
  policyRef:
    name: rate-limiting
  config:
    keySelector: "#[attributes.headers.x-client-id]"
    rateLimits:
    - maximumRequests: 100000
      timePeriodInMilliseconds: 3600000
    exposeHeaders: true
```

**Mule 4 implementation for token counting:**
```xml
<flow name="token-budget-check">
    <http:listener config-ref="HTTP_Listener" path="/v1/chat/completions" method="POST"/>
    <os:retrieve key="#[attributes.headers.x-client-id ++ -tokens]" objectStore="token-budget" target="used"/>
    <choice>
        <when expression="#[vars.used default 0 > 100000]">
            <set-payload value=Token budget exceeded/>
            <http:response statusCode="429"/>
        </when>
        <otherwise>
            <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST"/>
            <os:store key="#[attributes.headers.x-client-id ++ -tokens]" objectStore="token-budget">
                <os:value>#[(vars.used default 0) + payload.usage.total_tokens]</os:value>
            </os:store>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Each request is tracked by client ID
2. Token usage from the LLM response (`usage.total_tokens`) is accumulated
3. When the budget is exceeded, requests are rejected with 429
4. Budget resets based on the Object Store TTL (hourly/daily)

### Gotchas
- Token count is only known AFTER the LLM responds — budget enforcement is post-hoc
- Streaming responses require parsing SSE chunks to extract token counts
- `max_tokens` in the request is an estimate — actual usage may differ
- Shared Object Store adds ~5ms latency per budget check

### Related
- [OpenAI Proxy](../openai-proxy/) — gateway setup
- [SLA Tiers](../../rate-limiting/sla-tiers/) — tiered rate limiting
