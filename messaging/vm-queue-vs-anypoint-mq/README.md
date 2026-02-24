## VM Queue vs Anypoint MQ
> When to use in-app VM queues vs cross-app Anypoint MQ — a practical decision guide

### When to Use
- You need asynchronous processing within a single Mule application
- You're deciding between VM and Anypoint MQ for a new integration flow
- You need to understand the persistence, clustering, and cost trade-offs
- You're designing a system that may need to scale from single-app to multi-app later

### Configuration / Code

#### Comparison Table

| Feature | VM Queue | Anypoint MQ |
|---------|----------|-------------|
| **Scope** | Single Mule app only | Cross-app, cross-region |
| **Persistence** | Non-persistent by default; persistent option available | Always persistent (7-day default TTL) |
| **Clustering** | Shared across cluster nodes (persistent mode) | Fully distributed, cloud-native |
| **Latency** | <1ms (in-process) | ~50ms (HTTP round-trip) |
| **Throughput** | 50,000+ msg/sec (memory-bound) | ~1,000 msg/sec per queue |
| **Message size** | No limit (JVM heap-bound) | 10 MB hard limit |
| **Cost** | Free (included in runtime) | Per-message pricing ($0.001–0.002/msg) |
| **Transactions** | Supports local transactions | No transaction support |
| **Ordering** | FIFO within a single flow | Standard (unordered) or FIFO queue |
| **DLQ** | No built-in DLQ | Built-in DLQ per queue |
| **Monitoring** | JMX/custom logging only | Anypoint Monitoring dashboard |
| **Replay** | No replay (consumed = gone) | Manual requeue; 7-day retention |
| **Backpressure** | maxQueueSize blocks producer | No native backpressure |
| **Worker restart** | Non-persistent: messages lost. Persistent: recovered | Messages survive indefinitely |

#### VM Queue — In-App Async Processing

```xml
<!-- VM Queue configuration -->
<vm:config name="VM_Config">
    <vm:queues>
        <!-- Transient queue: fastest, messages lost on restart -->
        <vm:queue queueName="fast-processing" queueType="TRANSIENT" />

        <!-- Persistent queue: survives restart, slower writes -->
        <vm:queue queueName="important-events"
            queueType="PERSISTENT"
            maxOutstandingMessages="10000" />
    </vm:queues>
</vm:config>

<!-- Producer: publish to VM queue -->
<flow name="api-endpoint">
    <http:listener config-ref="HTTP_Config" path="/api/orders" method="POST" />

    <!-- Validate and respond immediately -->
    <flow-ref name="validate-order" />

    <!-- Async: publish to VM queue for background processing -->
    <vm:publish
        config-ref="VM_Config"
        queueName="important-events"
        sendCorrelationId="ALWAYS">
        <vm:content>#[payload]</vm:content>
    </vm:publish>

    <!-- Return 202 Accepted immediately -->
    <set-payload value='#[output application/json --- { status: "accepted", correlationId: correlationId }]' />
    <set-variable variableName="httpStatus" value="202" />
</flow>

<!-- Consumer: process from VM queue -->
<flow name="order-processor" maxConcurrency="4">
    <vm:listener
        config-ref="VM_Config"
        queueName="important-events"
        numberOfConsumers="4" />

    <logger level="INFO"
        message="Processing order from VM queue: #[correlationId]" />

    <flow-ref name="process-order-logic" />
</flow>
```

#### VM Queue with Transactions

```xml
<!-- VM queues support local transactions — Anypoint MQ does not -->
<flow name="transactional-vm-processing">
    <vm:listener
        config-ref="VM_Config"
        queueName="important-events"
        transactionalAction="ALWAYS_BEGIN" />

    <try transactionalAction="ALWAYS_BEGIN">
        <!-- DB insert and VM consume in same transaction -->
        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (data) VALUES (:data)</db:sql>
            <db:input-parameters>#[{ data: write(payload, 'application/json') }]</db:input-parameters>
        </db:insert>

        <!-- If DB insert fails, VM message is rolled back (not consumed) -->

        <error-handler>
            <on-error-propagate>
                <logger level="ERROR" message="Transaction rolled back: #[error.description]" />
                <!-- Message returns to VM queue automatically -->
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Anypoint MQ — Cross-App Messaging

```xml
<!-- Anypoint MQ configuration -->
<anypoint-mq:config name="Anypoint_MQ_Config">
    <anypoint-mq:connection
        url="${anypoint.mq.url}"
        clientId="${anypoint.mq.clientId}"
        clientSecret="${anypoint.mq.clientSecret}" />
</anypoint-mq:config>

<!-- Producer (App A) -->
<flow name="order-publisher">
    <http:listener config-ref="HTTP_Config" path="/api/orders" method="POST" />

    <anypoint-mq:publish
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue">
        <anypoint-mq:message>
            <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
            <anypoint-mq:properties>
                <anypoint-mq:property key="source" value="order-api" />
                <anypoint-mq:property key="correlationId" value="#[correlationId]" />
            </anypoint-mq:properties>
        </anypoint-mq:message>
    </anypoint-mq:publish>

    <set-payload value='#[output application/json --- { status: "accepted" }]' />
