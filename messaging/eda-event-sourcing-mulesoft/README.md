## Event Sourcing in MuleSoft

> Implement an event store with append-only event persistence, event replay for state reconstruction, and projection rebuilding for read-optimized views.

### When to Use
- You need a complete audit trail of every state change (regulatory compliance, financial systems)
- You want to reconstruct the state of any entity at any point in time
- You need to rebuild read models or projections without losing source data
- Traditional CRUD updates are losing business context (you know the current state but not how you got there)

### The Problem
In a CRUD system, when you update an order status from PENDING to SHIPPED, the PENDING state is overwritten and lost. If a dispute arises, you cannot prove what the state was at a specific time. Event sourcing stores every state change as an immutable event: OrderCreated, PaymentReceived, InventoryReserved, OrderShipped. The current state is derived by replaying all events for that entity. MuleSoft can implement event sourcing using a database event store, Anypoint MQ or Kafka for event distribution, and DataWeave for projection computation.

### Configuration

#### Event Store Schema

```sql
-- PostgreSQL event store table
CREATE TABLE event_store (
    event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id    VARCHAR(100) NOT NULL,   -- e.g., order ID
    aggregate_type  VARCHAR(50) NOT NULL,     -- e.g., "Order"
    event_type      VARCHAR(100) NOT NULL,    -- e.g., "OrderCreated"
    event_data      JSONB NOT NULL,           -- event payload
    metadata        JSONB,                    -- correlation IDs, user info
    version         INTEGER NOT NULL,         -- optimistic concurrency
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Optimistic locking: unique version per aggregate
    CONSTRAINT uq_aggregate_version UNIQUE (aggregate_id, version)
);

CREATE INDEX idx_event_store_aggregate ON event_store (aggregate_id, version);
CREATE INDEX idx_event_store_type ON event_store (event_type, created_at);

-- Projection table (read model)
CREATE TABLE order_projections (
    order_id        VARCHAR(100) PRIMARY KEY,
    customer_id     VARCHAR(100),
    status          VARCHAR(50),
    total_amount    DECIMAL(12,2),
    items           JSONB,
    last_event_id   UUID,
    last_event_at   TIMESTAMP WITH TIME ZONE,
    projection_version INTEGER DEFAULT 0
);
```

#### Append Event Flow

```xml
<!--
    Append an event to the event store.
    Uses optimistic concurrency: if the version already exists,
    the INSERT fails (concurrent modification detected).
-->
<flow name="append-event">
    <http:listener config-ref="HTTP_Listener" path="/api/events" method="POST" />

    <!-- Validate event structure -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    aggregateId: payload.aggregateId,
    aggregateType: payload.aggregateType,
    eventType: payload.eventType,
    eventData: payload.eventData,
    metadata: {
        correlationId: correlationId,
        userId: attributes.headers."x-user-id" default "system",
        source: attributes.headers."x-source" default "unknown",
        timestamp: now()
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Get current version for this aggregate -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT COALESCE(MAX(version), 0) as current_version
                 FROM event_store WHERE aggregate_id = :aggregateId</db:sql>
        <db:input-parameters>#[{aggregateId: payload.aggregateId}]</db:input-parameters>
    </db:select>

    <set-variable variableName="nextVersion" value="#[payload[0].current_version + 1]" />

    <!-- Append event with version check (optimistic lock) -->
    <try>
        <db:insert config-ref="Database_Config">
            <db:sql><![CDATA[
                INSERT INTO event_store
                    (aggregate_id, aggregate_type, event_type, event_data, metadata, version)
                VALUES
                    (:aggregateId, :aggregateType, :eventType,
                     :eventData::jsonb, :metadata::jsonb, :version)
            ]]></db:sql>
            <db:input-parameters><![CDATA[#[{
                aggregateId: payload.aggregateId,
                aggregateType: payload.aggregateType,
                eventType: payload.eventType,
                eventData: write(payload.eventData, "application/json"),
                metadata: write(payload.metadata, "application/json"),
                version: vars.nextVersion
            }]]]></db:input-parameters>
        </db:insert>

        <!-- Publish event to Anypoint MQ for downstream consumers -->
        <anypoint-mq:publish config-ref="AMQ_Config" destination="domain-events">
            <anypoint-mq:message>
                <anypoint-mq:body>#[output application/json --- {
                    eventId: uuid(),
                    aggregateId: payload.aggregateId,
                    eventType: payload.eventType,
                    eventData: payload.eventData,
                    version: vars.nextVersion,
                    timestamp: now()
                }]</anypoint-mq:body>
                <anypoint-mq:properties>
                    <anypoint-mq:property key="eventType" value="#[payload.eventType]" />
                    <anypoint-mq:property key="aggregateId" value="#[payload.aggregateId]" />
                </anypoint-mq:properties>
            </anypoint-mq:message>
        </anypoint-mq:publish>

        <error-handler>
            <!-- Optimistic concurrency violation -->
            <on-error-propagate type="DB:QUERY_EXECUTION">
                <logger level="WARN"
                    message="Concurrent modification on #[payload.aggregateId] — client should retry" />
                <set-variable variableName="httpStatus" value="409" />
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "CONCURRENT_MODIFICATION",
    message: "Aggregate version conflict. Retry with latest version."
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Replay Events (Reconstruct State)

```xml
<!--
    Replay all events for an aggregate to reconstruct its current state.
    This is the "left fold" over the event stream.
