## Agent Scanners Multi-Cloud
> Auto-discover agents across Agentforce, Bedrock, Vertex AI, and Copilot Studio with a unified registry.

### When to Use
- Your enterprise has AI agents deployed across multiple cloud providers
- You need a single view of all agents, their capabilities, and health status
- You want to map agent capabilities into a common schema for orchestration
- You need to monitor agent availability and detect configuration drift

### Configuration / Code

**Scanner configuration per cloud provider — `agent-scanner-config.yaml`:**

```yaml
scanner:
  name: "enterprise-agent-scanner"
  scan_interval_minutes: 60
  max_concurrent_scans: 3

  providers:
    agentforce:
      enabled: true
      auth:
        type: "oauth2_jwt"
        issuer: "${secure::sf.connected_app.client_id}"
        subject: "${secure::sf.admin.username}"
        audience: "https://login.salesforce.com"
        private_key_path: "${secure::sf.jwt.key_path}"
      discovery:
        api_version: "v62.0"
        base_url: "https://${sf.instance}.my.salesforce.com"
        endpoints:
          list_agents: "/services/data/${api_version}/agent"
          agent_detail: "/services/data/${api_version}/agent/{agentId}"
          agent_actions: "/services/data/${api_version}/agent/{agentId}/actions"
      capabilities_mapping:
        "KnowledgeRetrieval": "knowledge_search"
        "FlowInvocation": "workflow_execution"
        "ApexAction": "code_execution"
        "ExternalService": "api_integration"

    bedrock:
      enabled: true
      auth:
        type: "aws_iam"
        region: "${aws.region}"
        access_key_id: "${secure::aws.access_key}"
        secret_access_key: "${secure::aws.secret_key}"
        role_arn: "${aws.scanner_role_arn}"
      discovery:
        endpoints:
          list_agents: "bedrock-agent:ListAgents"
          agent_detail: "bedrock-agent:GetAgent"
          agent_knowledge: "bedrock-agent:ListKnowledgeBases"
          agent_actions: "bedrock-agent:ListAgentActionGroups"
      capabilities_mapping:
        "KNOWLEDGE_BASE": "knowledge_search"
        "ACTION_GROUP": "api_integration"
        "LAMBDA": "code_execution"
        "RETURN_CONTROL": "human_handoff"

    vertex_ai:
      enabled: true
      auth:
        type: "gcp_service_account"
        project_id: "${gcp.project_id}"
        credentials_path: "${secure::gcp.credentials_path}"
      discovery:
        location: "${gcp.region}"
        endpoints:
          list_agents: "dialogflow.googleapis.com/v3/projects/{project}/locations/{location}/agents"
          agent_detail: "dialogflow.googleapis.com/v3/projects/{project}/locations/{location}/agents/{agentId}"
          agent_flows: "dialogflow.googleapis.com/v3/projects/{project}/locations/{location}/agents/{agentId}/flows"
      capabilities_mapping:
        "FLOW": "workflow_execution"
        "WEBHOOK": "api_integration"
        "KNOWLEDGE_CONNECTOR": "knowledge_search"
        "GENERATIVE_AGENT": "generative_response"

    copilot_studio:
      enabled: true
      auth:
        type: "azure_ad"
        tenant_id: "${azure.tenant_id}"
        client_id: "${secure::azure.client_id}"
        client_secret: "${secure::azure.client_secret}"
        scope: "https://api.powerplatform.com/.default"
      discovery:
        environment_id: "${azure.power_platform.env_id}"
        endpoints:
          list_agents: "https://api.powerplatform.com/appmanagement/environments/{envId}/customcopilots"
          agent_detail: "https://api.powerplatform.com/appmanagement/environments/{envId}/customcopilots/{agentId}"
      capabilities_mapping:
        "Topic": "conversation_flow"
        "Action": "api_integration"
        "KnowledgeSource": "knowledge_search"
        "Plugin": "code_execution"
```

