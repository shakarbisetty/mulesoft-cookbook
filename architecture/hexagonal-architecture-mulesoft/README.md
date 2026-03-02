## Hexagonal Architecture for MuleSoft
> Ports and adapters pattern for decoupling business logic from connectors and protocols

### When to Use
- Your Mule applications tightly couple business logic with connector-specific code
- Swapping a backend system (e.g., SOAP to REST, on-prem DB to cloud) requires rewriting entire flows
- Unit testing is difficult because flows directly call external systems
- You want to apply Domain-Driven Design principles to your MuleSoft integrations

### The Problem

Most MuleSoft applications embed business logic directly in flows alongside HTTP listeners, database connectors, and transformation code. When a backend changes (Oracle to PostgreSQL, SOAP to REST, on-prem to SaaS), developers must modify flows that contain business rules, risking regressions in logic that has nothing to do with the infrastructure change.

Hexagonal architecture (ports and adapters) isolates the business domain from external dependencies. In MuleSoft, this means separating "what the integration does" from "how it connects."

### Configuration / Code

#### Hexagonal Architecture in MuleSoft

```
                     ┌─────────────────────────────────────┐
                     │          DOMAIN CORE                │
                     │    (Pure business logic flows)      │
                     │                                     │
  INBOUND            │   ┌─────────────────────────┐      │           OUTBOUND
  ADAPTERS           │   │  Business Rules         │      │           ADAPTERS
  (Driving)          │   │  - Validate order        │      │           (Driven)
                     │   │  - Calculate pricing     │      │
  ┌──────────┐  PORT │   │  - Apply discounts       │      │  PORT  ┌──────────┐
  │ HTTP     │──────►│   │  - Determine fulfillment │      │──────►│ Database │
  │ Listener │       │   └─────────────────────────┘      │       │ Connector│
  └──────────┘       │                                     │       └──────────┘
                     │   Flows use variables, flow-refs,   │
  ┌──────────┐  PORT │   and DataWeave — no connectors     │  PORT  ┌──────────┐
  │ Anypoint │──────►│                                     │──────►│ HTTP     │
  │ MQ Sub   │       │                                     │       │ Request  │
  └──────────┘       │                                     │       └──────────┘
                     │                                     │
  ┌──────────┐  PORT │                                     │  PORT  ┌──────────┐
  │ Scheduler│──────►│                                     │──────►│ SFTP     │
  │          │       │                                     │       │ Write    │
  └──────────┘       └─────────────────────────────────────┘       └──────────┘

  PORTS = Sub-flow interfaces (input/output contracts)
  ADAPTERS = Flows with connectors that implement the port contract
```

#### Project Structure

```
src/main/mule/
├── adapters/
│   ├── inbound/
│   │   ├── http-order-adapter.xml      ← HTTP listener + request parsing
│   │   ├── mq-order-adapter.xml        ← Anypoint MQ subscriber
│   │   └── scheduler-adapter.xml       ← Cron-triggered batch
│   └── outbound/
│       ├── database-adapter.xml        ← DB connector calls
│       ├── salesforce-adapter.xml      ← SFDC connector calls
│       └── notification-adapter.xml    ← Email/SMS connector calls
├── domain/
│   ├── order-domain.xml                ← Pure business logic (no connectors)
│   ├── pricing-domain.xml              ← Pricing rules
│   └── validation-domain.xml           ← Validation rules
├── ports/
│   └── port-contracts.xml              ← Sub-flow signatures (the contracts)
└── global.xml                          ← Connector configs, error handlers
```

#### Inbound Adapter (HTTP)

```xml
<!-- adapters/inbound/http-order-adapter.xml -->
<flow name="http-order-adapter">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders" method="POST" />

    <!-- Adapter responsibility: parse protocol-specific input into domain object -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
{
    customerId: payload.customer_id,
    items: payload.line_items map {
        sku: $.sku,
        quantity: $.qty,
        requestedPrice: $.price
    },
    shippingAddress: payload.ship_to,
    channel: "WEB"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Hand off to domain — adapter does NOT contain business logic -->
    <flow-ref name="domain-process-order" />

    <!-- Adapter responsibility: transform domain output to protocol-specific response -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    order_id: payload.orderId,
    status: payload.status,
    total: payload.calculatedTotal,
    estimated_delivery: payload.estimatedDelivery
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Inbound Adapter (Anypoint MQ — Same Domain, Different Entry Point)

```xml
<!-- adapters/inbound/mq-order-adapter.xml -->
<flow name="mq-order-adapter">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ"
                            destination="order-queue"
                            acknowledgementMode="MANUAL" />

    <!-- Parse MQ message into same domain object -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
