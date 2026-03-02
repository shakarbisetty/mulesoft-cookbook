## VM vs Anypoint MQ vs JMS — Decision Matrix

> A practical decision framework comparing VM queues, Anypoint MQ, and JMS brokers across latency, throughput, persistence, cost, and operational complexity.

### When to Use
- You are designing a new integration and need to choose a messaging technology
- Stakeholders ask "why not just use VM queues?" or "why do we need Anypoint MQ?"
- You are migrating from on-prem JMS (IBM MQ, ActiveMQ) to CloudHub and need to choose a replacement
- You need to justify the cost of Anypoint MQ licensing vs self-managed JMS

### The Problem
MuleSoft supports three fundamentally different messaging approaches, and choosing the wrong one causes either unnecessary cost (paying for Anypoint MQ when VM queues suffice) or reliability gaps (using VM queues when you need cross-app durability). Most teams default to whatever they used on the last project. This recipe provides a structured decision matrix with real numbers.

### Decision Matrix

```
                    │  VM Queue           │  Anypoint MQ          │  JMS (IBM MQ/ActiveMQ)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Scope               │ Single app only     │ Cross-app, cross-env  │ Cross-system, on-prem
                    │ Same Mule runtime   │ Cloud-native          │ + cloud
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Persistence         │ In-memory (default) │ Always persistent     │ Configurable
                    │ Persistent optional │ Replicated across AZs │ (persistent/non)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Latency             │ < 1ms (in-process)  │ 5-50ms (network hop)  │ 2-20ms (varies by
                    │                     │                       │ network topology)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Throughput          │ 10,000+ msg/sec     │ ~1000 msg/sec/queue   │ 5,000-50,000 msg/sec
                    │ (limited by CPU)    │ (MuleSoft-managed)    │ (broker-dependent)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Message Size Limit  │ JVM heap limit      │ 10 MB                 │ Broker-configured
                    │                     │                       │ (IBM MQ: 100 MB)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Ordering            │ FIFO (single queue) │ Standard: best-effort │ FIFO per queue
                    │                     │ FIFO: strict ordering │
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Dead Letter Queue   │ None (build your    │ Built-in DLQ with     │ Built-in (backout queue
                    │ own error handling) │ maxDeliveries config  │ for IBM MQ)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
HA / Durability     │ Lost on app restart │ Multi-AZ replicated   │ Cluster/HA pair
                    │ (unless persistent) │ 99.99% SLA            │ (self-managed)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Transactions (XA)   │ No                  │ No                    │ Yes (2PC with DB)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Cost                │ Free (included)     │ Per-API-call billing  │ License + infra
                    │                     │ ($$$)                 │ ($$-$$$$)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Ops Overhead        │ None                │ Low (MuleSoft-managed)│ High (self-managed)
────────────────────┼─────────────────────┼───────────────────────┼─────────────────────────
Best For            │ Flow decoupling,    │ Cross-app events,     │ Enterprise integration,
                    │ async within app,   │ CloudHub native,      │ XA transactions,
                    │ throttling          │ no infra to manage    │ high throughput
```

### Configuration

#### When to Use VM Queues

```xml
<!--
    USE VM WHEN:
    - Communication between flows in the SAME application
    - Fire-and-forget async processing (e.g., audit logging)
    - Throttling / buffering within a single app
    - You don't need messages to survive app restarts

    DO NOT USE VM WHEN:
    - Different apps need to communicate
    - Messages must survive crashes / restarts
    - You need a DLQ for failed messages
-->
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="async-audit" queueType="TRANSIENT" maxOutstandingMessages="1000" />
        <vm:queue queueName="buffered-writes" queueType="PERSISTENT" maxOutstandingMessages="500" />
    </vm:queues>
</vm:config>

<!-- Fire-and-forget audit logging -->
<flow name="api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST" />

    <!-- Process the order synchronously -->
    <flow-ref name="process-order" />

    <!-- Async audit via VM (fire-and-forget) -->
    <vm:publish config-ref="VM_Config" queueName="async-audit">
        <vm:content><![CDATA[#[output application/json --- {
            action: "ORDER_CREATED",
            orderId: payload.orderId,
            timestamp: now(),
            userId: attributes.headers.userId
        }]]]></vm:content>
    </vm:publish>
</flow>

<flow name="audit-writer" maxConcurrency="2">
    <vm:listener config-ref="VM_Config" queueName="async-audit" />
    <db:insert config-ref="DB_Config">
        <db:sql>INSERT INTO audit_log (action, data, created_at)
                 VALUES (:action, :data, :created_at)</db:sql>
        <db:input-parameters><![CDATA[#[{
            action: payload.action,
            data: write(payload, "application/json"),
            created_at: now()
        }]]]></db:input-parameters>
    </db:insert>
</flow>
```

