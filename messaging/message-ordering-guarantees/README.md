## Message Ordering Guarantees
> Standard vs FIFO vs partitioned ordering — trade-offs across throughput, cost, and correctness

### When to Use
- You need to understand what ordering guarantee your use case actually requires
- You're choosing between standard queues, FIFO queues, and partitioned topics
- Consumers are processing messages out of order and you need to fix or accept it
- You're designing a system where event ordering affects data correctness

### Configuration / Code

#### Ordering Guarantee Comparison

| Guarantee | Anypoint MQ Standard | Anypoint MQ FIFO | Kafka (per-partition) | VM Queue |
|-----------|---------------------|-------------------|----------------------|----------|
| **Ordering** | Best-effort (no guarantee) | Strict FIFO per queue | Strict FIFO per partition | Strict FIFO per queue |
| **Throughput** | ~1,000 msg/sec | ~300 msg/sec | 100,000+ msg/sec | 50,000+ msg/sec |
| **Cost multiplier** | 1x | 2x | N/A (infra cost) | Free |
| **Parallel consumers** | Yes (unordered) | No (maxConcurrency=1) | Yes (1 per partition) | Yes (but breaks FIFO) |
| **Retry impact** | No ordering to break | NACK blocks queue | Offset commit controls | Transaction rollback |
| **Message groups** | N/A | Yes (per-group FIFO) | Partition key | N/A |
| **Cross-queue ordering** | No | No | No (cross-partition) | N/A |
| **DLQ impact on ordering** | N/A | Gap in sequence | N/A (app-level DLQ) | N/A |

#### When Ordering Matters vs When It Doesn't

**Ordering REQUIRED:**
- Financial transactions (debit before credit, or balance goes negative)
- State machine transitions (CREATE → UPDATE → DELETE)
- Event sourcing (events must replay in exact order)
- CDC (Change Data Capture) streams (last-write-wins requires correct "last")
- Inventory updates (stock count depends on operation order)

