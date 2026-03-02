## CQRS Implementation
> Command/query separation with event sourcing bridge in MuleSoft

### When to Use
- Read and write workloads have vastly different scaling requirements
- Your API serves both high-volume read queries and complex write operations
- You need separate data models optimized for reads vs. writes
- Your integration requires an audit trail of every state change (event sourcing)

### The Problem

Traditional CRUD APIs use the same data model for reads and writes. An order table optimized for transactional writes (normalized, foreign keys, constraints) performs poorly for read-heavy dashboards (denormalized, pre-aggregated, cached). Scaling the database for reads impacts write performance and vice versa.

CQRS (Command Query Responsibility Segregation) separates the write model from the read model. Commands mutate state and publish events. Queries read from a projection optimized for the specific read pattern. MuleSoft sits at the center, routing commands and queries to the appropriate model and synchronizing them via events.

### Configuration / Code

#### CQRS Architecture in MuleSoft

```
                    ┌───────────────────────────────┐
                    │        API Gateway /          │
                    │      Experience Layer         │
                    └──────┬───────────┬────────────┘
                           │           │
              Commands     │           │    Queries
              (POST/PUT/   │           │    (GET)
               DELETE)     │           │
                           ▼           ▼
              ┌────────────────┐  ┌────────────────┐
              │  Command API   │  │   Query API    │
              │  (Process)     │  │  (Process)     │
              │                │  │                │
              │ - Validate     │  │ - Read from    │
              │ - Apply rules  │  │   optimized    │
              │ - Write to     │  │   read store   │
              │   write store  │  │ - Cache layer  │
              │ - Publish event│  │                │
              └───────┬────────┘  └───────┬────────┘
                      │                   │
                      ▼                   ▼
              ┌──────────────┐    ┌──────────────┐
              │  Write Store │    │  Read Store   │
              │ (Normalized  │    │ (Denormalized │
              │  RDBMS)      │    │  NoSQL/Cache) │
              └──────┬───────┘    └──────▲───────┘
                     │                   │
                     │    ┌──────────┐   │
                     └───►│  Event   │───┘
                          │  Bus     │
                          │(Anypoint │
                          │   MQ)    │
                          └──────────┘
```

#### Command Side Implementation

```xml
<!-- Command API: handles write operations -->
<flow name="command-create-order">
    <http:listener config-ref="HTTPS_Listener" path="/api/commands/orders"
                   method="POST" />

    <!-- Validate command -->
    <flow-ref name="validate-create-order-command" />

    <!-- Write to command store (source of truth) -->
    <db:insert config-ref="WriteDB">
        <db:sql>INSERT INTO orders (id, customer_id, items, total, status, created_at, version)
               VALUES (:id, :custId, :items, :total, 'CREATED', NOW(), 1)</db:sql>
        <db:input-parameters>#[{
            id: vars.orderId,
            custId: payload.customerId,
            items: write(payload.items, "application/json"),
            total: vars.calculatedTotal
        }]</db:input-parameters>
    </db:insert>

    <!-- Publish domain event for read model synchronization -->
    <anypoint-mq:publish config-ref="Anypoint_MQ"
                         destination="domain-events-exchange">
        <anypoint-mq:body>#[%dw 2.0
output application/json
---
{
    eventType: "OrderCreated",
    eventId: uuid(),
    aggregateId: vars.orderId,
    aggregateType: "Order",
    version: 1,
    timestamp: now(),
    data: {
        orderId: vars.orderId,
        customerId: payload.customerId,
        items: payload.items,
        total: vars.calculatedTotal,
        status: "CREATED"
    }
}]</anypoint-mq:body>
    </anypoint-mq:publish>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: vars.orderId,
    status: "CREATED",
    message: "Order accepted for processing"
}]]></ee:set-payload>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 201 }]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</flow>

<!-- Command: Update order status -->
<flow name="command-update-order-status">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/commands/orders/{orderId}/status"
                   method="PUT" />

    <!-- Optimistic locking with version -->
    <db:update config-ref="WriteDB">
        <db:sql>UPDATE orders SET status = :status, version = version + 1,
               updated_at = NOW()
               WHERE id = :id AND version = :expectedVersion</db:sql>
        <db:input-parameters>#[{
            id: attributes.uriParams.orderId,
            status: payload.status,
            expectedVersion: payload.expectedVersion
        }]</db:input-parameters>
    </db:update>

    <!-- Check optimistic lock -->
    <choice>
        <when expression="#[payload.affectedRows == 0]">
            <raise-error type="APP:CONFLICT"
                        description="Order was modified by another process. Refresh and retry." />
        </when>
    </choice>

    <!-- Publish status change event -->
    <anypoint-mq:publish config-ref="Anypoint_MQ"
                         destination="domain-events-exchange">
        <anypoint-mq:body>#[%dw 2.0
output application/json
---
{
    eventType: "OrderStatusChanged",
    eventId: uuid(),
    aggregateId: attributes.uriParams.orderId,
    aggregateType: "Order",
    version: payload.expectedVersion + 1,
    timestamp: now(),
    data: {
        orderId: attributes.uriParams.orderId,
        previousStatus: vars.previousStatus,
        newStatus: payload.status
    }
}]</anypoint-mq:body>
    </anypoint-mq:publish>
</flow>
```

#### Event Projector (Read Model Synchronization)

