## Agent Governance Framework
> Governance framework for AI agents consuming APIs: identity management, scope restrictions, audit trails, and policy enforcement

### When to Use
- AI agents (LLM-powered, RPA, or autonomous) are consuming your MuleSoft APIs
- Need to distinguish agent traffic from human traffic for monitoring and rate limiting
- Compliance requires a full audit trail of all agent API interactions
- Must enforce least-privilege access: each agent gets only the API scopes it needs
- Want to prevent agent identity spoofing and unauthorized escalation

### Configuration / Code

#### 1. Agent Identity Registration (Anypoint Platform)

```json
{
  "agentRegistration": {
    "agentId": "sentinel-content-analyzer",
    "agentName": "Sentinel Content Analyzer",
    "owner": "content-ops-team",
    "ownerEmail": "content-ops@example.com",
    "agentType": "llm-powered",
    "model": "gpt-4",
    "purpose": "Analyze content patterns and generate classification metadata",
    "registeredDate": "2026-02-15T00:00:00Z",
    "apiAccess": {
      "clientId": "${AGENT_CLIENT_ID}",
      "clientSecret": "${AGENT_CLIENT_SECRET}",
      "grantType": "client_credentials",
      "scopes": [
        "content:read",
        "patterns:search",
        "classifications:write"
      ]
    },
    "rateLimits": {
      "requestsPerMinute": 60,
      "requestsPerDay": 10000,
      "tokensPerDay": 500000
    },
    "restrictions": {
      "allowedEnvironments": ["dev", "staging"],
      "allowedIpRanges": ["10.0.0.0/8"],
      "deniedEndpoints": ["/admin/*", "/users/*/delete"]
    }
  }
}
```

#### 2. Custom Policy: Agent Header Validation

```yaml
# policies/agent-header-validation.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: agent-header-validation
  namespace: api-governance
spec:
  targetRef:
    kind: ApiInstance
    name: enterprise-api
  policyRef:
    kind: Extension
    name: agent-header-validator
  config:
    # Required headers for all agent traffic
    requiredHeaders:
      - name: X-Agent-Id
        pattern: "^[a-z0-9][a-z0-9-]{2,63}$"
        description: "Registered agent identifier"
      - name: X-Agent-Purpose
        maxLength: 256
        description: "Human-readable purpose for this API call"
      - name: X-Agent-Model
        pattern: "^(gpt-4|gpt-3\\.5|claude-[a-z0-9-]+|gemini-[a-z0-9-]+|llama-[a-z0-9-]+|custom)$"
        description: "AI model powering this agent"
    # Optional but recommended headers
    optionalHeaders:
      - name: X-Agent-Conversation-Id
        description: "Correlation ID for multi-turn agent conversations"
      - name: X-Agent-Tool-Call-Id
        description: "MCP or function-calling tool invocation ID"
    # How to detect agent traffic (if headers are missing)
    agentDetection:
      userAgentPatterns:
        - "^OpenAI/"
        - "^Anthropic/"
        - "^LangChain/"
        - "^AutoGPT/"
      # If agent is detected but required headers are missing
      onMissingHeaders: reject
      rejectionResponse:
        statusCode: 400
        body: |
          {
            "error": "agent_headers_required",
            "message": "AI agent traffic must include X-Agent-Id, X-Agent-Purpose, and X-Agent-Model headers",
            "documentation": "https://docs.example.com/agent-governance"
          }
```

#### 3. Agent Scope Enforcement Policy