**Ordering NOT required:**
- Independent event processing (each message is self-contained)
- Notifications/alerts (email order doesn't matter)
- Log aggregation (timestamps provide ordering, not queue position)
- Fan-out patterns (each consumer processes independently)
- Idempotent operations (same result regardless of order)

#### Pattern 1: Consumer-Side Sequencing (Application-Level Ordering)

When you can't use FIFO queues (cost, throughput) but need ordering:

```xml
<!--
    Application-level ordering using sequence numbers.
    Producer assigns monotonic sequence numbers.
    Consumer reorders in a buffer before processing.
-->

<!-- Producer: assign sequence number -->
<flow name="sequenced-producer">
    <os:retrieve objectStore="sequence-store" key="global-seq" target="currentSeq">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <set-variable variableName="nextSeq" value="#[vars.currentSeq as Number + 1]" />

    <os:store objectStore="sequence-store" key="global-seq">
        <os:value>#[vars.nextSeq as String]</os:value>
    </os:store>

    <anypoint-mq:publish
        config-ref="Anypoint_MQ_Config"
        destination="events-queue">
        <anypoint-mq:message>
            <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
            <anypoint-mq:properties>
                <anypoint-mq:property key="sequenceNumber" value="#[vars.nextSeq as String]" />
                <anypoint-mq:property key="entityId" value="#[payload.entityId]" />
            </anypoint-mq:properties>
        </anypoint-mq:message>
    </anypoint-mq:publish>
</flow>

<!-- Consumer: buffer and reorder -->
<flow name="reordering-consumer">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="events-queue"
        acknowledgementMode="MANUAL" />

    <set-variable variableName="entityId" value="#[attributes.properties.entityId]" />
    <set-variable variableName="seqNum" value="#[attributes.properties.sequenceNumber as Number]" />

    <!-- Get last processed sequence for this entity -->
    <os:retrieve objectStore="sequence-tracker" key="#[vars.entityId]" target="lastProcessed">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <choice>
        <!-- Already processed (duplicate) -->
        <when expression="#[vars.seqNum &lt;= vars.lastProcessed as Number]">
            <logger level="WARN"
                message="Duplicate: entity=#[vars.entityId] seq=#[vars.seqNum] (last=#[vars.lastProcessed])" />
            <anypoint-mq:ack />
        </when>

        <!-- Next expected sequence -->
        <when expression="#[vars.seqNum == (vars.lastProcessed as Number) + 1]">
            <flow-ref name="process-event" />

            <os:store objectStore="sequence-tracker" key="#[vars.entityId]">
                <os:value>#[vars.seqNum as String]</os:value>
            </os:store>

            <anypoint-mq:ack />
        </when>

        <!-- Out of order: NACK and retry later (gap detected) -->
        <otherwise>
            <logger level="WARN"
                message="Out of order: entity=#[vars.entityId] expected=#[(vars.lastProcessed as Number) + 1] got=#[vars.seqNum]" />
            <anypoint-mq:nack />
        </otherwise>
    </choice>
</flow>
```

#### Pattern 2: Partition Key Routing (Kafka-Style in MuleSoft)

Achieve per-entity ordering without FIFO queues by routing to dedicated queues:

```xml
<!--
    Route messages to per-entity queues using a hash of the entity ID.
    Each queue has maxConcurrency=1 for ordering.
    Trade-off: more queues = more parallelism but more operational overhead.
-->
<flow name="partitioned-producer">
    <!-- Hash entity ID to a partition number (0-3) -->
    <set-variable variableName="partition"
        value="#[abs(payload.entityId as String hashCode()) mod 4]" />

    <anypoint-mq:publish
        config-ref="Anypoint_MQ_Config"
        destination="#['events-partition-' ++ vars.partition]">
        <anypoint-mq:message>
            <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
        </anypoint-mq:message>
    </anypoint-mq:publish>
</flow>

<!-- One consumer flow per partition -->
<flow name="partition-0-consumer" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="events-partition-0"
        acknowledgementMode="MANUAL" />
    <flow-ref name="process-partitioned-event" />
    <anypoint-mq:ack />
</flow>

<flow name="partition-1-consumer" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="events-partition-1"
        acknowledgementMode="MANUAL" />
    <flow-ref name="process-partitioned-event" />
    <anypoint-mq:ack />
</flow>

<!-- ... repeat for partition-2, partition-3 -->
```

#### Pattern 3: Timestamp-Based Idempotent Processing

When exact ordering is impossible but you need correct final state:

```xml
<!--
    Last-write-wins using timestamps.
    Each message carries a timestamp. Consumer only applies
    the update if the message timestamp is newer than the
    currently stored timestamp.
-->
<flow name="idempotent-timestamp-consumer">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="entity-updates"
        acknowledgementMode="MANUAL" />

    <set-variable variableName="msgTimestamp"
        value="#[payload.updatedAt as DateTime]" />

    <!-- Get current stored timestamp -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT updated_at FROM entities WHERE id = :entityId</db:sql>
        <db:input-parameters>#[{ entityId: payload.entityId }]</db:input-parameters>
    </db:select>

    <choice>
        <!-- No existing record: insert -->
        <when expression="#[isEmpty(payload)]">
            <db:insert config-ref="Database_Config">
                <db:sql>INSERT INTO entities (id, data, updated_at) VALUES (:id, :data, :ts)</db:sql>
                <db:input-parameters>#[{
                    id: vars.originalPayload.entityId,
                    data: write(vars.originalPayload, 'application/json'),
                    ts: vars.msgTimestamp
                }]</db:input-parameters>
            </db:insert>
        </when>

        <!-- Newer than stored: update -->
        <when expression="#[vars.msgTimestamp > payload[0].updated_at]">
            <db:update config-ref="Database_Config">
                <db:sql>UPDATE entities SET data = :data, updated_at = :ts WHERE id = :id AND updated_at &lt; :ts</db:sql>
                <db:input-parameters>#[{
                    id: vars.originalPayload.entityId,
                    data: write(vars.originalPayload, 'application/json'),
                    ts: vars.msgTimestamp
                }]</db:input-parameters>
            </db:update>
        </when>

        <!-- Older than stored: skip (out-of-order arrival) -->
        <otherwise>
            <logger level="INFO"
                message="Skipping stale message: entity=#[vars.originalPayload.entityId] msg_ts=#[vars.msgTimestamp] stored_ts=#[payload[0].updated_at]" />
        </otherwise>
    </choice>

    <anypoint-mq:ack />
</flow>
```

### How It Works

1. **No queue guarantees total ordering across consumers**: Even FIFO queues only guarantee ordering within a single consumer thread. The moment you add a second consumer or partition, global ordering is lost. Design for per-entity ordering, not global ordering.

2. **Standard queues are best-effort**: Anypoint MQ standard queues may deliver messages approximately in order under low load, but make no guarantee. Under high load, retries, or multiple consumers, messages arrive out of order.

3. **FIFO queues enforce strict ordering**: FIFO queues deliver messages in exact publish order. But this comes at a cost: ~300 msg/sec throughput, 2x pricing, and maxConcurrency=1 requirement. Message groups loosen this by providing per-group ordering with parallel processing across groups.

4. **Kafka partitions are the sweet spot**: Kafka provides per-partition ordering at 100K+ msg/sec. You choose the partition key (e.g., customer ID), and all messages for that key go to the same partition in order. Different keys can be processed in parallel.

5. **Consumer-side sequencing**: When broker-level ordering is too expensive or unavailable, the producer assigns sequence numbers and the consumer reorders. This adds complexity but works with any queue type.

6. **Timestamp-based last-write-wins**: For state updates (not event streams), you often don't need ordering — you need the correct final state. By comparing timestamps, the consumer can accept messages in any order and still converge on the correct state.

7. **Retry is the ordering killer**: When message 5 fails and messages 6–10 succeed, message 5 is redelivered after 10. Now 5 is out of order. With FIFO, 5 blocks 6–10 (preserving order but reducing throughput). Without FIFO, 5 arrives late (breaking order but maintaining throughput).

### Gotchas
- **Distributed consumers always break ordering**: Even with FIFO queues, if you have 2 CloudHub workers both subscribing to the same FIFO queue, the broker may deliver to either worker. Only one worker (maxConcurrency=1) preserves ordering.
- **Retry breaks sequence numbers**: If the consumer NACKs message 5 and processes 6–10, then reprocesses 5, the sequence is 1-2-3-4-6-7-8-9-10-5. Consumer-side reordering must handle this by buffering out-of-sequence messages (adds memory pressure and timeout complexity).
- **Sequence number generation is hard**: In distributed systems, generating globally unique, monotonically increasing sequence numbers requires coordination (database sequence, Redis INCR, or a dedicated service). Object Store works for single-app producers but not for multi-app scenarios.
- **FIFO + DLQ = ordering gap**: When a FIFO message goes to DLQ, the next message proceeds. The sequence now has a gap. Your consumer must handle missing sequence numbers — either wait (with timeout) or skip with a warning.
- **Timestamp skew**: If producers run on different servers with clock skew, timestamps may not reflect actual event order. Use synchronized clocks (NTP) or logical timestamps (Lamport clocks, vector clocks) for distributed producers.
- **Hash collision in partition routing**: The `hashCode() mod N` approach can create hot partitions if entity ID distribution is skewed. Monitor partition queue depths and adjust the number of partitions or hashing strategy if one partition handles disproportionate traffic.
- **Rebalancing breaks partition ordering**: If you change the number of partitions (queues), the hash function routes entities to different partitions. In-flight messages in the old partition may be processed after new messages in the new partition, breaking per-entity ordering during the transition.

### Related
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) — detailed FIFO setup and message groups
- [Anypoint MQ vs Kafka — Honest Comparison](../anypoint-mq-vs-kafka-honest-comparison/) — Kafka's partition model explained
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) — VM queue ordering behavior
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) — DLQ impact on message ordering
