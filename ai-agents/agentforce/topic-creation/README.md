## Agentforce Topic Creation
> Define conversation topics that guide Agentforce agents to the right actions.

### When to Use
- Building Agentforce agents with domain-specific capabilities
- Organizing agent behavior by business area (orders, support, billing)
- Controlling which actions are available for each conversation context

### Configuration / Code

```json
{
  "topic": {
    "name": "Order Management",
    "description": "Handle customer inquiries about orders, including status tracking, modifications, and cancellations",
    "scope": "Use this topic when the customer asks about their orders, delivery status, or wants to make changes to existing orders",
    "instructions": [
      "Always verify the customer identity before sharing order details",
      "For cancellations, check if the order is still in a cancellable state",
      "Escalate to a human agent if the customer is dissatisfied after 2 attempts"
    ],
    "actions": [
      "get-order-status",
      "modify-order",
      "cancel-order",
      "track-shipment"
    ]
  }
}
```

### How It Works
1. Topics group related actions under a business context
2. Agent uses the topic description to determine when to engage
3. Instructions provide guardrails for the agent behavior
4. Only actions listed in the topic are available during that context

### Gotchas
- Overlapping topic descriptions cause routing confusion — make scopes distinct
- Too many actions per topic reduce agent focus — keep it under 10
- Instructions are natural language — be specific and unambiguous
- Test topic routing with diverse user queries to verify classification

### Related
- [Mule Actions](../mule-actions/) — implementing actions
- [Custom Instructions](../custom-instructions/) — advanced instructions
