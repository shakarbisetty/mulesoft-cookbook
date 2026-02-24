## MCP Server with OAuth 2.0 Security
> Secure your MCP server endpoints with OAuth 2.0 token validation.

### When to Use
- Exposing MCP tools to external AI agents that need authentication
- Enterprise environments requiring token-based access control
- Multi-tenant MCP servers serving different organizations

### Configuration / Code

```xml
<flow name="mcp-secured-endpoint">
    <http:listener config-ref="HTTP_Listener" path="/mcp/tools/*"/>
    <!-- Validate OAuth token -->
    <http:request config-ref="OAuth_Validation" path="/oauth2/introspect" method="POST">
        <http:body>#[output application/x-www-form-urlencoded --- {token: attributes.headers.Authorization replace "Bearer " with ""}]</http:body>
    </http:request>
    <choice>
        <when expression="#[payload.active == true]">
            <set-variable variableName="clientId" value="#[payload.client_id]"/>
            <flow-ref name="mcp-tool-router"/>
        </when>
        <otherwise>
            <set-payload value=Unauthorized mimeType="application/json"/>
            <http:response statusCode="401"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. MCP client includes an OAuth 2.0 bearer token in requests
2. Server validates the token via introspection endpoint
3. Valid tokens proceed to tool execution with client context
4. Invalid/expired tokens return 401

### Gotchas
- Token validation adds latency per MCP call — cache validation results
- MCP protocol does not natively define auth — this is an extension
- Scope-based tool access requires mapping OAuth scopes to MCP tool names
- Refresh token handling is the MCP client responsibility

### Related
- [MCP Server Basics](../mcp-server-basics/) — basic MCP server setup
- [Load Balanced Server](../load-balanced-server/) — scaling MCP servers
