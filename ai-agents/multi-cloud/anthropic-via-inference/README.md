## Anthropic Models via MuleSoft
> Integrate Anthropic Claude models using HTTP requester.

### When to Use
- Using Claude models for their strengths (long context, reasoning)
- Multi-provider AI strategy with MuleSoft as the integration layer
- Applications requiring 200K+ token context windows

### Configuration / Code

```xml
<http:request-config name="Anthropic_Config">
    <http:request-connection host="api.anthropic.com" protocol="HTTPS">
        <http:default-headers>
            <http:header key="x-api-key" value="${secure::anthropic.api.key}"/>
            <http:header key="anthropic-version" value="2023-06-01"/>
            <http:header key="Content-Type" value="application/json"/>
        </http:default-headers>
    </http:request-connection>
</http:request-config>

<flow name="anthropic-inference">
    <http:listener config-ref="HTTP_Listener" path="/ai/anthropic" method="POST"/>
    <http:request config-ref="Anthropic_Config" path="/v1/messages" method="POST">
        <http:body>#[output application/json --- {
            model: "claude-sonnet-4-6-20250514",
            max_tokens: 1024,
            messages: [{role: "user", content: payload.prompt}]
        }]</http:body>
    </http:request>
    <set-payload value="#[output application/json --- {
        response: payload.content[0].text,
        model: payload.model,
        tokens: payload.usage.input_tokens + payload.usage.output_tokens
    }]"/>
</flow>
```

### How It Works
1. HTTP requester connects to the Anthropic Messages API
2. API key and version header are set in the connection config
3. Request includes model, max_tokens, and messages array
4. Response content is extracted from the content array

### Gotchas
- Anthropic API format differs from OpenAI — content is an array of blocks
- `anthropic-version` header is required — check for the latest version
- Claude models have different token limits than GPT models
- Streaming uses SSE with different event types than OpenAI

### Related
- [OpenAI via Inference](../openai-via-inference/) — OpenAI integration
- [Model Fallback Chain](../../ai-gateway/model-fallback-chain/) — multi-provider fallback
