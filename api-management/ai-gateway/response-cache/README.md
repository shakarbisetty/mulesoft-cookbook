## LLM Response Caching
> Cache identical LLM prompts to reduce cost and latency for repeated queries.

### When to Use
- FAQ-style chatbots where many users ask the same questions
- Deterministic prompts (temperature=0) with predictable outputs
- Reducing LLM API costs for high-volume applications

### Configuration / Code

```xml
<flow name="cached-llm-flow">
    <http:listener config-ref="HTTP_Listener" path="/v1/chat/completions" method="POST"/>
    <set-variable variableName="cacheKey"
                  value="#[%dw 2.0 output text/plain --- payload.messages reduce ((m, acc=) -> acc ++ m.content)]"/>
    <ee:cache cachingStrategy-ref="llm-cache"
              keyExpression="#[vars.cacheKey]">
        <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST"/>
    </ee:cache>
</flow>

<os:object-store name="llm-cache" persistent="true" entryTtl="3600" entryTtlUnit="SECONDS"/>
```

### How It Works
1. Generate a cache key from the concatenated message contents
2. Check if an identical prompt was recently answered
3. On cache hit, return the cached response instantly (no LLM call)
4. On cache miss, call the LLM and cache the response for 1 hour

### Gotchas
- Only cache deterministic responses (temperature=0, no randomness)
- Cache key must include all relevant parameters (model, messages, temperature)
- Large responses consume Object Store quota — monitor storage usage
- Cache invalidation is time-based only — no way to purge specific answers

### Related
- [Token Rate Limiting](../token-rate-limiting/) — cost control
- [Cache Scope Object Store](../../../performance/caching/cache-scope-object-store/) — general caching
