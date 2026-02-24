## Legacy ESB Patterns to API-Led Connectivity
> Migrate from traditional ESB integration patterns to MuleSoft API-led architecture

### When to Use
- Migrating from legacy ESB (Mule ESB 3, IBM IIB, TIBCO, Oracle SOA)
- Point-to-point integrations need modernization
- ESB "hub and spoke" creating bottlenecks
- Moving to microservices-friendly integration

### Configuration / Code

#### 1. ESB Anti-Patterns to Replace

```
ESB Pattern              -> API-Led Pattern
──────────────────────────────────────────
Central Message Bus      -> Distributed APIs + MQ
Point-to-Point Adapter   -> System API (reusable)
Orchestration Engine     -> Process API
Protocol Translation     -> System API layer
Content-Based Routing    -> Process API with logic
Batch File Transfer      -> Event-driven + streaming
Shared Database          -> System API + API contracts
```

#### 2. Replace ESB Routing with API Contracts

```xml
<!-- ESB pattern: content-based routing in single app -->
<choice>
    <when expression="#[payload.type == 'ORDER']">
        <flow-ref name="processOrder" />
    </when>
    <when expression="#[payload.type == 'RETURN']">
        <flow-ref name="processReturn" />
    </when>
</choice>

<!-- API-led: separate APIs with clear contracts -->
<!-- orders-process-api handles orders -->
<!-- returns-process-api handles returns -->
<!-- Router at experience layer directs to correct API -->
```

#### 3. Replace Shared State with API Calls

```xml
<!-- ESB: shared database lookup -->
<db:select config-ref="SharedDB">
    <db:sql>SELECT * FROM customer WHERE id = :id</db:sql>
</db:select>

<!-- API-led: call Customer System API -->
<http:request config-ref="Customer_System_API"
    method="GET" path="/customers/{id}">
    <http:uri-params>#[{ 'id': vars.customerId }]</http:uri-params>
</http:request>
```

#### 4. Replace ESB Queue Mediation

```xml
<!-- ESB: central queue mediation -->
<jms:inbound-endpoint queue="input" />
<choice>
    <when><!-- route to system A --></when>
    <when><!-- route to system B --></when>
</choice>

<!-- API-led: Anypoint MQ with topic exchanges -->
<!-- Publisher sends to exchange -->
<anypoint-mq:publish config-ref="MQ_Config"
    destination="orders-exchange" />

<!-- Each system subscribes independently -->
<!-- system-a-api subscribes to orders-exchange -->
<!-- system-b-api subscribes to orders-exchange -->
```

### How It Works
1. ESB centralizes all integration logic in one layer; API-led distributes it
2. System APIs replace ESB adapters with reusable, self-documenting interfaces
3. Process APIs replace ESB orchestration with composable business logic
4. Anypoint MQ replaces ESB internal queues for decoupled communication

### Migration Checklist
- [ ] Map all ESB integrations and data flows
- [ ] Identify backend systems (candidates for System APIs)
- [ ] Identify business processes (candidates for Process APIs)
- [ ] Design API contracts (RAML/OAS) for each API
- [ ] Build System APIs first (bottom-up)
- [ ] Build Process APIs as orchestrators
- [ ] Replace ESB queues with Anypoint MQ
- [ ] Implement API management (security, rate limiting)
- [ ] Run parallel for validation
- [ ] Decommission ESB flows

### Gotchas
- "Lift and shift" (copying ESB logic to Mule 4) is NOT API-led migration
- Not every integration needs all three layers
- ESB transaction support (XA) has limited equivalents in API-led
- Performance may differ due to network hops
- Team organization should align with API ownership

### Related
- [monolith-to-api-led](../monolith-to-api-led/) - Monolith decomposition
- [mule3-to-4-mma](../../runtime-upgrades/mule3-to-4-mma/) - Mule 3 to 4
- [sync-to-event-driven](../sync-to-event-driven/) - Async patterns
