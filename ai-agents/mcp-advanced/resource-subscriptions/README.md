## MCP Resource Subscriptions
> Enable real-time resource updates via MCP subscription mechanism.

### When to Use
- AI agents that need live data updates (stock prices, order status)
- Reducing polling overhead for frequently changing resources
- Event-driven AI workflows triggered by data changes

### Configuration / Code

```xml
<flow name="mcp-subscription-handler">
    <http:listener config-ref="HTTP_Listener" path="/mcp/subscribe" method="POST"/>
    <set-variable variableName="resourceUri" value="#[payload.params.uri]"/>
    <!-- Register subscription in Object Store -->
    <os:store key="#[payload.params.uri ++ - ++ correlationId]" objectStore="subscriptions-store">
        <os:value>#[output application/json --- {uri: vars.resourceUri, clientId: correlationId, created: now()}]</os:value>
    </os:store>
    <set-payload value={subscribed:
