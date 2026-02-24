## MCP Servers by URL
> Register MCP servers with just a URL — simplified discovery and tool integration (GA January 2026).

### When to Use
- You want to register an MCP server in Anypoint Platform without complex setup
- You are migrating from manual MCP configuration to URL-based registration
- You need auto-discovery of tools and schemas from an MCP server manifest
- You want agents to dynamically discover and invoke MCP server capabilities

### Configuration / Code

**Before (complex setup — pre-GA):**

```json
{
  "mcpServers": {
    "salesforce-tools": {
      "type": "custom",
      "transport": "sse",
      "host": "mcp-salesforce.internal.company.com",
      "port": 3001,
      "path": "/mcp/v1",
      "protocol": "https",
      "authentication": {
        "type": "oauth2",
        "clientId": "sf-mcp-client",
        "clientSecret": "encrypted:abc123...",
        "tokenUrl": "https://login.salesforce.com/services/oauth2/token",
        "scopes": ["api", "refresh_token"]
      },
      "tools": [
        {
          "name": "query_accounts",
          "description": "Query Salesforce accounts",
          "inputSchema": {
            "type": "object",
            "properties": {
              "filter": {"type": "string"},
              "limit": {"type": "integer", "default": 10}
            }
          }
        },
        {
          "name": "create_case",
          "description": "Create a Salesforce case",
          "inputSchema": {
            "type": "object",
            "properties": {
              "subject": {"type": "string"},
              "description": {"type": "string"},
              "priority": {"type": "string", "enum": ["Low", "Medium", "High"]}
            },
            "required": ["subject"]
          }
        }
      ],
      "healthCheck": {
        "endpoint": "/health",
        "interval": 30
      }
    }
  }
}
```

**After (URL-based registration — GA January 2026):**

```json
{
  "mcpServers": {
    "salesforce-tools": {
      "url": "https://mcp-salesforce.internal.company.com/mcp/v1"
    }
  }
}
```

That is the entire registration. Tools, schemas, and capabilities are auto-discovered from the server manifest.

**MCP server manifest — what the server exposes at its URL:**

```json
{
  "name": "salesforce-mcp-server",
  "version": "2.1.0",
  "description": "MCP server for Salesforce CRM operations",
  "transport": "sse",
  "authentication": {
    "type": "oauth2",
    "authorizationUrl": "https://login.salesforce.com/services/oauth2/authorize",
    "tokenUrl": "https://login.salesforce.com/services/oauth2/token",
    "scopes": ["api"]
  },
  "tools": [
    {
      "name": "query_accounts",
      "description": "Query Salesforce Account records with optional filters",
      "inputSchema": {
        "type": "object",
        "properties": {
          "filter": {
            "type": "string",
            "description": "SOQL WHERE clause (e.g., 'Industry = \\'Technology\\'')"
          },
          "fields": {
            "type": "array",
            "items": {"type": "string"},
            "default": ["Id", "Name", "Industry", "Website"],
            "description": "Account fields to return"
          },
          "limit": {
            "type": "integer",
            "default": 10,
            "maximum": 200,
            "description": "Maximum records to return"
          }
        }
      },
      "outputSchema": {
        "type": "object",
        "properties": {
          "records": {
            "type": "array",
            "items": {"type": "object"}
          },
          "totalSize": {"type": "integer"}
        }
      }
    },
    {
      "name": "create_case",
      "description": "Create a new Salesforce Case",
      "inputSchema": {
        "type": "object",
        "properties": {
          "subject": {"type": "string", "maxLength": 255},
          "description": {"type": "string"},
          "priority": {
            "type": "string",
            "enum": ["Low", "Medium", "High", "Urgent"]
          },
          "accountId": {"type": "string", "pattern": "^001[A-Za-z0-9]{15}$"}
        },
        "required": ["subject"]
      }
    },
    {
      "name": "update_opportunity",
      "description": "Update an existing Salesforce Opportunity stage or amount",
      "inputSchema": {
        "type": "object",
        "properties": {
          "opportunityId": {"type": "string", "pattern": "^006[A-Za-z0-9]{15}$"},
          "stage": {
            "type": "string",
            "enum": ["Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won", "Closed Lost"]
          },
          "amount": {"type": "number", "minimum": 0}
        },
        "required": ["opportunityId"]
      }
    }
  ],
  "resources": [
    {
      "name": "account_schema",
      "uri": "salesforce://schema/Account",
      "description": "Salesforce Account object schema"
    }
  ]
}
```

**Registration API call — Anypoint Platform:**

