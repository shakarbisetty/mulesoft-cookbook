## Event-Driven Architecture with MuleSoft
> Anypoint MQ, VM queues, and CDC for asynchronous, decoupled integration

### When to Use
- You need to decouple producers from consumers so they can scale and deploy independently
- Request-reply latency is unacceptable for downstream processing (e.g., order placed triggers 5 downstream systems)
- You need guaranteed delivery even when a consumer is temporarily down
- Data changes in a system of record must propagate to multiple subscribers
- You are building a CQRS or event-sourcing architecture on MuleSoft

### Configuration / Code

#### Decision Tree: Events vs Request-Reply

```
START: Integration requirement
  │
  ├─ Does the caller need an immediate response with data?
  │    YES ──► Request-Reply (HTTP/HTTPS)
  │    NO  ──┐
  │          │
  │    ├─ Must the action complete before the caller proceeds?
  │    │    YES ──► Synchronous (request-reply or sync VM queue)
  │    │    NO  ──┐
  │    │          │
  │    │    ├─ Are there multiple consumers for the same event?
  │    │    │    YES ──► Publish-Subscribe (Anypoint MQ with multiple subscribers)
  │    │    │    NO  ──► Point-to-Point Queue (Anypoint MQ or VM queue)
  │    │    │
  │    │    └─ Is the event scope within a single Mule app?
  │    │         YES ──► VM Queue (in-memory, no external broker)
  │    │         NO  ──► Anypoint MQ (cross-app, durable)
  │    │
  │    └─ Do you need event replay / audit trail?
  │         YES ──► Event Sourcing pattern (see below)
  │         NO  ──► Standard event queue
  │
  └─ Is this a data sync triggered by database changes?
       YES ──► CDC (Change Data Capture) — see CDC section below
       NO  ──► Application-level events
```

#### Pattern 1: Publish-Subscribe with Anypoint MQ

```xml
<!-- PUBLISHER: order-api publishes order events -->
<flow name="publish-order-created">
    <http:listener path="/orders" method="POST" config-ref="httpConfig"/>

    <!-- Process the order synchronously -->
    <db:insert config-ref="orderDb">
        <db:sql>INSERT INTO orders (id, customer_id, total) VALUES (:id, :customerId, :total)</db:sql>
        <db:input-parameters><![CDATA[#[{
            id: payload.orderId,
            customerId: payload.customerId,
            total: payload.total
        }]]]></db:input-parameters>
    </db:insert>

    <!-- Publish event asynchronously — fire and forget -->
    <async>
        <anypoint-mq:publish
            config-ref="anypointMqConfig"
            destination="order-events-exchange"
            messageId="#[payload.orderId]">
            <anypoint-mq:body><![CDATA[#[output application/json --- {
                eventType: "ORDER_CREATED",
                orderId: payload.orderId,
                customerId: payload.customerId,
                total: payload.total,
                timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
            }]]]></anypoint-mq:body>
            <anypoint-mq:properties>
                <anypoint-mq:property key="eventType" value="ORDER_CREATED"/>
            </anypoint-mq:properties>
        </anypoint-mq:publish>
    </async>

    <!-- Return 202 Accepted immediately -->
    <set-payload value='#[output application/json --- {status: "accepted", orderId: payload.orderId}]'/>
    <set-variable variableName="httpStatus" value="202"/>
</flow>
```

