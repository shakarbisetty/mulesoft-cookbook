## A2A Agent Card Registry
> Publish and discover agent capabilities using A2A Agent Cards.

### When to Use
- Building an enterprise agent marketplace
- Automated agent discovery for orchestration
- Documenting agent capabilities and requirements

### Configuration / Code

**Agent Card (JSON):**
```json
{
  "name": "Order Management Agent",
  "description": "Handles order creation, status tracking, and modifications",
  "url": "https://agents.example.com/order-agent",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true
  },
  "skills": [
    {"name": "create-order", "description": "Create a new customer order"},
    {"name": "track-order", "description": "Get current order status"},
    {"name": "cancel-order", "description": "Cancel a pending order"}
  ],
  "authentication": {
    "type": "oauth2",
    "tokenUrl": "https://auth.example.com/token"
  }
}
```

**Registry endpoint in Mule:**
```xml
<flow name="agent-registry">
    <http:listener config-ref="HTTP_Listener" path="/.well-known/agent.json" method="GET"/>
    <parse-template location="agent-card.json"/>
</flow>
```

### How It Works
1. Each agent publishes an Agent Card at `/.well-known/agent.json`
2. Registry service aggregates Agent Cards from known agent URLs
3. Orchestrators query the registry to discover agents with needed skills
4. Agent Cards include authentication requirements and capabilities

### Gotchas
- Agent Cards should be versioned — breaking changes need a new version
- Registry must handle agents that go offline (health checks)
- Skill descriptions should be detailed enough for AI routing decisions
- Authentication info in the card tells clients HOW to auth, not secrets

### Related
- [Multi-Agent Orchestration](../multi-agent-orchestration/) — using discovered agents
- [Protocol Versioning](../protocol-versioning/) — version management
