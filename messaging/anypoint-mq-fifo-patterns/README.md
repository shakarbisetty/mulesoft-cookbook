## Anypoint MQ FIFO Patterns
> Guaranteed message ordering with FIFO queues — setup, prefetch pitfalls, and exactly-once processing

### When to Use
- Messages must be processed in exact publish order (financial transactions, state machines, event sourcing)
- You need exactly-once delivery semantics within Anypoint MQ
- Regulatory requirements demand provable message ordering
- Upstream systems emit events where ordering affects correctness (e.g., CREATE before UPDATE before DELETE)

### Configuration / Code

#### Creating a FIFO Queue

**Via Anypoint CLI:**
```bash
anypoint-cli-v4 mq:queue:create \
  --region us-east-1 \
  --environment Production \
  --fifo true \
  --defaultTtl 604800000 \
  --defaultLockTtl 120000 \
  --deadLetterQueue orders-fifo-dlq \
  --maxDeliveries 3 \
  orders-fifo
```

**Via Anypoint MQ Admin API:**
```bash
curl -X PUT "https://anypoint.mulesoft.com/mq/admin/api/v1/organizations/{orgId}/environments/{envId}/regions/us-east-1/destinations/queues/orders-fifo" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "defaultTtlMillis": 604800000,
    "defaultLockTtlMillis": 120000,
    "fifo": true,
    "deadLetterSources": {
      "queueId": "orders-fifo-dlq",
      "maxDeliveries": 3
    }
  }'
```

#### FIFO Queue Subscriber — Strict Ordering

```xml
<anypoint-mq:subscriber
    config-ref="Anypoint_MQ_Config"
    destination="orders-fifo"
    doc:name="FIFO Subscriber"
    maxConcurrency="1"
    acknowledgementMode="MANUAL">
    <anypoint-mq:subscriber-config
        prefetch="1"
        acknowledgementTimeout="120000" />
</anypoint-mq:subscriber>

<flow name="orders-fifo-processor" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-fifo"
        acknowledgementMode="MANUAL" />

    <logger level="INFO"
        message="Processing order: #[attributes.messageId] — seq: #[attributes.headers.sequenceNumber]" />

    <try>
        <!-- Business logic here -->
        <db:insert config-ref="Database_Config">
            <db:sql>
                INSERT INTO order_events (order_id, event_type, payload, processed_at)
                VALUES (:orderId, :eventType, :payload, NOW())
            </db:sql>
            <db:input-parameters><![CDATA[#[{
                orderId: payload.orderId,
                eventType: payload.eventType,
                payload: write(payload, "application/json"),
            }]]]></db:input-parameters>
        </db:insert>

        <anypoint-mq:ack doc:name="ACK on success" />

        <error-handler>
            <on-error-propagate>
                <logger level="ERROR"
                    message="Failed to process #[attributes.messageId]: #[error.description]" />
                <!-- NACK triggers redelivery, preserving order -->
                <anypoint-mq:nack doc:name="NACK on failure" />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Message Grouping for Parallel FIFO

When you need ordering per entity (e.g., per customer) but parallelism across entities:

```xml
<!-- Publisher: set message group ID -->
<anypoint-mq:publish
    config-ref="Anypoint_MQ_Config"
    destination="orders-fifo">
    <anypoint-mq:message>
        <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
        <anypoint-mq:properties>
            <anypoint-mq:property key="messageGroupId" value="#[payload.customerId]" />
        </anypoint-mq:properties>
    </anypoint-mq:message>
</anypoint-mq:publish>

<!--
    Consumer: messages with the same messageGroupId are delivered in order.
    Messages with different group IDs can be processed in parallel.
    You can increase maxConcurrency when using message groups.
-->
<flow name="grouped-fifo-processor" maxConcurrency="4">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-fifo"
        acknowledgementMode="MANUAL" />

    <logger level="INFO"
        message="Group: #[attributes.properties.messageGroupId] — Message: #[attributes.messageId]" />

    <!-- Process with per-group ordering guaranteed -->
    <flow-ref name="process-order-event" />

    <anypoint-mq:ack />
</flow>
```

#### Exactly-Once Processing with Idempotency

FIFO guarantees ordering but redelivery can still happen. Use idempotency:

```xml
<os:object-store name="idempotency-store"
    persistent="true"
    entryTtl="24"
    entryTtlUnit="HOURS"
    maxEntries="100000" />

