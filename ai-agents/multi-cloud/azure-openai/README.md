## Azure OpenAI Integration
> Connect to Azure-hosted OpenAI models for enterprise-grade AI with Azure compliance.

### When to Use
- Enterprise requirements for data residency (Azure regions)
- Azure AD integration for authentication
- Private network deployment of LLM models

### Configuration / Code

```xml
<http:request-config name="Azure_OpenAI_Config">
    <http:request-connection host="${azure.openai.endpoint}" protocol="HTTPS">
        <http:default-headers>
            <http:header key="api-key" value="${secure::azure.openai.key}"/>
            <http:header key="Content-Type" value="application/json"/>
        </http:default-headers>
    </http:request-connection>
</http:request-config>

<flow name="azure-openai-inference">
    <http:listener config-ref="HTTP_Listener" path="/ai/azure" method="POST"/>
    <http:request config-ref="Azure_OpenAI_Config"
                  path="/openai/deployments/${azure.deployment.name}/chat/completions"
                  method="POST">
        <http:query-params>#[{"api-version": "2024-02-01"}]</http:query-params>
        <http:body>#[output application/json --- {
            messages: [{role: "user", content: payload.prompt}],
            temperature: 0.7,
            max_tokens: 1000
        }]</http:body>
    </http:request>
</flow>
```

### How It Works
1. Azure OpenAI uses deployment names instead of model names
2. API version is passed as a query parameter
3. Authentication uses an API key or Azure AD token
4. Response format matches the OpenAI API specification

### Gotchas
- Azure endpoint URL is region-specific (e.g., `eastus.api.cognitive.microsoft.com`)
- Deployment names must match your Azure resource configuration
- `api-version` changes frequently — pin to a stable version
- Azure AD auth is more complex but more secure than API keys

### Related
- [OpenAI via Inference](../openai-via-inference/) — direct OpenAI
- [Flex AI Proxy](../../ai-gateway/flex-ai-proxy/) — centralized AI gateway