**Unified agent registry schema:**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Unified Agent Registry Entry",
  "type": "object",
  "required": ["id", "name", "provider", "status", "capabilities", "discoveredAt"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Globally unique agent ID: {provider}:{native_id}"
    },
    "name": {
      "type": "string",
      "description": "Human-readable agent name"
    },
    "description": {
      "type": "string"
    },
    "provider": {
      "type": "string",
      "enum": ["agentforce", "bedrock", "vertex_ai", "copilot_studio"]
    },
    "nativeId": {
      "type": "string",
      "description": "Provider-specific agent identifier"
    },
    "status": {
      "type": "string",
      "enum": ["active", "inactive", "error", "discovering"]
    },
    "version": {
      "type": "string"
    },
    "capabilities": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "name"],
        "properties": {
          "type": {
            "type": "string",
            "enum": [
              "knowledge_search",
              "workflow_execution",
              "code_execution",
              "api_integration",
              "generative_response",
              "human_handoff",
              "conversation_flow"
            ]
          },
          "name": {
            "type": "string"
          },
          "description": {
            "type": "string"
          },
          "nativeType": {
            "type": "string",
            "description": "Provider-specific capability type"
          },
          "config": {
            "type": "object",
            "description": "Provider-specific configuration details"
          }
        }
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "region": {"type": "string"},
        "environment": {"type": "string"},
        "owner": {"type": "string"},
        "tags": {
          "type": "array",
          "items": {"type": "string"}
        },
        "lastModified": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "discoveredAt": {
      "type": "string",
      "format": "date-time"
    },
    "lastScanAt": {
      "type": "string",
      "format": "date-time"
    },
    "health": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["healthy", "degraded", "unhealthy", "unknown"]
        },
        "lastCheck": {
          "type": "string",
          "format": "date-time"
        },
        "responseTimeMs": {"type": "integer"},
        "errorRate": {"type": "number"}
      }
    }
  }
}
```

**Mule flow — multi-cloud scanner orchestration:**

```xml
<flow name="agent-scanner-orchestration-flow">
    <scheduler doc:name="Hourly Scan">
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="MINUTES"/>
        </scheduling-strategy>
    </scheduler>

    <logger level="INFO" doc:name="Log Scan Start"
            message='#["Agent scan started. correlationId=" ++ correlationId]'/>

    <scatter-gather doc:name="Scan All Providers" timeout="120000"
                    maxConcurrency="4">
        <route>
            <flow-ref name="scan-agentforce-subflow" doc:name="Scan Agentforce"/>
        </route>
        <route>
            <flow-ref name="scan-bedrock-subflow" doc:name="Scan Bedrock"/>
        </route>
        <route>
            <flow-ref name="scan-vertex-ai-subflow" doc:name="Scan Vertex AI"/>
        </route>
        <route>
            <flow-ref name="scan-copilot-studio-subflow" doc:name="Scan Copilot Studio"/>
        </route>
    </scatter-gather>

    <!-- Merge results from all providers -->
    <ee:transform doc:name="Merge Agent Registry">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var allAgents = flatten(payload..payload default [])
---
{
    scanId: uuid(),
    scannedAt: now(),
    summary: {
        totalAgents: sizeOf(allAgents),
        byProvider: allAgents groupBy $.provider
            mapObject ((agents, provider) ->
                (provider): sizeOf(agents)
            ),
        byStatus: allAgents groupBy $.status
            mapObject ((agents, status) ->
                (status): sizeOf(agents)
            ),
        byCapability: flatten(allAgents.capabilities)
            groupBy $.type
            mapObject ((caps, capType) ->
                (capType): sizeOf(caps distinctBy $.name)
            )
    },
    agents: allAgents orderBy $.name
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Store in registry -->
    <db:bulk-insert config-ref="Registry_DB" doc:name="Upsert Agent Registry">
        <db:sql>
            INSERT INTO agent_registry (id, name, provider, status, capabilities, metadata, discovered_at, last_scan_at)
            VALUES (:id, :name, :provider, :status, :capabilities, :metadata, :discoveredAt, :lastScanAt)
            ON CONFLICT (id) DO UPDATE SET
                status = EXCLUDED.status,
                capabilities = EXCLUDED.capabilities,
                metadata = EXCLUDED.metadata,
                last_scan_at = EXCLUDED.last_scan_at
        </db:sql>
        <db:input-parameters>#[
            payload.agents map {
                id: $.id,
                name: $.name,
                provider: $.provider,
                status: $.status,
                capabilities: write($.capabilities, "application/json"),
                metadata: write($.metadata default {}, "application/json"),
                discoveredAt: $.discoveredAt,
                lastScanAt: now()
            }
        ]</db:input-parameters>
    </db:bulk-insert>

    <logger level="INFO" doc:name="Log Scan Complete"
            message='#["Scan complete: " ++ sizeOf(payload.agents) ++ " agents found. correlationId=" ++ correlationId]'/>

    <error-handler>
        <on-error-continue type="MULE:COMPOSITE_ROUTING" doc:name="Partial Scan Failure">
            <logger level="WARN" doc:name="Log Partial Failure"
                    message='#["Some providers failed to scan. Processing available results. correlationId=" ++ correlationId]'/>
            <!-- Process successful routes only -->
            <ee:transform doc:name="Extract Successful Scans">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    scanId: uuid(),
    scannedAt: now(),
    partial: true,
    agents: flatten(
        (error.childErrors filter $.failed == false)
            map $.payload.payload default []
    )
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-continue>
    </error-handler>