```yaml
# policies/agent-scope-enforcement.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: agent-scope-enforcement
  namespace: api-governance
spec:
  targetRef:
    kind: ApiInstance
    name: enterprise-api
  policyRef:
    kind: Extension
    name: scope-enforcer
  config:
    scopeMapping:
      # Map API endpoints to required scopes
      - path: /api/content/**
        methods: [GET]
        requiredScopes: ["content:read"]
      - path: /api/content/**
        methods: [POST, PUT]
        requiredScopes: ["content:write"]
      - path: /api/patterns/search
        methods: [GET, POST]
        requiredScopes: ["patterns:search"]
      - path: /api/classifications/**
        methods: [POST]
        requiredScopes: ["classifications:write"]
      - path: /api/admin/**
        methods: [GET, POST, PUT, DELETE]
        requiredScopes: ["admin:full"]
        agentAccess: denied  # No agent can access admin endpoints
    # Scope validation source
    scopeSource: oauth2TokenClaims
    scopeClaim: scope
    # Response when scope is insufficient
    insufficientScopeResponse:
      statusCode: 403
      body: |
        {
          "error": "insufficient_scope",
          "requiredScopes": "#[vars.requiredScopes]",
          "agentScopes": "#[vars.agentScopes]",
          "agentId": "#[vars.agentId]"
        }
```

#### 4. Agent Audit Trail Configuration

```xml
<!-- Mule flow: Agent audit trail logger -->
<flow name="agent-audit-trail">
    <http:listener config-ref="Internal_Listener"
                   path="/v1/agent-events"
                   doc:name="Audit Event Receiver" />

    <!-- Validate audit event schema -->
    <ee:transform doc:name="Normalize Audit Event">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    eventId: uuid(),
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"},
    agentId: payload.agentId,
    agentName: payload.agentName,
    agentOwner: payload.agentOwner,
    agentModel: payload.agentModel default "unknown",
    action: {
        method: payload.httpMethod,
        path: payload.requestPath,
        statusCode: payload.responseStatusCode,
        durationMs: payload.durationMs
    },
    context: {
        purpose: payload.purpose default "not specified",
        conversationId: payload.conversationId,
        toolCallId: payload.toolCallId,
        environment: p('mule.env')
    },
    riskSignals: {
        isEscalation: payload.requestPath contains "/admin",
        isDataExport: payload.responseSize > 1048576,
        isHighFrequency: payload.requestsInLastMinute > 50,
        isScopeViolation: payload.scopeViolation default false
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Persist to audit database -->
    <db:insert config-ref="Audit_Database"
               doc:name="Insert Audit Event">
        <db:sql>
            INSERT INTO agent_audit_events (
                event_id, timestamp, agent_id, agent_name, agent_owner,
                agent_model, http_method, request_path, status_code,
                duration_ms, purpose, conversation_id, environment,
                is_escalation, is_data_export, is_high_frequency
            ) VALUES (
                :eventId, :timestamp, :agentId, :agentName, :agentOwner,
                :agentModel, :method, :path, :statusCode,
                :durationMs, :purpose, :conversationId, :environment,
                :isEscalation, :isDataExport, :isHighFrequency
            )
        </db:sql>
        <db:input-parameters><![CDATA[#[{
            eventId: payload.eventId,
            timestamp: payload.timestamp,
            agentId: payload.agentId,
            agentName: payload.agentName,
            agentOwner: payload.agentOwner,
            agentModel: payload.agentModel,
            method: payload.action.method,
            path: payload.action.path,
            statusCode: payload.action.statusCode,
            durationMs: payload.action.durationMs,
            purpose: payload.context.purpose,
            conversationId: payload.context.conversationId,
            environment: payload.context.environment,
            isEscalation: payload.riskSignals.isEscalation,
            isDataExport: payload.riskSignals.isDataExport,
            isHighFrequency: payload.riskSignals.isHighFrequency
        }]]]></db:input-parameters>
    </db:insert>

    <!-- Alert on risk signals -->
    <choice doc:name="Risk Signal Router">
        <when expression="#[payload.riskSignals.isEscalation]">
            <flow-ref name="alert-escalation-attempt" />
        </when>
        <when expression="#[payload.riskSignals.isHighFrequency]">
            <flow-ref name="alert-high-frequency" />
        </when>
    </choice>
</flow>
```

#### 5. Agent Governance Dashboard Query