</flow>

<!-- Consumer (App B — separate Mule application) -->
<flow name="order-consumer">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue"
        acknowledgementMode="MANUAL" />

    <try>
        <flow-ref name="process-order" />
        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate>
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Decision Tree

```
START: Do you need async messaging?
  │
  ├─ Producer and consumer in the SAME Mule application?
  │   ├─ YES → Do you need messages to survive restarts?
  │   │         ├─ YES → VM Queue (persistent mode)
  │   │         └─ NO  → VM Queue (transient mode) — fastest option
  │   └─ NO  → Continue ↓
  │
  ├─ Producer and consumer in DIFFERENT Mule applications?
  │   └─ YES → Anypoint MQ (only option for cross-app within MuleSoft)
  │
  ├─ Need transactional processing (consume + DB in one TX)?
  │   ├─ YES → VM Queue (Anypoint MQ has no transaction support)
  │   └─ NO  → Continue ↓
  │
  ├─ Need built-in DLQ and monitoring dashboard?
  │   ├─ YES → Anypoint MQ
  │   └─ NO  → Continue ↓
  │
  ├─ Need >1000 msg/sec throughput?
  │   ├─ YES → VM Queue (50,000+ msg/sec) or Kafka
  │   └─ NO  → Either works; choose based on ops preference
  │
  └─ Cost-sensitive?
      ├─ YES → VM Queue (free)
      └─ NO  → Anypoint MQ (better observability)
```

### How It Works

1. **VM queues are in-process**: VM queues live inside the Mule runtime's JVM. Publishing and consuming is a direct memory operation — no network, no serialization, no HTTP. This gives sub-millisecond latency and zero cost.

2. **Anypoint MQ is a cloud service**: Every publish and consume operation is an HTTP call to the Anypoint MQ broker. This adds ~50ms latency and per-message cost, but enables cross-application, cross-region messaging.

3. **Persistence trade-off**: VM persistent queues write to disk (ObjectStore), adding ~5ms per message but surviving restarts. VM transient queues are pure memory — fastest possible, but all messages lost on restart. Anypoint MQ is always persistent.

4. **Transactions**: VM queues participate in Mule local transactions. You can consume a VM message and write to a database in a single transaction — if the DB write fails, the message returns to the queue. Anypoint MQ does not support transactions; you must implement idempotency instead.

5. **Scaling**: VM queues scale vertically (more JVM heap = more messages). Anypoint MQ scales horizontally (add more queues, more subscribers). For CloudHub, VM queues are limited to the worker's memory; Anypoint MQ is limited by your subscription quota.

6. **Migration path**: Start with VM queues for in-app async. If requirements evolve to cross-app, replace `vm:publish/vm:listener` with `anypoint-mq:publish/anypoint-mq:subscriber`. The flow structure is nearly identical.

### Gotchas
- **VM queues are lost on restart (non-persistent)**: This is the #1 surprise. Transient VM queues live in memory. A CloudHub worker restart, redeployment, or crash loses all queued messages. Use persistent mode for anything you cannot afford to lose.
- **VM persistent mode has limits**: Persistent VM queues use the ObjectStore, which has its own size limits. On CloudHub, the default ObjectStore is capped at 100,000 entries. Plan accordingly.
- **VM transactional scope limits**: VM transactions only work with connectors that support local transactions (Database, VM, JMS). HTTP requests are non-transactional — a successful HTTP call followed by a failed DB write cannot roll back the HTTP call.
- **No cross-app VM**: VM queues are strictly intra-application. You cannot publish from App A and consume in App B. If you think you might need cross-app messaging later, start with Anypoint MQ to avoid a migration.
- **VM maxOutstandingMessages**: Without `maxOutstandingMessages`, the VM queue grows unbounded until OutOfMemoryError. Always set a max and handle the `VM:QUEUE_IS_FULL` error on the producer side.
- **Anypoint MQ cost surprise**: At $0.001–0.002 per message, a flow processing 10M messages/day costs $10,000–20,000/month in MQ alone. For high-volume in-app async, VM queues save significant cost.
- **No VM queue monitoring**: VM queues have no built-in dashboard. You must add custom logging or JMX metrics to track queue depth. Anypoint MQ provides queue depth monitoring out of the box.

### Related
- [Anypoint MQ vs Kafka — Honest Comparison](../anypoint-mq-vs-kafka-honest-comparison/) — when both MuleSoft options aren't enough
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) — if you need ordering with Anypoint MQ
- [Anypoint MQ Circuit Breaker](../anypoint-mq-circuit-breaker/) — protection patterns for MQ consumers
- [Message Ordering Guarantees](../message-ordering-guarantees/) — ordering across all queue types