```xml
<!-- SUBSCRIBER 1: inventory-service consumes order events -->
<flow name="inventory-subscriber">
    <anypoint-mq:subscriber
        config-ref="anypointMqConfig"
        destination="order-events-inventory"
        acknowledgementMode="MANUAL"
        acknowledgementTimeout="60000">
    </anypoint-mq:subscriber>

    <logger message="Processing inventory update for order: #[payload.orderId]" level="INFO"/>

    <try>
        <!-- Reserve inventory -->
        <db:update config-ref="inventoryDb">
            <db:sql>UPDATE inventory SET reserved = reserved + 1 WHERE product_id = :productId</db:sql>
        </db:update>

        <!-- ACK on success -->
        <anypoint-mq:ack config-ref="anypointMqConfig"/>

    <error-handler>
        <on-error-continue type="ANY">
            <!-- NACK — message returns to queue for retry -->
            <anypoint-mq:nack config-ref="anypointMqConfig"/>
            <logger message="Failed to process order event: #[error.description]" level="ERROR"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

```xml
<!-- SUBSCRIBER 2: notification-service consumes same events -->
<flow name="notification-subscriber">
    <anypoint-mq:subscriber
        config-ref="anypointMqConfig"
        destination="order-events-notifications"
        acknowledgementMode="AUTO">
    </anypoint-mq:subscriber>

    <http:request method="POST" url="https://email-api.internal/send"
        config-ref="emailHttpConfig">
        <http:body><![CDATA[#[output application/json --- {
            to: payload.customerId,
            template: "order-confirmation",
            data: payload
        }]]]></http:body>
    </http:request>
</flow>
```

**Anypoint MQ topology for pub-sub:**
```
                      ┌─────────────────────────┐
                      │  order-events-exchange   │  (Exchange/Topic)
  order-api ─────────►│                           │
                      └──────────┬──┬────────────┘
                                 │  │
                    ┌────────────┘  └────────────┐
                    ▼                             ▼
        ┌───────────────────┐         ┌───────────────────┐
        │ order-events-     │         │ order-events-     │
        │ inventory (Queue) │         │ notifications     │
        └────────┬──────────┘         │ (Queue)           │
                 │                    └────────┬──────────┘
                 ▼                             ▼
        inventory-service             notification-service
```

#### Pattern 2: In-App Events with VM Queues

```xml
<!-- VM Queue for intra-application async processing -->
<vm:config name="vmConfig">
    <vm:queues>
        <vm:queue queueName="audit-events" queueType="TRANSIENT" maxOutstandingMessages="1000"/>
        <vm:queue queueName="heavy-processing" queueType="PERSISTENT"/>
    </vm:queues>
</vm:config>

<!-- Producer flow: publish to VM queue -->
<flow name="api-handler">
    <http:listener path="/process" method="POST" config-ref="httpConfig"/>

    <!-- Fast path: respond immediately -->
    <set-variable variableName="requestPayload" value="#[payload]"/>

    <!-- Fire and forget to VM queue -->
    <vm:publish config-ref="vmConfig" queueName="heavy-processing">
        <vm:content>#[vars.requestPayload]</vm:content>
    </vm:publish>

    <set-payload value='#[output application/json --- {status: "queued"}]'/>
</flow>

<!-- Consumer flow: process from VM queue -->
<flow name="heavy-processor">
    <vm:listener config-ref="vmConfig" queueName="heavy-processing"/>

    <!-- Slow processing happens here without blocking the API -->
    <http:request method="POST" url="https://slow-backend.example.com/process"
        config-ref="slowBackendConfig"/>

    <logger message="Completed heavy processing for: #[payload.id]" level="INFO"/>