var msg = read(payload, "application/json")
---
{
    customerId: msg.customerRef,
    items: msg.orderLines map {
        sku: $.productCode,
        quantity: $.amount,
        requestedPrice: $.unitPrice
    },
    shippingAddress: msg.deliveryAddress,
    channel: "PARTNER_EDI"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- SAME domain flow — business logic is identical regardless of entry point -->
    <flow-ref name="domain-process-order" />

    <anypoint-mq:ack />
</flow>
```

#### Domain Core (No Connectors)

```xml
<!-- domain/order-domain.xml -->
<!-- This file contains ZERO connector references. Only flow-refs, DataWeave, and variables. -->

<sub-flow name="domain-process-order">
    <!-- Step 1: Validate the order -->
    <flow-ref name="domain-validate-order" />

    <!-- Step 2: Calculate pricing -->
    <flow-ref name="domain-calculate-pricing" />

    <!-- Step 3: Check inventory (calls outbound port, not connector directly) -->
    <flow-ref name="port-check-inventory" />

    <!-- Step 4: Apply business rules -->
    <choice>
        <when expression="#[vars.inventoryAvailable == true]">
            <!-- Step 5: Reserve inventory via outbound port -->
            <flow-ref name="port-reserve-inventory" />

            <!-- Step 6: Create order record via outbound port -->
            <flow-ref name="port-save-order" />

            <set-variable variableName="orderStatus" value="CONFIRMED" />
        </when>
        <otherwise>
            <set-variable variableName="orderStatus" value="BACKORDERED" />
            <!-- Notify via outbound port -->
            <flow-ref name="port-notify-backorder" />
        </otherwise>
    </choice>

    <!-- Build domain response -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
{
    orderId: vars.orderId,
    status: vars.orderStatus,
    calculatedTotal: vars.pricingResult.total,
    estimatedDelivery: vars.estimatedDelivery
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>

<sub-flow name="domain-validate-order">
    <validation:is-not-null value="#[payload.customerId]"
                           message="Customer ID is required" />
    <validation:validate-size value="#[payload.items]"
                             min="1" max="100"
                             message="Order must have 1-100 items" />
    <!-- Pure validation — no external calls -->
</sub-flow>

<sub-flow name="domain-calculate-pricing">
    <ee:transform>
        <ee:message>
            <ee:set-variable variableName="pricingResult"><![CDATA[%dw 2.0
output application/java
var items = payload.items
var subtotal = items reduce ((item, acc = 0) ->
    acc + (item.quantity * item.requestedPrice))
var discount = if (subtotal > 1000) 0.10 else 0
---
{
    subtotal: subtotal,
    discount: discount,
    total: subtotal * (1 - discount)
}]]></ee:set-variable>
        </ee:message>
    </ee:transform>
</sub-flow>
```

#### Outbound Port (Interface)

```xml
<!-- ports/port-contracts.xml -->
<!-- These sub-flows define the CONTRACT. They delegate to adapters. -->

<sub-flow name="port-check-inventory">
    <!-- Port delegates to whichever adapter is configured -->
    <flow-ref name="adapter-check-inventory" />
</sub-flow>

<sub-flow name="port-save-order">
    <flow-ref name="adapter-save-order" />
</sub-flow>

<sub-flow name="port-reserve-inventory">
    <flow-ref name="adapter-reserve-inventory" />
</sub-flow>

<sub-flow name="port-notify-backorder">
    <flow-ref name="adapter-notify-backorder" />
</sub-flow>
```

#### Outbound Adapter (Database)

```xml
<!-- adapters/outbound/database-adapter.xml -->
<sub-flow name="adapter-save-order">
    <!-- This is the ONLY place that knows about the database schema -->
    <db:insert config-ref="OrdersDB">
        <db:sql>INSERT INTO orders (id, customer_id, total, status, created_at)
               VALUES (:id, :custId, :total, :status, CURRENT_TIMESTAMP)</db:sql>
        <db:input-parameters>#[{
            id: vars.orderId,
            custId: payload.customerId,
            total: vars.pricingResult.total,
            status: vars.orderStatus
        }]</db:input-parameters>
    </db:insert>
</sub-flow>

<sub-flow name="adapter-check-inventory">
    <http:request config-ref="Inventory_API" path="/stock/#[payload.items[0].sku]"
                 method="GET" />
    <set-variable variableName="inventoryAvailable"
                  value="#[payload.quantityAvailable > 0]" />
</sub-flow>
```

#### Swapping Adapters (The Payoff)

```
BEFORE: Oracle on-prem
  port-save-order ──► adapter-save-order (Oracle DB connector)

AFTER: PostgreSQL on CloudHub
  port-save-order ──► adapter-save-order-postgres (PostgreSQL connector)

  Change: ONE adapter file. Domain logic: ZERO changes.
  Test: Only the new adapter needs testing. Domain tests still pass.
```

### How It Works

1. **Identify your domain boundaries** — what business logic is independent of technology?
2. **Define ports** as sub-flow contracts — inputs (variables/payload) and outputs (variables/payload)
3. **Implement adapters** for each external system — one adapter per connector type
4. **Keep the domain pure** — no connector elements, only DataWeave, flow-ref, choice, and variables
5. **Test independently** — domain flows can be tested with mock data (no connectors to stub)

### Gotchas

- **MuleSoft does not have native interface/implementation patterns.** Ports are conventions (sub-flow naming), not enforced contracts. Discipline is required to prevent leaking connectors into domain flows.
- **Performance overhead of extra flow-refs is negligible.** A flow-ref adds < 1ms. The architectural benefit far outweighs the micro-overhead.
- **Error handling must be adapter-aware.** Each adapter translates connector-specific errors (HTTP:TIMEOUT, DB:CONNECTIVITY) into domain errors (APP:SERVICE_UNAVAILABLE) so the domain does not depend on connector error types.
- **This pattern does not mean more Mule applications.** All adapters, ports, and domain flows live in ONE Mule application. The separation is at the file/flow level, not the deployment level.
- **DataWeave in the domain is fine.** DataWeave is a pure functional language — it is part of your domain logic, not an external dependency. Transformations belong in the domain when they implement business rules.

### Related

- [Domain-Driven API Design](../domain-driven-api-design/) — bounded contexts that map to hexagonal boundaries
- [Anti-Corruption Layer](../anti-corruption-layer/) — adapters as anti-corruption layers for legacy systems
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — when coupling connectors to logic causes problems
- [Strangler Fig Migration](../strangler-fig-migration/) — using adapters to incrementally replace backends