-->
<flow name="replay-aggregate-state">
    <http:listener config-ref="HTTP_Listener"
        path="/api/aggregates/{aggregateId}/state" method="GET" />

    <!-- Load all events for this aggregate, ordered by version -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT event_type, event_data, version, created_at
                 FROM event_store
                 WHERE aggregate_id = :aggregateId
                 ORDER BY version ASC</db:sql>
        <db:input-parameters>#[{aggregateId: attributes.uriParams.aggregateId}]</db:input-parameters>
    </db:select>

    <choice>
        <when expression="#[sizeOf(payload) == 0]">
            <set-variable variableName="httpStatus" value="404" />
            <set-payload value='#[output application/json --- {error: "Aggregate not found"}]' />
        </when>
        <otherwise>
            <!-- Apply events using DataWeave reduce (left fold) -->
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json

// Event handlers: each event type applies a state change
fun applyEvent(state, event) =
    event.event_type match {
        case "OrderCreated" -> state ++ {
            orderId: event.event_data.orderId,
            customerId: event.event_data.customerId,
            items: event.event_data.items,
            totalAmount: event.event_data.totalAmount,
            status: "CREATED"
        }
        case "PaymentReceived" -> state ++ {
            paymentId: event.event_data.paymentId,
            paidAmount: event.event_data.amount,
            status: "PAID"
        }
        case "InventoryReserved" -> state ++ {
            reservationId: event.event_data.reservationId,
            status: "RESERVED"
        }
        case "OrderShipped" -> state ++ {
            shipmentId: event.event_data.shipmentId,
            shippedAt: event.event_data.shippedAt,
            status: "SHIPPED"
        }
        case "OrderCancelled" -> state ++ {
            cancelledAt: event.event_data.cancelledAt,
            cancelReason: event.event_data.reason,
            status: "CANCELLED"
        }
        else -> state
    }
---
{
    aggregateId: attributes.uriParams.aggregateId,
    currentState: payload reduce (event, state = {}) ->
        applyEvent(state, {
            event_type: event.event_type,
            event_data: read(event.event_data, "application/json")
        }),
    version: max(payload.version),
    eventCount: sizeOf(payload),
    lastModified: max(payload.created_at)
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </otherwise>
    </choice>
</flow>
```

#### Projection Builder (Event Consumer)

```xml
<!--
    Async projection builder: consumes domain events and updates
    the read-optimized projection table.
-->
<flow name="projection-builder" maxConcurrency="1">
    <anypoint-mq:subscriber config-ref="AMQ_Config"
        destination="domain-events"
        acknowledgementMode="MANUAL" />

    <set-variable variableName="event"
        value="#[read(payload, 'application/json')]" />

    <logger level="INFO"
        message="Projecting: #[vars.event.eventType] for #[vars.event.aggregateId]" />

    <try>
        <choice>
            <when expression="#[vars.event.eventType == 'OrderCreated']">
                <db:insert config-ref="Database_Config">
                    <db:sql><![CDATA[
                        INSERT INTO order_projections
                            (order_id, customer_id, status, total_amount, items, last_event_id, last_event_at)
                        VALUES (:orderId, :customerId, 'CREATED', :totalAmount,
                                :items::jsonb, :eventId::uuid, :eventTime::timestamptz)
                        ON CONFLICT (order_id) DO NOTHING
                    ]]></db:sql>
                    <db:input-parameters><![CDATA[#[{
                        orderId: vars.event.eventData.orderId,
                        customerId: vars.event.eventData.customerId,
                        totalAmount: vars.event.eventData.totalAmount,
                        items: write(vars.event.eventData.items, "application/json"),
                        eventId: vars.event.eventId,
                        eventTime: vars.event.timestamp
                    }]]]></db:input-parameters>
                </db:insert>
            </when>

            <when expression="#[vars.event.eventType == 'OrderShipped']">
                <db:update config-ref="Database_Config">
                    <db:sql><![CDATA[
                        UPDATE order_projections
                        SET status = 'SHIPPED',
                            last_event_id = :eventId::uuid,
                            last_event_at = :eventTime::timestamptz,
                            projection_version = projection_version + 1
                        WHERE order_id = :orderId
                          AND last_event_at < :eventTime::timestamptz
                    ]]></db:sql>
                    <db:input-parameters><![CDATA[#[{
                        orderId: vars.event.aggregateId,
                        eventId: vars.event.eventId,
                        eventTime: vars.event.timestamp
                    }]]]></db:input-parameters>
                </db:update>
            </when>

            <!-- Add handlers for other event types -->
        </choice>

        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                    message="Projection failed for #[vars.event.eventType]: #[error.description]" />
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Projection Rebuilder (Full Replay)

