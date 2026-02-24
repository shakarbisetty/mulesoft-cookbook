## A2A Protocol Versioning
> Manage protocol version compatibility between A2A agents.

### When to Use
- Upgrading A2A protocol versions across agent fleet
- Maintaining backward compatibility during migrations
- Multi-version agent environments

### Configuration / Code

```xml
<flow name="a2a-versioned-handler">
    <http:listener config-ref="HTTP_Listener" path="/a2a/*"/>
    <set-variable variableName="protocolVersion"
                  value="#[payload.jsonrpc default '2.0']"/>
    <choice>
        <when expression="#[vars.protocolVersion == '2.0']">
            <flow-ref name="a2a-v2-handler"/>
        </when>
        <otherwise>
            <set-payload value='#[output application/json --- {
                jsonrpc: "2.0",
                error: {code: -32600, message: "Unsupported protocol version"}
            }]'/>
            <set-variable variableName="httpStatus" value="400"/>
        </otherwise>
    </choice>
</flow>

<!-- Version 2.0 handler with full A2A spec compliance -->
<sub-flow name="a2a-v2-handler">
    <choice>
        <when expression="#[payload.method == 'tasks/send']">
            <flow-ref name="handle-task-send"/>
        </when>
        <when expression="#[payload.method == 'tasks/get']">
            <flow-ref name="handle-task-get"/>
        </when>
        <when expression="#[payload.method == 'tasks/cancel']">
            <flow-ref name="handle-task-cancel"/>
        </when>
        <otherwise>
            <set-payload value='#[output application/json --- {
                jsonrpc: "2.0",
                id: payload.id,
                error: {code: -32601, message: "Method not found"}
            }]'/>
        </otherwise>
    </choice>
</sub-flow>
```

**Agent Card advertising supported versions:**
```json
{
  "name": "order-agent",
  "url": "https://orders.example.com/a2a",
  "version": "2.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": true
  },
  "skills": [
    {"id": "order-lookup", "name": "Order Lookup"}
  ]
}
```

### How It Works
1. The HTTP listener receives all A2A JSON-RPC requests on `/a2a/*`
2. The protocol version is extracted from `jsonrpc` field (defaults to 2.0)
3. A Choice router directs to the version-specific handler sub-flow
4. Unsupported versions receive a `-32600` (Invalid Request) JSON-RPC error
5. The v2 handler routes by method name (`tasks/send`, `tasks/get`, `tasks/cancel`)
6. Unknown methods return `-32601` (Method Not Found) per JSON-RPC spec
7. Agent Card declares supported version and capabilities for client discovery

### Gotchas
- Always include `jsonrpc: "2.0"` in every response — clients validate this field
- Agent Cards must be updated when adding new capabilities or version support
- JSON-RPC error codes are standardized: use -32600 to -32699 for server-defined errors
- During migration, run v1 and v2 handlers in parallel until all clients upgrade
- Test version negotiation with real agent clients, not just HTTP tools

### Related
- [A2A Multi-Agent Orchestration](../multi-agent-orchestration/) — coordinating versioned agents
- [A2A Error Recovery](../error-recovery/) — handling version mismatch failures
- [MCP Streaming Responses](../../mcp-advanced/streaming-responses/) — similar versioning for MCP
