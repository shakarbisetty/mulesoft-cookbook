## MCP and A2A Gateway
> Govern AI agent protocols (MCP tool calls, A2A task messages) through Flex Gateway with authentication, rate limiting, and audit logging

### When to Use
- Running MCP servers that expose tools to AI agents and need centralized access control
- Using Google A2A protocol for agent-to-agent communication and need traffic governance
- Must audit all agent-to-tool and agent-to-agent interactions for compliance
- Need to rate limit individual agents to prevent runaway tool invocations
- Want a single entry point for all agent protocol traffic with consistent security policies

### Configuration / Code

#### 1. MCP Tool Server Gateway Route

```yaml
# flex-gateway-config.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: mcp-gateway
  namespace: agent-services
spec:
  address: https://0.0.0.0:8443
  services:
    mcp-tools:
      address: http://mcp-server.internal:3000
      routes:
        # MCP protocol endpoints
        - path: /mcp/initialize
          methods: [POST]
        - path: /mcp/tools/list
          methods: [GET]
        - path: /mcp/tools/call
          methods: [POST]
        - path: /mcp/resources/list
          methods: [GET]
        - path: /mcp/resources/read
          methods: [POST]
        # SSE endpoint for streaming tool results
        - path: /mcp/sse
          methods: [GET]
    a2a-broker:
      address: http://a2a-broker.internal:4000
      routes:
        # A2A protocol endpoints
        - path: /a2a/agent-card
          methods: [GET]
        - path: /a2a/tasks/send
          methods: [POST]
        - path: /a2a/tasks/sendSubscribe
          methods: [POST]
        - path: /a2a/tasks/get
          methods: [GET]
        - path: /a2a/tasks/cancel
          methods: [POST]
  tls:
    certificate:
      path: /etc/flex-gateway/certs/tls.crt
    key:
      path: /etc/flex-gateway/certs/tls.key
```

#### 2. Agent Authentication Policy

```yaml
# policies/agent-authentication.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: agent-auth
  namespace: agent-services
spec:
  targetRef:
    kind: ApiInstance
    name: mcp-gateway
  policyRef:
    kind: Extension
    name: agent-identity-validator
  config:
    authMethods:
      # API key authentication for registered agents
      - type: apiKey
        headerName: x-agent-api-key
        validationEndpoint: https://identity.internal/v1/agents/validate
      # OAuth2 client credentials for service-to-service
      - type: oauth2ClientCredentials
        tokenUrl: https://auth.example.com/oauth/token
        introspectionUrl: https://auth.example.com/oauth/introspect
        requiredScopes:
          - mcp:tools:invoke
          - a2a:tasks:send
    # Extract agent identity from token/key for downstream headers
    identityExtraction:
      agentId: "#[vars.tokenClaims.agent_id]"
      agentName: "#[vars.tokenClaims.agent_name]"
      agentOwner: "#[vars.tokenClaims.owner]"
    # Inject identity headers for audit trail
    addHeaders:
      X-Verified-Agent-Id: "#[vars.agentId]"
      X-Verified-Agent-Name: "#[vars.agentName]"
      X-Verified-Agent-Owner: "#[vars.agentOwner]"
```

#### 3. MCP Tool Access Control Policy

```yaml
# policies/mcp-tool-acl.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: mcp-tool-access-control
  namespace: agent-services
spec:
  targetRef:
    kind: ApiInstance
    name: mcp-gateway
  policyRef:
    kind: Extension
    name: tool-access-control
  config:
    # Define which agents can invoke which tools
    accessRules:
      - agentPattern: "sentinel-*"
        allowedTools:
          - "search_patterns"
          - "classify_content"
          - "read_config"
        deniedTools:
          - "execute_code"
          - "write_file"
      - agentPattern: "alchemy-*"
        allowedTools:
          - "generate_video"
          - "render_scene"
          - "read_template"
        deniedTools:
          - "delete_*"
      - agentPattern: "admin-*"
        allowedTools: ["*"]  # Full access
    # Apply to tools/call endpoint only
    applyTo:
      paths:
        - /mcp/tools/call
    # Inspect request body to extract tool name
    toolNameExtractor: "#[payload.params.name]"
    deniedResponse:
      statusCode: 403
      body: |
        {
          "error": "tool_access_denied",
          "message": "Agent '#[vars.agentId]' is not authorized to invoke tool '#[vars.toolName]'",
          "allowedTools": "#[vars.allowedTools]"
        }
```

#### 4. Agent Rate Limiting Policy

```yaml
# policies/agent-rate-limit.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: agent-rate-limit
  namespace: agent-services
spec:
  targetRef:
    kind: ApiInstance
    name: mcp-gateway
  policyRef:
    kind: Extension
    name: sliding-window-rate-limit
  config:
    limits:
      # MCP tool invocations
      - path: /mcp/tools/call
        keySelector: "#[attributes.headers['x-verified-agent-id']]"
        maxRequests: 60
        windowSeconds: 60
        burstAllowance: 10
      # A2A task submissions
      - path: /a2a/tasks/send
        keySelector: "#[attributes.headers['x-verified-agent-id']]"
        maxRequests: 30
        windowSeconds: 60
      # A2A subscribe (long-running)
      - path: /a2a/tasks/sendSubscribe
        keySelector: "#[attributes.headers['x-verified-agent-id']]"
        maxRequests: 10
        windowSeconds: 60
    rateLimitResponse:
      statusCode: 429
      body: |
        {
          "error": "agent_rate_limited",
          "agentId": "#[vars.agentId]",
          "retryAfterSeconds": "#[vars.retryAfter]"
        }
      headers:
        Retry-After: "#[vars.retryAfter]"
```

