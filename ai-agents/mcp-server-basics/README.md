# MCP Server Basics

> Turn any Mule application into an MCP server that AI agents can discover and invoke.

## What is MCP?

The [Model Context Protocol](https://modelcontextprotocol.io/) lets AI agents discover and call tools exposed by servers. The MuleSoft MCP Connector (v1.3 GA) enables Mule apps to act as MCP servers — exposing your existing integrations as tools that any MCP-compatible AI agent can use.

## Prerequisites

- Mule Runtime **4.9.6+**
- Java 17
- MCP Connector from Exchange: `com.mulesoft.connectors:mule-mcp-connector:1.3.0`

## Step 1: Add the MCP Connector Dependency

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-mcp-connector</artifactId>
    <version>1.3.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Step 2: Configure the MCP Server

Three transport options are available. **Streamable HTTP** is recommended for new projects.

```xml
<!-- HTTP Listener -->
<http:listener-config name="http-listener-config">
    <http:listener-connection host="0.0.0.0" port="8081" />
</http:listener-config>

<!-- MCP Server Config (Streamable HTTP) -->
<mcp:server-config name="mcp-server-config"
    serverName="My MCP Server" serverVersion="1.0.0">
    <mcp:streamable-http-server-connection
        listenerConfig="http-listener-config" />
</mcp:server-config>
```

### Transport Comparison

| Transport | Direction | Use When |
|-----------|-----------|----------|
| **Streamable HTTP** | Server + Client | New projects, cloud deployment, load balancers |
| **SSE Server** | Server only | Legacy integrations needing persistent connections |
| **SSE Client** | Client only | **Deprecated** — use Streamable HTTP instead |

## Step 3: Expose a Tool

Each tool is a Mule flow triggered by `mcp:tool-listener`. The JSON schema defines what parameters the tool accepts.

```xml
<flow name="getWeatherFlow">
    <mcp:tool-listener config-ref="mcp-server-config" name="get-weather">
        <mcp:description>Get current weather for a city</mcp:description>
        <mcp:parameters-schema><![CDATA[{
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "City name (e.g., San Francisco)"
                }
            },
            "required": ["city"]
        }]]></mcp:parameters-schema>
        <mcp:responses>
            <mcp:text-tool-response-content text="#[payload.^raw]" />
        </mcp:responses>
    </mcp:tool-listener>

    <!-- Your integration logic here -->
    <http:request method="GET"
        url="https://api.open-meteo.com/v1/forecast"
        config-ref="HTTP_Request_config">
        <http:query-params>#[{
            'latitude': vars.lat,
            'longitude': vars.lon,
            'current_weather': 'true'
        }]</http:query-params>
    </http:request>
</flow>
```

## Step 4: Add Authentication (Production)

Use the `on-new-session-listener` to validate tokens on incoming MCP connections:

```xml
<flow name="onNewSession">
    <mcp:on-new-session-listener config-ref="mcp-server-config" />
    <mcp:rejection rejectWithStatusCode="#[vars.rejectStatusCode]"
                   rejectWithMessage="#[vars.rejectMessage]" />
    <!-- Validate OAuth token -->
    <oauth2-provider:validate-token
        config-ref="external-oauth2-provider"
        accessToken="#[payload.additionalProperties.authorization]"
        scopes="#[['read']]" />
</flow>
```

### Supported Authentication Methods

1. Basic Authentication
2. OAuth Authorization Code
3. OAuth Client Credentials (recommended for machine-to-machine)
4. Digest
5. NTLM

## Common Gotchas

- **JSON schema is always required** — even tools with no parameters need an empty schema
- **Tool descriptions drive AI selection** — write them clearly so the LLM knows when to use your tool
- **SSE Client is deprecated** — always use Streamable HTTP for new projects
- **Session idle timeout** defaults to 5 minutes for Streamable HTTP Server
- **Port mismatches with Docker/Flex Gateway** kill connections silently — ensure exposed ports match listener config

## Real-World Example: Vendor Management

```xml
<flow name="getVendorsFlow">
    <mcp:tool-listener config-ref="mcp-server-config" name="get-vendors">
        <mcp:description>Get approved vendors with pagination</mcp:description>
        <mcp:parameters-schema><![CDATA[{
            "type": "object",
            "properties": {
                "pageSize": {"type": "integer", "minimum": 1, "maximum": 100, "default": 50},
                "pageNumber": {"type": "integer", "minimum": 1, "default": 1}
            }
        }]]></mcp:parameters-schema>
        <mcp:responses>
            <mcp:text-tool-response-content text="#[payload.^raw]" />
        </mcp:responses>
    </mcp:tool-listener>

    <!-- Cache expensive backend calls -->
    <ee:cache cachingStrategy-ref="vendorCache">
        <http:request method="GET" url="${sap.concur.vendors.url}"
            config-ref="SAP_Concur_Config" />
    </ee:cache>

    <!-- Transform with DataWeave -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var page = attributes.queryParams.pageNumber default 1
var size = attributes.queryParams.pageSize default 50
---
{
    vendors: payload[((page - 1) * size) to (page * size - 1)],
    total: sizeOf(payload),
    page: page,
    pageSize: size
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

## Next Steps

- [MCP Client](../mcp-client/) — Call remote MCP servers from Mule flows
- [MCP IDE Setup](../mcp-ide-setup/) — Connect your IDE to Anypoint Platform
- [Agent Fabric](../agent-fabric/) — Register and govern your MCP server

## References

- [MCP Connector Documentation](https://docs.mulesoft.com/mcp-connector/latest/)
- [MCP Connector Examples](https://docs.mulesoft.com/mcp-connector/latest/mcp-connector-examples)
- [MCP Connector Reference](https://docs.mulesoft.com/mcp-connector/latest/mcp-connector-reference)
- [Model Context Protocol Spec](https://modelcontextprotocol.io/)
