## LLM Gateway with Flex Gateway
> Use Flex Gateway as an enterprise LLM gateway for AI governance: rate limiting, PII detection, audit logging, and multi-provider routing

### When to Use
- Enterprise teams consuming OpenAI, Anthropic, Azure OpenAI, or self-hosted LLMs
- Need centralized governance over all LLM API traffic (cost control, compliance, audit)
- Must detect and redact PII before it reaches external LLM providers
- Want token-based rate limiting instead of request-based rate limiting
- Need a single endpoint that routes to different LLM providers based on policy

### Configuration / Code

#### 1. Flex Gateway Route Configuration

```yaml
# flex-gateway-config.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: llm-gateway
  namespace: ai-services
spec:
  address: https://0.0.0.0:8443
  services:
    openai:
      address: https://api.openai.com
      routes:
        - path: /v1/chat/completions
        - path: /v1/embeddings
    anthropic:
      address: https://api.anthropic.com
      routes:
        - path: /v1/messages
    azure-openai:
      address: https://${AZURE_OPENAI_ENDPOINT}.openai.azure.com
      routes:
        - path: /openai/deployments/*/chat/completions
  tls:
    certificate:
      path: /etc/flex-gateway/certs/tls.crt
    key:
      path: /etc/flex-gateway/certs/tls.key
```

#### 2. Token-Based Rate Limiting Policy

```yaml
# policies/token-rate-limit.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: llm-token-rate-limit
  namespace: ai-services
spec:
  targetRef:
    kind: ApiInstance
    name: llm-gateway
  policyRef:
    kind: Extension
    name: token-rate-limiter
  config:
    # Rate limit by estimated input tokens (pre-request)
    inputTokenLimit:
      maxTokensPerMinute: 100000
      maxTokensPerHour: 2000000
      keySelector: "#[attributes.headers['x-agent-id']]"
    # Rate limit by actual output tokens (post-response)
    outputTokenLimit:
      maxTokensPerMinute: 50000
      keySelector: "#[attributes.headers['x-agent-id']]"
    # Fallback: request-based limit as safety net
    requestLimit:
      maxRequestsPerMinute: 200
      keySelector: "#[attributes.headers['x-agent-id']]"
    # Response when rate limited
    rateLimitResponse:
      statusCode: 429
      body: |
        {
          "error": "token_rate_limit_exceeded",
          "message": "Agent has exceeded token quota",
          "retryAfterSeconds": "#[vars.retryAfter]"
        }
      headers:
        Retry-After: "#[vars.retryAfter]"
        X-RateLimit-Remaining-Tokens: "#[vars.remainingTokens]"
```

#### 3. PII Detection and Redaction Policy

```yaml
# policies/pii-detection.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: llm-pii-detection
  namespace: ai-services
spec:
  targetRef:
    kind: ApiInstance
    name: llm-gateway
  policyRef:
    kind: Extension
    name: pii-scanner
  config:
    mode: redact  # Options: detect, redact, block
    scanFields:
      - path: "$.messages[*].content"
        type: request
      - path: "$.choices[*].message.content"
        type: response
    patterns:
      - name: ssn
        regex: "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        replacement: "[SSN-REDACTED]"
      - name: credit_card
        regex: "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
        replacement: "[CC-REDACTED]"
      - name: email
        regex: "\\b[\\w.+-]+@[\\w-]+\\.[\\w.]+\\b"
        replacement: "[EMAIL-REDACTED]"
      - name: phone
        regex: "\\b\\+?1?[-.]?\\(?\\d{3}\\)?[-.]?\\d{3}[-.]?\\d{4}\\b"
        replacement: "[PHONE-REDACTED]"
    onDetection:
      logLevel: WARN
      addHeader: "X-PII-Detected: true"
      # Block the request entirely if PII is found in mode: block
```

#### 4. Audit Logging Policy

```yaml
# policies/audit-logging.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: llm-audit-log
  namespace: ai-services
spec:
  targetRef:
    kind: ApiInstance
    name: llm-gateway
  policyRef:
    kind: Extension
    name: llm-audit-logger
  config:
    logDestination:
      type: http
      url: https://audit.internal.example.com/v1/events
      headers:
        Authorization: "Bearer ${AUDIT_API_KEY}"
    captureFields:
      request:
        - header: x-agent-id
          as: agentId
        - header: x-agent-purpose
          as: purpose
        - jsonPath: "$.model"
          as: model
        - jsonPath: "$.messages | length"
          as: messageCount
        - estimated: inputTokens
          as: estimatedInputTokens
      response:
        - jsonPath: "$.usage.prompt_tokens"
          as: promptTokens
        - jsonPath: "$.usage.completion_tokens"
          as: completionTokens
        - jsonPath: "$.usage.total_tokens"
          as: totalTokens
        - header: x-ratelimit-remaining-tokens
          as: remainingTokenQuota
    # DO NOT log message content — compliance requirement
    excludeFields:
      - "$.messages[*].content"
      - "$.choices[*].message.content"
    eventFormat:
      type: structured-json
      includeTimestamp: true
      includeCorrelationId: true
      includeDuration: true
```