#### 5. Agent Protocol Audit Logging

```yaml
# policies/agent-audit-log.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: agent-audit-log
  namespace: agent-services
spec:
  targetRef:
    kind: ApiInstance
    name: mcp-gateway
  policyRef:
    kind: Extension
    name: agent-audit-logger
  config:
    logDestination:
      type: http
      url: https://audit.internal.example.com/v1/agent-events
      batchSize: 50
      flushIntervalMs: 5000
    captureFields:
      request:
        - header: x-verified-agent-id
          as: agentId
        - header: x-verified-agent-name
          as: agentName
        - header: x-verified-agent-owner
          as: agentOwner
        - jsonPath: "$.method"
          as: protocolMethod
        # MCP-specific
        - jsonPath: "$.params.name"
          as: toolName
          onPath: /mcp/tools/call
        # A2A-specific
        - jsonPath: "$.params.message.parts[0].kind"
          as: messageKind
          onPath: /a2a/tasks/send
      response:
        - jsonPath: "$.result.isError"
          as: toolError
          onPath: /mcp/tools/call
        - jsonPath: "$.result.status.state"
          as: taskState
          onPath: /a2a/tasks/send
    eventFormat:
      type: structured-json
      includeTimestamp: true
      includeCorrelationId: true
      includeDuration: true
      includeRequestPath: true
```

#### 6. MCP Tool Registration with Gateway Endpoint

```json
{
  "mcpServer": {
    "name": "mulesoft-tools",
    "version": "1.0.0",
    "description": "MuleSoft platform tools accessible via MCP through Flex Gateway",
    "endpoint": "https://mcp-gateway.example.com:8443/mcp",
    "authentication": {
      "type": "apiKey",
      "header": "x-agent-api-key"
    },
    "tools": [
      {
        "name": "search_patterns",
        "description": "Search DataWeave patterns by keyword or category",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": {"type": "string"},
            "category": {"type": "string"}
          },
          "required": ["query"]
        }
      },
      {
        "name": "deploy_application",
        "description": "Deploy a Mule application to CloudHub 2.0",
        "inputSchema": {
          "type": "object",
          "properties": {
            "appName": {"type": "string"},
            "environment": {"type": "string", "enum": ["dev", "staging", "prod"]},
            "runtimeVersion": {"type": "string"}
          },
          "required": ["appName", "environment"]
        }
      }
    ]
  }
}
```

### How It Works
1. Flex Gateway sits in front of MCP servers and A2A brokers, acting as the single entry point for all agent protocol traffic
2. Agent authentication validates identity via API key or OAuth2 client credentials before any protocol message is processed
3. Tool access control inspects the MCP `tools/call` request body to extract the tool name and checks it against per-agent ACLs
4. Rate limiting uses a sliding window algorithm keyed by verified agent ID, preventing runaway agents from exhausting tool capacity
5. The audit logger captures protocol-level metadata (tool name, task state, agent identity) without logging full message content
6. For A2A, the gateway routes `tasks/send` to the broker which manages task lifecycle; `tasks/sendSubscribe` opens a streaming connection for real-time task updates

### Gotchas
- **SSE streaming for MCP**: MCP uses Server-Sent Events for streaming tool results. Flex Gateway must be configured with appropriate timeouts for SSE connections — the default HTTP request timeout (30s) will prematurely close the stream. Set `responseTimeout` to 300000ms (5 minutes) or higher for SSE endpoints.
- **A2A long-running task timeouts**: A2A tasks can run for minutes or hours. The `sendSubscribe` endpoint opens a long-lived HTTP connection for status updates. Configure Flex Gateway's idle connection timeout to at least 3600s for this endpoint, and ensure any intermediate load balancers also support long-lived connections.
- **Request body inspection cost**: Tool access control requires parsing the JSON request body to extract the tool name. For high-throughput scenarios (1000+ tool calls/second), this adds measurable latency. Consider caching parsed bodies or using header-based routing as an alternative.
- **Agent identity spoofing**: API key authentication is only as secure as the key management. If an agent's API key is compromised, an attacker can impersonate that agent. Use short-lived OAuth2 tokens with automatic rotation for production deployments.
- **A2A protocol version compatibility**: The A2A protocol is evolving rapidly (GA v1.0.0 released 2025). Ensure your gateway routes handle both the current spec and potential breaking changes in minor versions. Pin the A2A spec version in the route configuration.
- **MCP tool discovery caching**: The `tools/list` endpoint should be cached at the gateway level (5-minute TTL) to reduce load on MCP servers. Tools change infrequently, and every new agent connection calls `tools/list` on initialization.
- **Mixed protocol traffic**: Do not route MCP and A2A traffic through the same Flex Gateway instance in production if they have different SLA requirements. MCP tool calls are typically low-latency (< 1s), while A2A tasks can be long-running. Separate instances prevent noisy-neighbor effects.

### Related
- [llm-gateway-flex](../../../ai-agents/ai-gateway/llm-gateway-flex/) — LLM traffic governance through Flex Gateway
- [agent-governance](../../governance/agent-governance/) — Governance framework for AI agents consuming APIs
- [mcp-server-basics](../../../ai-agents/mcp-server-basics/) — Building MCP servers on MuleSoft
- [a2a-protocol](../../../ai-agents/a2a-protocol/) — A2A protocol implementation guide
- [rate-limit-sliding-window](../../../performance/api-performance/rate-limit-sliding-window/) — Sliding window rate limiting details
- [connected-vs-local](../connected-vs-local/) — Flex Gateway deployment modes
