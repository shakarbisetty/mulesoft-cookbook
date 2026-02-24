## Mule Actions for Agentforce
> Expose MuleSoft API operations as Agentforce agent actions.

### When to Use
- Connecting Agentforce to backend systems via MuleSoft
- Making existing MuleSoft APIs available to AI agents
- CRUD operations on Salesforce and external systems

### Configuration / Code

```xml
<!-- MuleSoft flow exposed as Agentforce action -->
<flow name="get-order-status-action">
    <http:listener config-ref="HTTP_Listener" path="/actions/get-order-status" method="POST"/>
    <set-variable variableName="orderId" value="#[payload.inputs.orderId]"/>
    <db:select config-ref="Database_Config">
        <db:sql>SELECT order_id, status, estimated_delivery FROM orders WHERE order_id = :orderId</db:sql>
        <db:input-parameters>#[{orderId: vars.orderId}]</db:input-parameters>
    </db:select>
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    outputs: {
        orderId: payload[0].order_id,
        status: payload[0].status,
        estimatedDelivery: payload[0].estimated_delivery
    }
}]]></ee:set-payload></ee:message>
    </ee:transform>
</flow>
```

**Action definition:**
```json
{
  "name": "get-order-status",
  "description": "Retrieve the current status and estimated delivery date for a customer order",
  "inputs": [
    {"name": "orderId", "type": "string", "description": "The unique order identifier", "required": true}
  ],
  "outputs": [
    {"name": "orderId", "type": "string"},
    {"name": "status", "type": "string"},
    {"name": "estimatedDelivery", "type": "string"}
  ]
}
```

### How It Works
1. Mule flow implements the action logic (database query, API call, etc.)
2. Action definition describes inputs and outputs for the agent
3. Agentforce calls the Mule endpoint when the action is triggered
4. Response is formatted as `{outputs: {...}}` for the agent to interpret

### Gotchas
- Action input/output descriptions help the agent decide when to use the action
- Keep actions atomic — one action per business operation
- Error responses should be human-readable for the agent to relay to users
- Action timeouts in Agentforce default to 30 seconds — optimize slow queries

### Related
- [Topic Creation](../topic-creation/) — organizing actions
- [Agent Testing](../agent-testing/) — testing actions