```bash
# Register MCP server via Anypoint Platform API
curl -X POST "https://anypoint.mulesoft.com/mcp/api/v1/organizations/${ORG_ID}/servers" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "salesforce-tools",
    "url": "https://mcp-salesforce.internal.company.com/mcp/v1",
    "environment": "production",
    "tags": ["salesforce", "crm", "production"]
  }'

# Response:
# {
#   "id": "mcp-srv-abc123",
#   "name": "salesforce-tools",
#   "url": "https://mcp-salesforce.internal.company.com/mcp/v1",
#   "status": "DISCOVERING",
#   "discoveredTools": 0,
#   "registeredAt": "2026-01-15T10:30:00Z"
# }
```

**Check discovery status:**

```bash
# Poll until discovery completes
curl -X GET "https://anypoint.mulesoft.com/mcp/api/v1/organizations/${ORG_ID}/servers/mcp-srv-abc123" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"

# Response after discovery:
# {
#   "id": "mcp-srv-abc123",
#   "name": "salesforce-tools",
#   "url": "https://mcp-salesforce.internal.company.com/mcp/v1",
#   "status": "ACTIVE",
#   "discoveredTools": 3,
#   "discoveredResources": 1,
#   "lastDiscovery": "2026-01-15T10:30:05Z",
#   "manifest": {
#     "name": "salesforce-mcp-server",
#     "version": "2.1.0",
#     "toolCount": 3,
#     "resourceCount": 1
#   }
# }
```

**Mule flow — invoking a discovered MCP tool:**

```xml
<flow name="agent-invoke-mcp-tool-flow">
    <http:listener config-ref="HTTP_Listener" path="/agent/query-accounts"
                   method="POST" doc:name="Agent Request"/>

    <!-- Invoke discovered MCP tool by name -->
    <mcp:invoke-tool config-ref="MCP_Config" serverName="salesforce-tools"
                     toolName="query_accounts" doc:name="Query Accounts via MCP">
        <mcp:arguments>
            #[output application/json ---
            {
                filter: payload.filter default "",
                fields: payload.fields default ["Id", "Name", "Industry"],
                limit: payload.limit default 25
            }]
        </mcp:arguments>
    </mcp:invoke-tool>

    <ee:transform doc:name="Format Agent Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    toolUsed: "query_accounts",
    server: "salesforce-tools",
    result: payload,
    metadata: {
        recordCount: sizeOf(payload.records default []),
        executedAt: now()
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <error-handler>
        <on-error-continue type="MCP:TOOL_NOT_FOUND" doc:name="Tool Not Found">
            <ee:transform doc:name="404 Tool Error">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{error: {code: "TOOL_NOT_FOUND", message: "MCP tool not available"}}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 404}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-continue type="MCP:SERVER_UNAVAILABLE" doc:name="Server Down">
            <ee:transform doc:name="503 Server Error">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{error: {code: "MCP_SERVER_UNAVAILABLE", message: "MCP server is unreachable"}}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 503}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>
    </error-handler>
</flow>
```

### How It Works
1. You register an MCP server by providing only its URL to the Anypoint Platform (via UI or API)
2. The platform connects to the URL and fetches the server's manifest, which declares available tools, input/output schemas, and resources
3. Tool discovery is automatic — the platform reads the manifest and indexes all tools with their schemas
4. Agents and flows can invoke discovered tools by `serverName` + `toolName`, with input validated against the auto-detected schema
5. Schema versioning is handled by the manifest's `version` field — the platform tracks changes on re-discovery
6. Health checks and re-discovery run periodically to detect new tools or schema changes

### Gotchas
- **URL must be publicly reachable or VPN-accessible**: The Anypoint Platform control plane must be able to reach the MCP server URL to discover tools. For internal servers, ensure the URL is accessible from the platform's network (VPN, VPC peering, or Anypoint VPN)
- **Schema versioning**: When the MCP server updates its tool schemas, agents using old schemas may send invalid input. Implement backward-compatible schema changes or version your tool names (e.g., `query_accounts_v2`)
- **Discovery latency**: Initial discovery can take 5-30 seconds depending on manifest size. Do not assume tools are available immediately after registration
- **Authentication handshake**: The URL-based registration still requires the MCP server to handle authentication. The simplified registration does not eliminate auth — it auto-discovers the auth method from the manifest
- **Manifest format compliance**: The server must expose a standards-compliant MCP manifest at its root URL. Non-compliant manifests cause discovery to fail silently
- **Rate limits on discovery**: If you register many MCP servers simultaneously, the platform may rate-limit discovery requests. Stagger registrations for large deployments

### Related
- [Agent Scanners Multi-Cloud](../agent-scanners-multi-cloud/)
- [MCP Server Basics](../mcp-server-basics/)
- [MCP Advanced Patterns](../mcp-advanced/)
