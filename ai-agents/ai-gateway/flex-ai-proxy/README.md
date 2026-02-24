## Flex Gateway as AI API Proxy
> Route all LLM API calls through Flex Gateway for centralized governance.

### When to Use
- Enterprise-wide AI governance and cost control
- Applying consistent policies across all LLM consumers
- Single entry point for multiple AI model providers

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: ai-gateway
spec:
  address: http://0.0.0.0:8081
  services:
    openai:
      address: https://api.openai.com
      routes:
      - rules:
        - path: /v1/chat/completions
        - path: /v1/embeddings
    anthropic:
      address: https://api.anthropic.com
      routes:
      - rules:
        - path: /v1/messages

---
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: ai-rate-limit
spec:
  targetRef:
    name: ai-gateway
  policyRef:
    name: rate-limiting
  config:
    keySelector: "#[attributes.headers.x-team-id]"
    rateLimits:
    - maximumRequests: 1000
      timePeriodInMilliseconds: 3600000
```

### How It Works
1. All AI API calls go through Flex Gateway instead of direct provider access
2. Gateway routes to the correct provider based on the URL path
3. Rate limiting, logging, and security policies apply uniformly
4. API keys are injected at the gateway — teams never see provider credentials

### Gotchas
- Streaming responses (SSE) need proper gateway configuration
- Large request/response bodies (images, embeddings) need size limit adjustments
- Provider-specific headers must be passed through or mapped
- Gateway adds ~5ms latency — negligible for LLM calls

### Related
- [PII Masking](../pii-masking-llm/) — data protection
- [Token Usage Tracking](../token-usage-tracking/) — cost monitoring
