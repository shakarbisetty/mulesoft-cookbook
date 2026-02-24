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
                  value="#[payload.jsonrpc default 2.0]"/>
    <choice>
        <when expression="#[vars.protocolVersion == 2.0]">
            <flow-ref name="a2a-v2-handler"/>
        </when>
        <otherwise>
            <set-payload value="#[output application/json --- {
                jsonrpc: 2.0,
                error: {code: -32600, message: Unsupported