```xml
<!--
    Rebuild all projections from scratch by replaying the entire event store.
    Use when: projection schema changes, bug fix in projection logic,
    or adding a new projection type.
-->
<flow name="rebuild-projections">
    <http:listener config-ref="HTTP_Listener"
        path="/api/admin/projections/rebuild" method="POST" />

    <!-- Truncate existing projections -->
    <db:execute-script config-ref="Database_Config">
        <db:sql>TRUNCATE TABLE order_projections</db:sql>
    </db:execute-script>

    <!-- Stream all events ordered by creation time -->
    <db:select config-ref="Database_Config" fetchSize="500">
        <db:sql>SELECT aggregate_id, event_type, event_data, version, created_at
                 FROM event_store
                 ORDER BY created_at ASC, version ASC</db:sql>
    </db:select>

    <set-variable variableName="processedCount" value="#[0]" />

    <foreach>
        <set-variable variableName="event" value="#[{
            aggregateId: payload.aggregate_id,
            eventType: payload.event_type,
            eventData: read(payload.event_data, 'application/json'),
            eventId: uuid(),
            timestamp: payload.created_at
        }]" />

        <!-- Reuse projection logic -->
        <flow-ref name="apply-projection-event" />

        <set-variable variableName="processedCount"
            value="#[vars.processedCount + 1]" />

        <choice>
            <when expression="#[vars.processedCount mod 1000 == 0]">
                <logger level="INFO"
                    message="Rebuild progress: #[vars.processedCount] events replayed" />
            </when>
        </choice>
    </foreach>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "REBUILD_COMPLETE",
    eventsReplayed: vars.processedCount,
    completedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### Gotchas
- **Event store is append-only, never update or delete**: Once an event is stored, it is immutable. To "undo" something, append a compensating event (e.g., OrderCancelled). If you update or delete events, you break the event log's integrity and audit trail.
- **Projection rebuild can take hours**: If your event store has 10M events, rebuilding projections by replaying all of them takes time. Use `fetchSize` to stream results (avoid loading all events into memory) and log progress.
- **Optimistic concurrency is essential**: Without version checking, two concurrent requests can append conflicting events for the same aggregate. The unique constraint on `(aggregate_id, version)` prevents this, but the client must handle 409 Conflict and retry.
- **Event schema evolution**: Once events are stored, changing their schema is problematic. If you add a field to OrderCreated events, old events do not have it. Use versioned event types (OrderCreated_v2) or ensure DataWeave replay logic handles missing fields with defaults.
- **Eventual consistency of projections**: The projection table is updated asynchronously. After appending an event, querying the projection may return stale data. Design your API to accept `If-None-Match` / version headers for consistency-aware reads.
- **Event store grows forever**: Unlike CRUD tables that stabilize in size, event stores grow monotonically. Plan for partitioning (by aggregate_type or date range) and archival of old events. PostgreSQL table partitioning works well.
- **Do not put business logic in projections**: Projections are dumb transformers -- they read events and update views. Business rules (e.g., "can this order be cancelled?") belong in the command handler that validates before appending events.

### Testing

```xml
<munit:test name="test-event-replay-reconstructs-state"
    description="Verify state is correctly reconstructed from event stream">

    <munit:behavior>
        <munit-tools:mock-when processor="db:select">
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- [
                    {event_type: "OrderCreated", event_data: "{\"orderId\":\"O-1\",\"customerId\":\"C-1\",\"totalAmount\":100}", version: 1, created_at: "2026-01-01T00:00:00Z"},
                    {event_type: "PaymentReceived", event_data: "{\"paymentId\":\"P-1\",\"amount\":100}", version: 2, created_at: "2026-01-01T00:01:00Z"},
                    {event_type: "OrderShipped", event_data: "{\"shipmentId\":\"S-1\",\"shippedAt\":\"2026-01-02\"}", version: 3, created_at: "2026-01-02T00:00:00Z"}
                ]]' />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="replay-aggregate-state" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.currentState.status]"
            is="#[MunitTools::equalTo('SHIPPED')]" />
        <munit-tools:assert-that
            expression="#[payload.version]"
            is="#[MunitTools::equalTo(3)]" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [EDA Saga Orchestration](../eda-saga-orchestration/) -- saga pattern with compensating actions
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) -- handling failed projection events
- [Kafka Exactly-Once](../kafka-exactly-once/) -- exactly-once event delivery with Kafka