#### When to Use Anypoint MQ

```xml
<!--
    USE ANYPOINT MQ WHEN:
    - Cross-app communication (App A publishes, App B consumes)
    - Running on CloudHub and want MuleSoft-managed infrastructure
    - Need DLQ, message TTL, and redelivery out of the box
    - Need FIFO ordering across applications

    DO NOT USE ANYPOINT MQ WHEN:
    - Same-app flow decoupling (VM is simpler and free)
    - Need > 10 MB messages (use claim-check pattern)
    - Need XA transactions (use JMS)
    - Cost-sensitive high-volume scenarios (API-call billing adds up)
-->
<anypoint-mq:config name="AMQ_Config">
    <anypoint-mq:connection
        clientId="${amq.client.id}"
        clientSecret="${amq.client.secret}"
        url="${amq.broker.url}" />
</anypoint-mq:config>

<!-- Cross-app event publishing -->
<flow name="order-service-publisher">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST" />

    <flow-ref name="create-order" />

    <!-- Publish event for other apps to consume -->
    <anypoint-mq:publish config-ref="AMQ_Config" destination="order-events">
        <anypoint-mq:message>
            <anypoint-mq:body>#[output application/json --- {
                eventType: "ORDER_CREATED",
                orderId: payload.orderId,
                timestamp: now()
            }]</anypoint-mq:body>
        </anypoint-mq:message>
    </anypoint-mq:publish>
</flow>
```

#### When to Use JMS

```xml
<!--
    USE JMS WHEN:
    - Integrating with existing enterprise message brokers (IBM MQ, ActiveMQ, TIBCO)
    - Need XA transactions (atomic JMS + DB)
    - Need pub/sub with durable subscriptions
    - High throughput requirements (10,000+ msg/sec)
    - On-prem or hybrid deployment

    DO NOT USE JMS WHEN:
    - Pure CloudHub deployment (Anypoint MQ is simpler)
    - You don't have an existing JMS broker
    - You want zero operational overhead
-->
<jms:config name="JMS_Config">
    <jms:active-mq-connection>
        <jms:factory-configuration
            brokerUrl="tcp://${activemq.host}:${activemq.port}" />
    </jms:active-mq-connection>
</jms:config>

<!-- XA transaction: JMS + DB atomic -->
<flow name="jms-xa-processor">
    <jms:listener config-ref="JMS_Config"
        destination="orders"
        transactionalAction="ALWAYS_BEGIN"
        transactionType="XA" />

    <db:insert config-ref="DB_XA_Config"
        transactionalAction="ALWAYS_JOIN">
        <db:sql>INSERT INTO orders (order_id, data) VALUES (:id, :data)</db:sql>
        <db:input-parameters>#[{id: payload.orderId, data: payload}]</db:input-parameters>
    </db:insert>
</flow>
```

### Decision Flowchart

```
Start
  │
  ├── Same app, same runtime?
  │     ├── Yes → VM Queue
  │     │     ├── Need persistence? → VM PERSISTENT queue type
  │     │     └── Fire-and-forget? → VM TRANSIENT queue type
  │     │
  │     └── No (different apps) ↓
  │
  ├── On CloudHub, no existing broker?
  │     ├── Yes → Anypoint MQ
  │     │     ├── Need ordering? → FIFO queue
  │     │     └── Need DLQ? → Configure maxDeliveries
  │     │
  │     └── No (existing broker or on-prem) ↓
  │
  ├── Need XA transactions?
  │     ├── Yes → JMS (IBM MQ or ActiveMQ)
  │     └── No ↓
  │
  ├── Need > 5000 msg/sec?
  │     ├── Yes → JMS or Kafka
  │     └── No → Anypoint MQ or JMS (based on existing infra)
  │
  └── Cost-sensitive?
        ├── Yes → JMS (self-hosted) or VM (if same-app)
        └── No → Anypoint MQ (managed, lowest ops overhead)
```

