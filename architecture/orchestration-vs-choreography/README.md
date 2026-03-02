## Orchestration vs Choreography
> Decision framework with trade-off matrix for MuleSoft integration patterns

### When to Use
- You are designing a multi-step business process and need to decide who controls the flow
- Your centralized orchestrator has become a bottleneck or single point of failure
- Teams want autonomy over their services but you need cross-system consistency
- You are evaluating Anypoint MQ, VM queues, or direct HTTP calls for inter-service communication

### The Problem

Integration architects face a fundamental design choice: should a central process API coordinate all steps (orchestration), or should each service react to events independently (choreography)? Choosing wrong leads to either a monolithic orchestrator that bottlenecks delivery, or a spaghetti of event chains that nobody can debug.

Most MuleSoft implementations default to orchestration because it maps naturally to API-led process APIs. But choreography — using Anypoint MQ, VM queues, or platform events — is often better for loosely-coupled, high-availability scenarios.

### Configuration / Code

#### Architecture Comparison

```
ORCHESTRATION (centralized control):

  ┌──────────────────────────┐
  │   Process API            │
  │   (Orchestrator)         │
  │                          │
  │   Step 1 ──► Validate    │
  │   Step 2 ──► Enrich      │──── Owns the sequence
  │   Step 3 ──► Transform   │──── Knows all participants
  │   Step 4 ──► Route       │──── Handles compensation
  │                          │
  └──┬─────┬─────┬──────┬───┘
     │     │     │      │
     ▼     ▼     ▼      ▼
   Svc A  Svc B  Svc C  Svc D


CHOREOGRAPHY (decentralized, event-driven):

  Svc A ──publish──► [Order Created Event]
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
           Svc B       Svc C       Svc D
        (Inventory)  (Billing)   (Shipping)
              │           │           │
              ▼           ▼           ▼
     [Reserved Event] [Charged Event] [Shipped Event]

  No central controller. Each service reacts to events
  and publishes its own events. Services are independently
  deployable and scalable.
```

#### Decision Matrix

| Factor | Orchestration | Choreography |
|--------|--------------|--------------|
| **Visibility** | Full — orchestrator has complete view | Low — must aggregate from event logs |
| **Coupling** | Tight — orchestrator knows all services | Loose — services only know events |
| **Error handling** | Centralized — try/catch, compensation | Distributed — saga pattern required |
| **Team autonomy** | Low — orchestrator team is bottleneck | High — teams own their service independently |
| **Debugging** | Easy — single flow shows all steps | Hard — requires distributed tracing |
| **Scalability** | Limited by orchestrator throughput | Each service scales independently |
| **Latency** | Predictable — sequential steps | Variable — depends on consumer speed |
| **Consistency** | Strong — orchestrator manages state | Eventual — services converge over time |
| **Change impact** | High — adding a step changes orchestrator | Low — new service subscribes to existing event |
| **Best for** | < 5 steps, tight SLAs, simple workflows | > 5 participants, high throughput, autonomy |

#### Decision Flowchart

```
START: Multi-service business process
  │
  ├─ Must all steps complete in strict order?
  │    YES ──► ORCHESTRATION
  │    NO  ──┐
  │          │
  │   ├─ Do you need a guaranteed response to the caller?
  │   │    YES and < 5 services ──► ORCHESTRATION
  │   │    YES and > 5 services ──► HYBRID (sync ack + async processing)
  │   │    NO  ──┐
  │   │          │
  │   │   ├─ Are participating teams independent with separate release cycles?
  │   │   │    YES ──► CHOREOGRAPHY
  │   │   │    NO  ──► ORCHESTRATION (simpler for single-team ownership)
  │   │   │
  │   │   └─ Is throughput > 1000 events/min?
  │   │        YES ──► CHOREOGRAPHY (no central bottleneck)
  │   │        NO  ──► Either works — choose based on team preference
  │   │
  └───┘
```

#### Orchestration Implementation (MuleSoft Process API)

```xml
<flow name="prc-order-fulfillment">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders/fulfill"
                   method="POST" />

    <!-- Step 1: Validate inventory -->
    <http:request config-ref="sys-inventory" path="/check" method="POST">
        <http:body>#[payload]</http:body>
    </http:request>
    <set-variable variableName="inventoryResult" value="#[payload]" />

    <choice>
        <when expression="#[vars.inventoryResult.available == true]">
            <!-- Step 2: Reserve inventory -->
            <http:request config-ref="sys-inventory" path="/reserve" method="POST" />

            <!-- Step 3: Charge payment -->
            <try>
                <http:request config-ref="sys-billing" path="/charge" method="POST" />
            <error-handler>
                <on-error-propagate>
                    <!-- Compensation: release inventory if payment fails -->
                    <http:request config-ref="sys-inventory" path="/release"
                                 method="POST" />
                    <raise-error type="APP:PAYMENT_FAILED" />
                </on-error-propagate>
            </error-handler>
            </try>

            <!-- Step 4: Create shipment -->
            <http:request config-ref="sys-shipping" path="/shipments" method="POST" />
        </when>
        <otherwise>
            <raise-error type="APP:OUT_OF_STOCK" />
        </otherwise>
    </choice>
</flow>
```

