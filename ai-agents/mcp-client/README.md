# MCP Client

> Call remote MCP servers from your Mule flows — access external AI tools and services.

## What It Does

The MCP Connector's client mode lets Mule applications **consume** tools exposed by remote MCP servers. Your Mule flow becomes an AI agent that can discover and invoke tools on any MCP-compatible server.

## Prerequisites

- Mule Runtime 4.9.6+
- MCP Connector v1.3+
- URL of a remote MCP server

## Configuration

```xml
<mcp:client-config name="Remote_MCP_Client"
    clientName="Mule MCP Client" clientVersion="1.0.0">
    <mcp:streamable-http-client-connection
        serverUrl="https://remote-mcp-server.example.com"
        mcpEndpointPath="/mcp" />
</mcp:client-config>
```

## Client Operations

| Operation | Description |
|-----------|-------------|
| `list-tools` | Discover what tools the remote server offers |
| `call-tool` | Invoke a specific tool with parameters |
| `list-resources` | Discover available resources |
| `read-resource` | Read a resource by URI |
| `ping` | Check server connectivity |

## Example: Calling a Remote MCP Server

### 1. Discover Available Tools

```xml
<flow name="discoverToolsFlow">
    <http:listener config-ref="HTTP_Listener" path="/discover" />
    <mcp:list-tools config-ref="Remote_MCP_Client" />
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload.tools map {
    name: $.name,
    description: $.description
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### 2. Call a Tool

```xml
<flow name="callGeocodeFlow">
    <http:listener config-ref="HTTP_Listener" path="/geocode" />
    <mcp:call-tool config-ref="Remote_MCP_Client" toolName="geocode">
        <mcp:arguments><![CDATA[#[{
            "address": attributes.queryParams.address
        }]]]></mcp:arguments>
    </mcp:call-tool>
</flow>
```

### 3. With Authentication Headers

```xml
<mcp:client-config name="Authenticated_MCP_Client"
    clientName="Mule Secure Client" clientVersion="1.0.0">
    <mcp:streamable-http-client-connection
        serverUrl="https://secure-mcp.example.com"
        mcpEndpointPath="/mcp">
        <mcp:default-request-headers>
            <mcp:default-request-header key="Authorization"
                value="Bearer ${secure::mcp.api.key}" />
        </mcp:default-request-headers>
    </mcp:streamable-http-client-connection>
</mcp:client-config>
```

## Common Gotchas

- **Streamable HTTP is the recommended transport** — SSE Client is deprecated
- **Tool names are case-sensitive** — match exactly what `list-tools` returns
- **Arguments must be valid JSON** matching the tool's schema
- **Connection timeouts** default may be too low for AI tools — increase if calling LLMs

## Next Steps

- [MCP Server Basics](../mcp-server-basics/) — Expose your own tools
- [A2A Protocol](../a2a-protocol/) — Agent-to-agent communication (different from tool access)

## References

- [MCP Connector Client Operations](https://docs.mulesoft.com/mcp-connector/latest/mcp-connector-reference)
- [MCP Connector Examples](https://docs.mulesoft.com/mcp-connector/latest/mcp-connector-examples)
