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
    <os:store key="#[payload.params.uri ++ ':' ++ correlationId]" objectStore="subscriptions-store">
        <os:value>#[output application/json --- {
            uri: vars.resourceUri,
            clientId: correlationId,
            created: now()
        }]</os:value>
    </os:store>
    <set-payload value='#[output application/json --- {
        jsonrpc: "2.0",
        id: payload.id,
        result: {subscribed: true, uri: vars.resourceUri}
    }]'/>
</flow>

<!-- Background flow: detect changes and notify subscribers -->
<flow name="mcp-resource-monitor">
    <scheduler>
        <scheduling-strategy><fixed-frequency frequency="5000"/></scheduling-strategy>
    </scheduler>
    <os:retrieve-all objectStore="subscriptions-store"/>
    <foreach>
        <set-variable variableName="subscription" value="#[payload.value]"/>
        <flow-ref name="check-resource-changed"/>
        <choice>
            <when expression="#[vars.resourceChanged == true]">
                <http:request config-ref="HTTP_Requester" method="POST"
                              url="#['http://localhost:8081/mcp/notify']">
                    <http:body>#[output application/json --- {
                        jsonrpc: "2.0",
                        method: "notifications/resources/updated",
                        params: {uri: vars.subscription.uri}
                    }]</http:body>
                </http:request>
            </when>
        </choice>
    </foreach>
</flow>
```

### How It Works
1. Client sends `subscribe` request with the resource URI it wants to watch
2. Subscription is stored in Object Store keyed by `uri:clientId`
3. A scheduler polls every 5 seconds, checking all subscribed resources for changes
4. When a change is detected, `notifications/resources/updated` is sent to the client
5. The notification uses standard MCP notification format (no `id` field, just `method` + `params`)
6. Client responds by re-fetching the resource via `resources/read` to get updated data
7. Unsubscribe removes the Object Store entry

### Gotchas
- Poll frequency is a trade-off: 5s for near-real-time, 60s for low overhead
- For true real-time, replace polling with VM queues or Anypoint MQ events
- Object Store has a default max of 10,000 entries — monitor subscription count
- Clean up stale subscriptions (clients that disconnect without unsubscribing)
- Notification delivery is best-effort — clients must handle missed notifications

### Related
- [MCP Streaming Responses](../streaming-responses/) — streaming as alternative to subscriptions
- [Tool Discovery via Exchange](../tool-discovery-exchange/) — discovering subscribable resources
- [MCP OAuth Security](../oauth-security/) — securing subscription endpoints