```sql
-- Agent activity summary: last 24 hours
SELECT
    agent_id,
    agent_name,
    agent_owner,
    COUNT(*) AS total_requests,
    COUNT(DISTINCT request_path) AS unique_endpoints,
    AVG(duration_ms) AS avg_duration_ms,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) AS error_count,
    SUM(CASE WHEN is_escalation THEN 1 ELSE 0 END) AS escalation_attempts,
    SUM(CASE WHEN is_high_frequency THEN 1 ELSE 0 END) AS rate_limit_events
FROM agent_audit_events
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY agent_id, agent_name, agent_owner
ORDER BY total_requests DESC;

-- Suspicious agent behavior detection
SELECT
    agent_id,
    agent_name,
    request_path,
    COUNT(*) AS hit_count,
    MIN(timestamp) AS first_seen,
    MAX(timestamp) AS last_seen
FROM agent_audit_events
WHERE timestamp > NOW() - INTERVAL '1 hour'
  AND (is_escalation = TRUE OR status_code = 403)
GROUP BY agent_id, agent_name, request_path
HAVING COUNT(*) > 5
ORDER BY hit_count DESC;
```

### How It Works
1. Every AI agent is registered with a unique identity (agentId), associated owner team, declared purpose, and explicit API scope grants
2. Agent traffic is identified by required headers (X-Agent-Id, X-Agent-Purpose, X-Agent-Model) and validated against the registration
3. OAuth2 client credentials provide the authentication mechanism — each agent gets its own client ID and secret with scoped permissions
4. The scope enforcement policy maps API endpoints to required scopes and denies access when an agent's token lacks the necessary scope
5. All agent API calls are logged to an audit trail with risk signal detection (escalation attempts, data exports, high-frequency patterns)
6. The governance dashboard provides real-time visibility into agent behavior, enabling operators to detect anomalies and revoke access

### Gotchas
- **Agent identity spoofing**: Relying solely on `X-Agent-Id` headers without OAuth2 validation allows any client to impersonate an agent. Always validate headers against the OAuth2 token claims. The header should match the `agent_id` claim in the access token.
- **Rate limiting per agent vs per user**: When an agent acts on behalf of a human user, you need two rate limit dimensions: per-agent (total capacity) and per-user-per-agent (preventing one user's agent from consuming all quota). Use composite rate limit keys: `agentId + userId`.
- **Scope creep**: Agents that start with narrow scopes tend to request broader access over time. Implement a governance review process: scope escalation requests require owner team approval and are logged as escalation events.
- **Multi-turn conversation tracking**: Without `X-Agent-Conversation-Id`, individual API calls lose context. A single agent task may involve 10-50 API calls. Require conversation IDs for proper audit trail reconstruction.
- **Agent credential rotation**: Agent client secrets should rotate on a 90-day cycle. Implement zero-downtime rotation by supporting two active secrets per agent during the rotation window.
- **Performance impact of audit logging**: Synchronous audit logging adds latency to every API call. Use asynchronous logging (VM queue or Anypoint MQ) for high-throughput endpoints. Accept the trade-off of delayed audit visibility (seconds, not minutes) for better API performance.
- **Nested agent calls**: Agent A may call Agent B, which calls your API. The audit trail shows Agent B as the caller, but the actual initiator is Agent A. Implement chain-of-custody headers (X-Agent-Origin-Chain) to track the full call chain.
- **Shadow AI agents**: Developers may build unofficial agents that bypass governance. Detect ungoverned agent traffic by monitoring for known AI client user-agent strings without the required X-Agent-Id header.

### Related
- [mcp-a2a-gateway](../../flex-gateway/mcp-a2a-gateway/) — Gateway for AI agent protocols
- [agent-governance](../../../ai-agents/ai-security/) — AI agent security patterns
- [custom-ruleset](../custom-ruleset/) — Custom API governance rulesets
- [llm-gateway-flex](../../../ai-agents/ai-gateway/llm-gateway-flex/) — LLM traffic governance
- [rate-limit-sliding-window](../../../performance/api-performance/rate-limit-sliding-window/) — Rate limiting implementation
- [sla-throttling](../../../performance/api-performance/sla-throttling/) — SLA-based throttling policies