```xml
<!-- Event projector: subscribes to events, updates read model -->
<flow name="event-projector-orders">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ"
                            destination="order-read-projection-queue"
                            acknowledgementMode="MANUAL" />

    <set-variable variableName="event"
                  value="#[read(payload, 'application/json')]" />

    <choice>
        <when expression="#[vars.event.eventType == 'OrderCreated']">
            <!-- Insert denormalized read model -->
            <db:insert config-ref="ReadDB">
                <db:sql>INSERT INTO order_views (
                    order_id, customer_id, customer_name, customer_email,
                    item_count, total, status, created_at
                ) VALUES (
                    :orderId, :custId, :custName, :custEmail,
                    :itemCount, :total, :status, :createdAt
                )</db:sql>
                <db:input-parameters>#[{
                    orderId: vars.event.data.orderId,
                    custId: vars.event.data.customerId,
                    custName: vars.customerLookup.name,
                    custEmail: vars.customerLookup.email,
                    itemCount: sizeOf(vars.event.data.items),
                    total: vars.event.data.total,
                    status: vars.event.data.status,
                    createdAt: vars.event.timestamp
                }]</db:input-parameters>
            </db:insert>
        </when>

        <when expression="#[vars.event.eventType == 'OrderStatusChanged']">
            <!-- Update read model -->
            <db:update config-ref="ReadDB">
                <db:sql>UPDATE order_views SET status = :status, updated_at = :updatedAt
                       WHERE order_id = :orderId</db:sql>
                <db:input-parameters>#[{
                    orderId: vars.event.data.orderId,
                    status: vars.event.data.newStatus,
                    updatedAt: vars.event.timestamp
                }]</db:input-parameters>
            </db:update>
        </when>
    </choice>

    <anypoint-mq:ack />
</flow>
```

#### Query Side Implementation

```xml
<!-- Query API: reads from optimized read store -->
<flow name="query-orders-dashboard">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/queries/orders/dashboard"
                   method="GET" />

    <!-- Read from denormalized view — no joins needed -->
    <db:select config-ref="ReadDB">
        <db:sql>SELECT order_id, customer_name, item_count, total, status, created_at
               FROM order_views
               WHERE status = :status
               ORDER BY created_at DESC
               LIMIT :limit OFFSET :offset</db:sql>
        <db:input-parameters>#[{
            status: attributes.queryParams.status default 'ALL',
            limit: attributes.queryParams.limit default 20,
            offset: attributes.queryParams.offset default 0
        }]</db:input-parameters>
    </db:select>
</flow>

<!-- Query: Single order detail (could use cache) -->
<flow name="query-order-detail">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/queries/orders/{orderId}"
                   method="GET" />

    <!-- Try cache first -->
    <try>
        <os:retrieve key="#['order-view-' ++ attributes.uriParams.orderId]"
                     objectStore="Query_Cache" />
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <!-- Cache miss — read from read store -->
            <db:select config-ref="ReadDB">
                <db:sql>SELECT * FROM order_views WHERE order_id = :id</db:sql>
                <db:input-parameters>#[{ id: attributes.uriParams.orderId }]</db:input-parameters>
            </db:select>

            <!-- Cache the result -->
            <os:store key="#['order-view-' ++ attributes.uriParams.orderId]"
                      objectStore="Query_Cache">
                <os:value>#[write(payload, 'application/json')]</os:value>
            </os:store>
        </on-error-continue>
    </error-handler>
    </try>
</flow>

<os:object-store name="Query_Cache"
                 persistent="false"
                 entryTtl="60"
                 entryTtlUnit="SECONDS" />
```

#### Event Sourcing Extension

| Concept | Implementation |
|---------|---------------|
| **Event store** | Append-only table: `(event_id, aggregate_id, event_type, data, version, timestamp)` |
| **Aggregate reconstruction** | Replay all events for an aggregate ID to rebuild current state |
| **Snapshots** | Periodically store materialized state to avoid replaying all events |
| **Projection** | Event subscriber that builds a specific read model from events |
| **Temporal queries** | Replay events up to a point in time to see historical state |

### How It Works

1. **Split your API into commands and queries** — POST/PUT/DELETE are commands, GET requests are queries
2. **Commands write to the write store** and publish domain events to Anypoint MQ
3. **Event projectors subscribe** to events and update denormalized read stores
4. **Queries read from the read store** — optimized for the specific query pattern, with optional caching
5. **Read model can be rebuilt** by replaying events from the event store (if using event sourcing)

### Gotchas

- **Eventual consistency between write and read models.** After a command succeeds, the read model may take 100ms-1s to update (Anypoint MQ delivery + projection processing). Consumers calling the query API immediately after a command may see stale data. Return the created/updated resource in the command response to give the client immediate consistency for that specific record.
- **Read model projectors must be idempotent.** Anypoint MQ delivers at-least-once. Use `event_id` as a dedup key to prevent duplicate projections.
- **Optimistic locking version conflicts are expected.** When two commands try to update the same aggregate concurrently, one will fail. Clients must handle 409 Conflict responses gracefully.
- **Do not use CQRS for simple CRUD.** If your read and write models are the same (or nearly so), CQRS adds complexity without benefit. Use it when read/write patterns genuinely diverge.
- **Event schema evolution is hard.** Once events are stored, their schema is permanent. Use additive-only changes (new optional fields). Never remove or rename fields in published events.

### Related

- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — the event backbone that powers CQRS
- [Orchestration vs Choreography](../orchestration-vs-choreography/) — event projectors are choreography consumers
- [Hexagonal Architecture](../hexagonal-architecture-mulesoft/) — CQRS naturally fits the ports and adapters model
- [Data Mesh Integration](../data-mesh-integration/) — CQRS read models as data products