</flow>
```

**When VM queue vs Anypoint MQ:**

| Criteria | VM Queue | Anypoint MQ |
|----------|----------|-------------|
| Scope | Within a single Mule app | Cross-application |
| Durability | Transient or persistent (file-backed) | Always durable (cloud-managed) |
| Failover | Lost if worker restarts (transient) | Survives any single failure |
| Cost | Free (included in runtime) | Per-message pricing |
| Pub-Sub | No (point-to-point only) | Yes (exchanges + queues) |
| Dead-letter queue | Manual implementation | Built-in DLQ support |
| Use case | Intra-app async, buffering | Cross-app events, guaranteed delivery |

#### Pattern 3: Change Data Capture (CDC)

```xml
<!-- Polling-based CDC using watermark -->
<flow name="cdc-customer-changes">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS"/>
        </scheduling-strategy>
    </scheduler>

    <!-- Read watermark from Object Store -->
    <os:retrieve key="customer-cdc-watermark" objectStore="cdcWatermarkStore"
        target="lastTimestamp">
        <os:default-value>2020-01-01T00:00:00Z</os:default-value>
    </os:retrieve>

    <!-- Query for changes since last watermark -->
    <db:select config-ref="sourceDb">
        <db:sql>
            SELECT id, name, email, updated_at
            FROM customers
            WHERE updated_at > :lastTimestamp
            ORDER BY updated_at ASC
            LIMIT 500
        </db:sql>
        <db:input-parameters>#[{lastTimestamp: vars.lastTimestamp}]</db:input-parameters>
    </db:select>

    <choice>
        <when expression="#[sizeOf(payload) > 0]">
            <!-- Publish each change as an event -->
            <foreach>
                <anypoint-mq:publish config-ref="anypointMqConfig"
                    destination="customer-change-events">
                    <anypoint-mq:body><![CDATA[#[output application/json --- {
                        eventType: "CUSTOMER_UPDATED",
                        entityId: payload.id,
                        data: payload,
                        capturedAt: now() as String
                    }]]]></anypoint-mq:body>
                </anypoint-mq:publish>
            </foreach>

            <!-- Update watermark to last processed record -->
            <os:store key="customer-cdc-watermark" objectStore="cdcWatermarkStore">
                <os:value>#[payload[-1].updated_at as String]</os:value>
            </os:store>
        </when>
    </choice>
</flow>
```

#### Event Envelope Standard

Every event should follow a consistent envelope:

```json
{
  "eventId": "evt-uuid-here",
  "eventType": "ORDER_CREATED",
  "source": "order-process-api",
  "timestamp": "2026-02-24T10:30:00Z",
  "correlationId": "corr-uuid-from-request",
  "data": {
    "orderId": "ORD-12345",
    "customerId": "CUST-678",
    "total": 149.99
  },
  "metadata": {
    "version": "1.0",
    "environment": "production"
  }
}
```

### How It Works
1. **Producer** performs its primary operation (e.g., writes to database) and then publishes an event to Anypoint MQ or a VM queue
2. **Event broker** (Anypoint MQ exchange) fans out the event to all subscribed queues
3. **Consumers** independently read from their dedicated queue, process the event, and acknowledge
4. **Failed messages** are retried (NACK) or routed to a dead-letter queue after max retries
5. **Watermark-based CDC** polls for changes at intervals, publishing each change as an event, advancing the watermark on success

### Gotchas
- **Eventual consistency is the default.** Subscribers process events asynchronously. If a consumer reads data before the event is processed by another consumer, it sees stale state. Design your consumers to be tolerant of this
- **Message ordering is not guaranteed** in Anypoint MQ across multiple consumers. If order matters, use a single consumer with FIFO queue, or include a sequence number in the event and reorder on the consumer side
- **Duplicate handling is your responsibility.** Anypoint MQ provides at-least-once delivery. Every consumer must be idempotent — use the `eventId` or `messageId` to deduplicate. A simple `INSERT ... ON CONFLICT DO NOTHING` pattern works for database consumers
- **Dead-letter queues need monitoring.** A DLQ that nobody watches is a data graveyard. Set up alerts when DLQ depth exceeds zero
- **VM queues with TRANSIENT type lose messages on restart.** Use PERSISTENT type if you cannot afford to lose events, but know that persistent VM queues use disk I/O and are slower
- **CDC polling interval is a trade-off.** Too frequent (1s) wastes database connections; too infrequent (5min) increases data propagation delay. 15-60 seconds is typical
- **Large event payloads kill throughput.** Keep events small (< 10KB). Use the "event notification" pattern — include entity ID and type, let the consumer fetch full data if needed

### Related
- [Multi-Region DR Strategy](../multi-region-dr-strategy/) — Anypoint MQ cross-region replication for event-driven failover
- [Domain-Driven API Design](../domain-driven-api-design/) — Domain events map naturally to bounded context boundaries
- [Microservices vs API-Led](../microservices-vs-api-led/) — Event-driven is often the communication backbone for microservices