</flow>

<!-- Provider-specific scanner sub-flow example: Agentforce -->
<sub-flow name="scan-agentforce-subflow">
    <http:request config-ref="Salesforce_Config" method="GET"
                  path="/services/data/v62.0/agent"
                  doc:name="List Agentforce Agents"
                  responseTimeout="30000"/>

    <ee:transform doc:name="Normalize Agentforce Agents">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var capabilityMap = {
    "KnowledgeRetrieval": "knowledge_search",
    "FlowInvocation": "workflow_execution",
    "ApexAction": "code_execution",
    "ExternalService": "api_integration"
}
---
payload.agents map (agent) -> {
    id: "agentforce:" ++ agent.id,
    name: agent.name default "Unnamed Agent",
    description: agent.description default "",
    provider: "agentforce",
    nativeId: agent.id,
    status: if (agent.isActive default false) "active" else "inactive",
    version: agent.version default "1.0",
    capabilities: (agent.actions default []) map (action) -> {
        "type": capabilityMap[action.type] default "api_integration",
        name: action.name,
        description: action.description default "",
        nativeType: action.type
    },
    metadata: {
        region: "salesforce",
        environment: p('sf.environment'),
        owner: agent.createdBy default "unknown",
        tags: agent.labels default [],
        lastModified: agent.lastModifiedDate
    },
    discoveredAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>
```

**Dashboard query — single pane of glass:**

```sql
-- Summary view: agents by provider and status
SELECT
    provider,
    status,
    COUNT(*) as agent_count,
    COUNT(DISTINCT jsonb_array_elements_text(capabilities->'type')) as capability_types
FROM agent_registry
WHERE last_scan_at > NOW() - INTERVAL '2 hours'
GROUP BY provider, status
ORDER BY provider, status;

-- Capability gap analysis: which providers have which capabilities
SELECT
    cap.type as capability,
    STRING_AGG(DISTINCT ar.provider, ', ') as available_on,
    COUNT(DISTINCT ar.id) as agent_count
FROM agent_registry ar,
     jsonb_to_recordset(ar.capabilities) as cap(type text, name text)
WHERE ar.status = 'active'
GROUP BY cap.type
ORDER BY agent_count DESC;

-- Stale agents: not seen in last 2 scans
SELECT id, name, provider, last_scan_at
FROM agent_registry
WHERE last_scan_at < NOW() - INTERVAL '3 hours'
  AND status = 'active'
ORDER BY last_scan_at ASC;
```

### How It Works
1. A scheduled Mule flow triggers hourly, initiating parallel scans across all configured cloud providers
2. Each provider scanner authenticates using provider-specific credentials (OAuth2, IAM, Service Account, Azure AD)
3. Scanners call discovery APIs to list all agents and their capabilities per provider
4. Provider-specific capability types are mapped to a unified schema using the `capabilities_mapping` configuration
5. Results from all providers are merged, deduplicated, and upserted into a central agent registry database
6. If a provider scan fails, the scatter-gather error handler processes successful results from other providers
7. Dashboard queries against the registry provide a unified view of all enterprise agents

### Gotchas
- **Different auth per cloud**: Each cloud provider has a distinct authentication mechanism. Store all credentials in secure properties and rotate them on provider-specific schedules. A single expired credential blocks one provider's scan without affecting others
- **Agent capability schema mismatch**: Provider-native capability types do not map 1:1 to the unified schema. The `capabilities_mapping` is a best-effort normalization. Review and update mappings when providers add new capability types
- **Scan frequency vs API limits**: Salesforce has API call limits per 24-hour period. AWS Bedrock and GCP have per-second rate limits. Set scan intervals to stay within limits — for large agent counts, use pagination and backoff
- **Stale agent detection**: If an agent is deleted from a provider, the scanner will not discover it. Implement a staleness check: agents not seen in 3+ consecutive scans should be marked `inactive`
- **Provider API versioning**: Each cloud provider evolves its agent management APIs. Pin API versions in config and test before upgrading (e.g., Salesforce API version v62.0)
- **Network partitioning**: If the scanner runs in one cloud (e.g., AWS), scanning agents in another cloud (e.g., GCP) requires cross-cloud network connectivity. Use VPN or dedicated interconnects

### Related
- [MCP Servers by URL](../mcp-servers-by-url/)
- [Multi-Cloud AI Gateway](../multi-cloud/) (if available)
- [AI Security Patterns](../ai-security/)
- [Agent Fabric](../agent-fabric/)