<flow name="exactly-once-fifo-processor" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-fifo"
        acknowledgementMode="MANUAL" />

    <!-- Idempotency check -->
    <os:contains
        objectStore="idempotency-store"
        key="#[attributes.messageId]"
        target="alreadyProcessed" />

    <choice>
        <when expression="#[vars.alreadyProcessed]">
            <logger level="WARN"
                message="Duplicate message #[attributes.messageId] — skipping" />
            <anypoint-mq:ack doc:name="ACK duplicate" />
        </when>
        <otherwise>
            <try>
                <flow-ref name="process-order-event" />

                <!-- Mark as processed BEFORE ack -->
                <os:store
                    objectStore="idempotency-store"
                    key="#[attributes.messageId]">
                    <os:value>#[now()]</os:value>
                </os:store>

                <anypoint-mq:ack />

                <error-handler>
                    <on-error-propagate>
                        <anypoint-mq:nack />
                    </on-error-propagate>
                </error-handler>
            </try>
        </otherwise>
    </choice>
</flow>
```

### How It Works

1. **FIFO queue creation**: FIFO queues are a distinct queue type in Anypoint MQ. They cannot be converted from standard queues — you must create them as FIFO from the start. The queue name does not need a `.fifo` suffix (unlike AWS SQS).

2. **Strict ordering**: Anypoint MQ FIFO delivers messages in exact publish order. The broker holds back subsequent messages until the current message is acknowledged or its lock expires.

3. **maxConcurrency=1 is essential**: With FIFO queues, you must set `maxConcurrency="1"` on the flow to ensure single-threaded processing. Multiple concurrent consumers will violate ordering.

4. **Prefetch=1 for true ordering**: The `prefetch` setting controls how many messages the subscriber fetches ahead. Any value > 1 means multiple messages are in the client buffer simultaneously, and processing failures can cause out-of-order redelivery.

5. **Message groups**: Message groups enable parallel processing while preserving per-group ordering. Messages with the same `messageGroupId` are delivered in order; different groups can be processed concurrently. This is the key to scaling FIFO beyond single-threaded throughput.

6. **Throughput cap**: FIFO queues support ~300 messages/second (vs ~1,000 for standard queues). This is a hard platform limit — you cannot scale past it per queue. For higher throughput, use message groups or multiple FIFO queues with application-level routing.

7. **DLQ with FIFO**: Attach a DLQ to the FIFO queue with `maxDeliveries`. After N failed deliveries, the message moves to the DLQ and the next message in the FIFO can proceed. Without a DLQ, a poison message blocks the entire queue.

### Gotchas
- **Prefetch > 1 breaks ordering**: This is the #1 mistake. Setting `prefetch="10"` for performance means 10 messages are in the client buffer. If message 3 fails and messages 4–10 succeed, redelivery of message 3 happens after 10 — ordering violated.
- **FIFO throughput is ~300 msg/sec max**: This is a platform-level cap. If you need more, use message groups (parallel within FIFO) or standard queues with application-level sequencing.
- **FIFO costs 2x standard**: Every FIFO message costs double. At high volumes, this adds up fast. Calculate whether you truly need broker-level ordering or if application-level idempotency is sufficient.
- **Lock TTL matters**: If processing takes longer than the lock TTL (default 2 min), the broker assumes the consumer died and redelivers — causing duplicates. Set `acknowledgementTimeout` to match your worst-case processing time.
- **CloudHub worker restarts**: If a CloudHub worker restarts mid-processing, the in-flight message lock eventually expires and the message is redelivered. Always implement idempotency, even with FIFO.
- **No cross-queue FIFO**: If you split messages across multiple FIFO queues, there is no ordering guarantee across queues. Only within a single queue (or message group).
- **Message group lock**: While a message in a group is being processed (locked), no other messages in that group are delivered. A slow consumer on one group does not block other groups.

### Related
- [Anypoint MQ vs Kafka — Honest Comparison](../anypoint-mq-vs-kafka-honest-comparison/) — throughput and cost context
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) — handling failed FIFO messages
- [Message Ordering Guarantees](../message-ordering-guarantees/) — ordering patterns across broker types
- [Anypoint MQ Circuit Breaker](../anypoint-mq-circuit-breaker/) — protecting downstream during FIFO processing