### Cost Comparison (Approximate)

```
Volume: 1 million messages/month, average 5 KB each

VM Queue:
  License cost: $0 (included in Mule runtime)
  Infra cost:   $0 (runs in same app)
  Total:        $0/month

Anypoint MQ:
  API calls:    ~2M (publish + consume + ack)
  Estimated:    $200-500/month (varies by plan)
  Infra:        $0 (MuleSoft-managed)
  Total:        $200-500/month

IBM MQ on EC2:
  License:      $500-2000/month (per PVU)
  EC2 instance: $150-300/month (m5.xlarge HA pair)
  Ops labor:    $500-1000/month (patching, monitoring)
  Total:        $1150-3300/month

ActiveMQ on EC2:
  License:      $0 (open source)
  EC2 instance: $150-300/month (HA pair)
  Ops labor:    $300-600/month
  Total:        $450-900/month

Amazon MQ (managed ActiveMQ):
  Broker:       $100-400/month
  Storage:      $50-100/month
  Total:        $150-500/month
```

### Gotchas
- **VM queues are lost on restart (TRANSIENT)**: This is the #1 mistake. Developers test with VM queues, everything works, then messages vanish after a CloudHub restart. Use `queueType="PERSISTENT"` or switch to Anypoint MQ for critical messages.
- **Anypoint MQ cost scales with volume**: Each publish, consume, and acknowledge is a separate API call. A single message = 3 API calls minimum. At 10M messages/month, costs can exceed $2000/month. Monitor API call counts via the Anypoint Platform usage dashboard.
- **VM publish-consume is not the same as flow-ref**: `vm:publish` + `vm:listener` crosses a queue boundary with potential message loss on crash. `flow-ref` is synchronous and transactional. Do not replace `flow-ref` with VM "for decoupling" unless you need async behavior.
- **JMS requires broker management**: Patching, monitoring, capacity planning, failover testing, backup/restore. If your team does not have JMS broker expertise, the operational overhead will exceed the Anypoint MQ licensing cost.
- **Mixing VM and Anypoint MQ in the same flow**: A common anti-pattern is publishing to a VM queue, then consuming from it and publishing to Anypoint MQ. This adds latency and a failure point with no benefit. Publish directly to Anypoint MQ from the source flow.
- **FIFO throughput trap**: Anypoint MQ FIFO queues max out at ~300 msg/sec. If you choose Anypoint MQ for ordering, you may hit throughput limits. IBM MQ FIFO handles 10,000+ msg/sec per queue.
- **Anypoint MQ is not available in all regions**: Check MuleSoft documentation for supported regions. If your compliance requires data residency in a specific country, Anypoint MQ may not be available there. JMS with a local broker is the alternative.

### Testing

```xml
<munit:test name="test-vm-queue-async-processing"
    description="Verify VM queue decouples flows">

    <munit:behavior>
        <munit-tools:mock-when processor="db:insert">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{affectedRows: 1}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <vm:publish config-ref="VM_Config" queueName="async-audit">
            <vm:content><![CDATA[#[output application/json --- {
                action: "TEST_EVENT",
                timestamp: now()
            }]]]></vm:content>
        </vm:publish>

        <!-- Allow async processing time -->
        <munit-tools:sleep time="2000" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="db:insert" times="1" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) -- deep dive on VM vs AMQ
- [Anypoint MQ vs Kafka — Honest Comparison](../anypoint-mq-vs-kafka-honest-comparison/) -- when Kafka is a better fit
- [JMS XA Transaction Patterns](../jms-xa-transaction-patterns/) -- why JMS is needed for XA
- [JMS IBM MQ Production](../jms-ibm-mq-production/) -- production IBM MQ setup
- [AMQ Subscriber Scaling](../amq-subscriber-scaling/) -- tuning AMQ throughput