#### Choreography Implementation (Anypoint MQ Events)

```xml
<!-- Service A: Order Service — publishes event -->
<flow name="order-service-create">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders" method="POST" />

    <!-- Save order to DB -->
    <db:insert config-ref="OrdersDB">
        <db:sql>INSERT INTO orders (id, customer_id, total, status)
               VALUES (:id, :custId, :total, 'CREATED')</db:sql>
        <db:input-parameters>#[{
            id: uuid(),
            custId: payload.customerId,
            total: payload.total
        }]</db:input-parameters>
    </db:insert>

    <!-- Publish event — no knowledge of who consumes it -->
    <anypoint-mq:publish config-ref="Anypoint_MQ"
                         destination="order-events-exchange"
                         messageId="#[vars.orderId]">
        <anypoint-mq:body>#[%dw 2.0
output application/json
---
{
    eventType: "ORDER_CREATED",
    orderId: vars.orderId,
    payload: payload,
    timestamp: now()
}]</anypoint-mq:body>
    </anypoint-mq:publish>

    <set-payload value='#[{ status: "created", orderId: vars.orderId }]' />
</flow>

<!-- Service B: Inventory Service — reacts to event -->
<flow name="inventory-subscriber">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ"
                            destination="inventory-order-queue"
                            acknowledgementMode="MANUAL" />

    <choice>
        <when expression="#[payload.eventType == 'ORDER_CREATED']">
            <!-- Reserve inventory -->
            <db:update config-ref="InventoryDB">
                <db:sql>UPDATE stock SET reserved = reserved + :qty
                       WHERE sku = :sku AND available >= :qty</db:sql>
                <db:input-parameters>#[{
                    sku: payload.payload.sku,
                    qty: payload.payload.quantity
                }]</db:input-parameters>
            </db:update>

            <!-- Publish result event -->
            <anypoint-mq:publish config-ref="Anypoint_MQ"
                                 destination="order-events-exchange">
                <anypoint-mq:body>#[%dw 2.0
output application/json
---
{
    eventType: "INVENTORY_RESERVED",
    orderId: payload.orderId,
    timestamp: now()
}]</anypoint-mq:body>
            </anypoint-mq:publish>

            <anypoint-mq:ack />
        </when>
    </choice>
</flow>
```

#### Hybrid Pattern: Synchronous Acknowledgment + Async Processing

```
Consumer ──POST /orders──► Experience API ──► Anypoint MQ
         ◄──202 Accepted──┘                      │
                                                  ▼
                                         Process API (subscriber)
                                                  │
                                          ┌───────┼───────┐
                                          ▼       ▼       ▼
                                       Svc A    Svc B    Svc C
                                     (choreography among backends)

  Consumer gets fast sync response.
  Backend processing uses choreography for scale.
```

### How It Works

1. **Map your process** — identify all participants, their dependencies, and ordering constraints
2. **Apply the decision matrix** — score each factor for your specific scenario
3. **Choose the pattern** — orchestration, choreography, or hybrid
4. **Implement error handling** — compensation flows for orchestration, saga pattern for choreography
5. **Add observability** — centralized logging for orchestration, distributed tracing (correlation IDs) for choreography

### Gotchas

- **Choreography without distributed tracing is a nightmare.** Before adopting choreography, ensure you have correlation IDs propagated through all events and a centralized log aggregator (ELK, Splunk, or Anypoint Monitoring).
- **Anypoint MQ is not a full event broker.** It supports queues and exchanges but lacks features like event replay, consumer groups, or exactly-once delivery. For complex choreography, evaluate if Anypoint MQ is sufficient or if you need Kafka/Solace.
- **Saga compensation in choreography is hard.** Each service must publish compensating events (e.g., `INVENTORY_RELEASED` if payment fails). Design these from day one, not as an afterthought.
- **Orchestration does not mean synchronous.** An orchestrator can call services asynchronously using scatter-gather or Anypoint MQ. The key distinction is centralized vs. decentralized control, not sync vs. async.
- **Event schema versioning is critical in choreography.** When Service A changes its event schema, all subscribers must handle both old and new formats. Use schema registry or versioned event types.

### Related

- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — deep dive on Anypoint MQ and event patterns
- [Sync-Async Decision Flowchart](../sync-async-decision-flowchart/) — when to use async communication
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — protecting orchestrators from slow services
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — avoiding monolithic orchestrators
