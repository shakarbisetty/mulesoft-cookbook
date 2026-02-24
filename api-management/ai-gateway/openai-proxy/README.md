## OpenAI Proxy via Flex Gateway
> Route OpenAI API calls through Flex Gateway for governance, caching, and observability.

### When to Use
- Centralized LLM access control across teams
- Applying rate limiting and token budgets to AI calls
- Audit logging of all LLM interactions

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: openai-proxy
spec:
  address: http://0.0.0.0:8081
  services:
    openai:
      address: https://api.openai.com
      routes:
        - rules:
          - path: /v1/chat/completions
            methods: [POST]
          config:
            destinationPath: /v1/chat/completions

---
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: openai-auth
spec:
  targetRef:
    name: openai-proxy
  policyRef:
    name: header-injection
  config:
    inboundHeaders:
    - key: Authorization
      value: "Bearer ${OPENAI_API_KEY}"
```

### How It Works
1. Applications call the gateway instead of OpenAI directly
2. Gateway injects the API key via header injection policy
3. Rate limiting, logging, and caching policies apply transparently
4. Applications never see or manage the OpenAI API key

### Gotchas
- Streaming responses (`stream: true`) require SSE-aware proxy configuration
- Request/response bodies can be large — adjust payload size limits
- OpenAI API keys should be stored in a secrets manager, not YAML
- Latency overhead is minimal (~5ms) but measure for latency-sensitive use cases

### Related
- [Token Rate Limiting](../token-rate-limiting/) — limit by token count
- [Response Cache](../response-cache/) — cache identical prompts
