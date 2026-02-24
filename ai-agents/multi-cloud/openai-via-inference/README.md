## OpenAI via MuleSoft Inference Connector
> Call OpenAI models using the MuleSoft AI/ML Inference Connector.

### When to Use
- Standardized AI integration using MuleSoft native connectors
- Leveraging MuleSoft error handling and retry for AI calls
- Teams already familiar with MuleSoft connector patterns

### Configuration / Code

```xml
<ai:config name="OpenAI_Config">
    <ai:openai-connection
        apiKey="${secure::openai.api.key}"
        model="gpt-4o"
        baseUrl="https://api.openai.com/v1"/>
</ai:config>

<flow name="openai-inference">
    <http:listener config-ref="HTTP_Listener" path="/ai/openai" method="POST"/>
    <ai:chat-completions config-ref="OpenAI_Config">
        <ai:messages>
            <ai:message role="system" content="You are a helpful assistant."/>
            <ai:message role="user" content="#[payload.prompt]"/>
        </ai:messages>
        <ai:parameters temperature="0.7" maxTokens="1000"/>
    </ai:chat-completions>
    <set-payload value="#[output application/json --- {
        response: payload.choices[0].message.content,
        model: payload.model,
        tokens: payload.usage.total_tokens
    }]"/>
</flow>
```

### How It Works
1. AI Connector abstracts the OpenAI REST API into a Mule component
2. Connection config handles API key management and base URL
3. Chat completions operation sends messages and returns structured response
4. Standard Mule error handling applies (retry, fallback, logging)

### Gotchas
- Store API keys in secure properties — never hardcode
- Connector version must support the OpenAI model you want to use
- Streaming mode requires different handling (SSE events)
- Response timeout should be generous (30-60s for complex prompts)

### Related
- [Azure OpenAI](../azure-openai/) — Azure-hosted models
- [Model Fallback Chain](../../ai-gateway/model-fallback-chain/) — multi-provider fallback