#### 5. Multi-Provider Routing with Failover

```yaml
# policies/provider-routing.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: llm-provider-router
  namespace: ai-services
spec:
  targetRef:
    kind: ApiInstance
    name: llm-gateway
  policyRef:
    kind: Extension
    name: content-based-router
  config:
    routes:
      - condition: "#[attributes.headers['x-llm-provider'] == 'openai']"
        upstream: openai
        transformRequest:
          addHeaders:
            Authorization: "Bearer ${OPENAI_API_KEY}"
      - condition: "#[attributes.headers['x-llm-provider'] == 'anthropic']"
        upstream: anthropic
        transformRequest:
          addHeaders:
            x-api-key: "${ANTHROPIC_API_KEY}"
            anthropic-version: "2024-01-01"
      - condition: "#[attributes.headers['x-llm-provider'] == 'azure']"
        upstream: azure-openai
        transformRequest:
          addHeaders:
            api-key: "${AZURE_OPENAI_KEY}"
          rewritePath: "/openai/deployments/${AZURE_DEPLOYMENT}/chat/completions?api-version=2024-06-01"
    fallback:
      # If primary provider returns 5xx, fail over
      upstream: openai
      retryOn:
        - 500
        - 502
        - 503
      maxRetries: 1
      retryDelay: 1000
```

### How It Works
1. Flex Gateway acts as a reverse proxy sitting between your Mule applications (or any HTTP client) and external LLM providers
2. All LLM traffic flows through a single gateway endpoint, enabling centralized policy enforcement
3. The token-based rate limiter estimates input tokens before forwarding the request (using a tokenizer approximation) and tracks actual output tokens from the response `usage` field
4. PII detection scans the `messages[].content` field in the request body using regex patterns and either redacts, blocks, or logs matches before the payload reaches the LLM provider
5. The audit logger captures metadata (model, token counts, agent ID) without logging message content, satisfying compliance requirements
6. Content-based routing examines the `x-llm-provider` header to direct traffic to the correct upstream, with automatic failover on 5xx responses

### Gotchas
- **Streaming response handling**: When clients use `"stream": true` in the request body, the response is Server-Sent Events (SSE). PII detection on streaming responses requires buffering the entire stream before scanning, which defeats the purpose of streaming. For streaming, use detect-and-log mode instead of redact mode.
- **Token counting before response completes**: Input token estimation is approximate (whitespace tokenizer heuristic). The exact token count is only known from the provider's response `usage` field. Rate limiting on input tokens may over- or under-count by 10-15%.
- **Request body size**: LLM requests with large context windows (100K+ tokens) can produce request bodies of 500KB+. Ensure Flex Gateway's request body buffer size is configured to handle this (default is typically 1MB).
- **Anthropic API format differences**: Anthropic's Messages API uses a different request/response format than OpenAI's Chat Completions API. If you want a unified client interface, you need a request/response transformation policy — Flex Gateway alone does not normalize API formats.
- **Cost tracking**: Token-based rate limiting controls quota but does not track cost. Different models have different per-token prices. Implement cost calculation in the audit logger using model-to-price mapping.
- **API key rotation**: Store provider API keys in Anypoint Secrets Manager, not in policy YAML files. Rotate keys without redeploying the gateway by using dynamic secret references.
- **Latency overhead**: Each policy adds 1-5ms of processing time. With PII scanning on large payloads, expect 10-50ms overhead. For latency-critical applications, consider async PII scanning (log and scan post-hoc).

### Related
- [pii-masking-llm](../pii-masking-llm/) — Detailed PII masking patterns for LLM traffic
- [token-usage-tracking](../token-usage-tracking/) — Token consumption tracking and cost attribution
- [model-fallback-chain](../model-fallback-chain/) — Multi-model failover strategies
- [prompt-injection-detection](../prompt-injection-detection/) — Detecting prompt injection attacks
- [flex-ai-proxy](../flex-ai-proxy/) — Basic Flex Gateway AI proxy setup
- [mcp-a2a-gateway](../../../api-management/flex-gateway/mcp-a2a-gateway/) — Gateway for AI agent protocols
