## MCP Tool Discovery via Anypoint Exchange
> Publish MCP tool definitions to Exchange for automated discovery by AI agents.

### When to Use
- Organization-wide tool registry for AI agents
- Self-service tool discovery without manual configuration
- Versioned tool definitions with documentation

### Configuration / Code

**Tool definition (Exchange asset):**
```json
{
  "tools": [
    {
      "name": "get-order-status",
      "description": "Retrieve the current status of a customer order",
      "inputSchema": {
        "type": "object",
        "properties": {
          "orderId": {"type": "string", "description": "The order ID"}
        },
        "required": ["orderId"]
      },
      "serverUrl": "https://mcp.example.com/tools/get-order-status"
    }
  ]
}
```

**Discovery endpoint in Mule:**
```xml
<flow name="mcp-tool-discovery">
    <http:listener config-ref="HTTP_Listener" path="/mcp/tools/list" method="GET"/>
    <http:request config-ref="Exchange_API" path="/v2/assets" method="GET">
        <http:query-params>#[{type: "mcp-tool", organizationId: vars.orgId}]</http:query-params>
    </http:request>
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{tools: payload map {name: $.name, description: $.description, inputSchema: $.schema}}
]]></ee:set-payload></ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. MCP tool definitions are published to Exchange as custom assets
2. Discovery endpoint queries Exchange for all MCP tool assets
3. AI agents call the discovery endpoint to learn available tools
4. Tool metadata includes input schema, description, and server URL

### Gotchas
- Exchange API requires authentication — use connected app credentials
- Tool versioning must align with the MCP server version
- Schema changes need backward compatibility or version bumps
- Cache the tool list — Exchange API has rate limits

### Related
- [MCP Server Basics](../mcp-server-basics/) — implementing MCP tools
- [OAuth Security](../oauth-security/) — securing tool access
