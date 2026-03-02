## Kafka Rebalance Handling in MuleSoft

> Graceful consumer group rebalancing with cooperative sticky assignment and offset commit strategies to prevent duplicate processing.

### When to Use
- Your Kafka consumer group experiences frequent rebalances causing processing stalls
- You see duplicate messages after consumer restarts, deployments, or scaling events
- You need to minimize the "stop-the-world" rebalance window
- Your consumer holds local state (caches, accumulators) that is lost during rebalance

### The Problem
Every time a Kafka consumer joins or leaves a consumer group, all consumers stop processing while partitions are reassigned. With the default eager rebalance strategy, every consumer gives up every partition and gets new assignments. This causes: (1) a processing gap equal to the rebalance duration, (2) duplicate messages if offsets were not committed before the rebalance, (3) loss of local state tied to specific partitions. In MuleSoft, you cannot register a `ConsumerRebalanceListener` directly, so you must configure the connector properties and design flows to be resilient to rebalance events.

### Configuration

#### Consumer Config with Cooperative Sticky Assignor

```xml
<!--
    Cooperative sticky assignor: only partitions that change ownership
    are revoked. Other consumers keep processing during rebalance.
    Requires Kafka broker 2.4+.
-->
<kafka:consumer-config name="Kafka_Consumer_Sticky"
    doc:name="Kafka Consumer (Cooperative Sticky)">
    <kafka:consumer-connection
        bootstrapServers="${kafka.bootstrap.servers}">
        <kafka:consumer-properties>
            <!-- Cooperative sticky: incremental rebalance, no stop-the-world -->
            <kafka:consumer-property key="partition.assignment.strategy"
                value="org.apache.kafka.clients.consumer.CooperativeStickyAssignor" />

            <!-- Session timeout: how long before broker declares consumer dead -->
            <kafka:consumer-property key="session.timeout.ms" value="30000" />

            <!-- Heartbeat interval: must be < session.timeout / 3 -->
            <kafka:consumer-property key="heartbeat.interval.ms" value="10000" />

            <!-- Max poll interval: max time between poll() calls before rebalance -->
            <kafka:consumer-property key="max.poll.interval.ms" value="300000" />

            <!-- Max records per poll: keep low to avoid exceeding max.poll.interval -->
            <kafka:consumer-property key="max.poll.records" value="50" />

            <!-- Auto offset reset: what to do when no committed offset exists -->
            <kafka:consumer-property key="auto.offset.reset" value="earliest" />
        </kafka:consumer-properties>
    </kafka:consumer-connection>
</kafka:consumer-config>
```

#### Consumer Flow with Rebalance-Safe Offset Commit

```xml
<!--
    Key design: commit offsets frequently to minimize the duplicate window.
    If a rebalance happens, only uncommitted messages are reprocessed.
-->
<flow name="kafka-rebalance-safe-consumer" maxConcurrency="4">
    <kafka:consumer
        config-ref="Kafka_Consumer_Sticky"
        topic="events"
        groupId="event-processor"
        offsetCommit="MANUAL">
    </kafka:consumer>

    <!-- Store partition+offset for observability -->
    <set-variable variableName="partitionInfo"
        value="#['P' ++ (attributes.partition as String) ++ ':O' ++ (attributes.offset as String)]" />

    <logger level="DEBUG"
        message="Processing #[vars.partitionInfo] from topic #[attributes.topic]" />

    <try>
        <!-- Process the message -->
        <flow-ref name="process-event" />

        <!-- Commit offset immediately after successful processing.
             This minimizes the duplicate window during rebalance. -->
        <kafka:commit config-ref="Kafka_Consumer_Sticky" />

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                    message="Failed #[vars.partitionInfo]: #[error.description]" />
                <!-- Do NOT commit — message will be reprocessed after rebalance or next poll -->
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### Handling Long Processing with Heartbeat Keep-Alive

```xml
<!--
    Problem: if processing takes > max.poll.interval.ms (default 5 min),
    the broker assumes the consumer is dead and triggers a rebalance.

    Solution: for long-running processing, break work into chunks
    and commit intermediate progress.
-->
<flow name="kafka-long-processing-consumer" maxConcurrency="1">
    <kafka:consumer
        config-ref="Kafka_Consumer_Sticky"
        topic="batch-jobs"
        groupId="batch-processor"
        offsetCommit="MANUAL">
        <kafka:consumer-config maxPollRecords="1" />
    </kafka:consumer>

    <!-- Extract batch items from the message -->
    <set-variable variableName="items" value="#[payload.items]" />
    <set-variable variableName="batchId" value="#[payload.batchId]" />

    <!-- Process in chunks to stay within max.poll.interval -->
    <foreach collection="#[vars.items splitAt 100]" counterVariableName="chunk">
        <logger level="INFO"
            message="Batch #[vars.batchId] chunk #[vars.chunk] / #[sizeOf(vars.items) / 100]" />

        <foreach collection="#[payload]">
            <flow-ref name="process-single-item" />
        </foreach>

        <!-- Store checkpoint after each chunk (resume on crash) -->
        <os:store objectStore="checkpoint-store" key="#[vars.batchId]">
            <os:value>#[vars.chunk as String]</os:value>
        </os:store>
    </foreach>

    <!-- All chunks done — commit offset -->
    <kafka:commit config-ref="Kafka_Consumer_Sticky" />
</flow>
```

### Rebalance Strategy Comparison

```
Strategy                    | Rebalance Behavior          | Duplicate Risk   | MuleSoft Support
────────────────────────────┼─────────────────────────────┼──────────────────┼──────────────────
RangeAssignor (default)     | Full stop-the-world         | HIGH — all       | Yes (default)
                            | All partitions revoked      | uncommitted msgs |
────────────────────────────┼─────────────────────────────┼──────────────────┼──────────────────
RoundRobinAssignor          | Full stop-the-world         | HIGH             | Yes
                            | Even distribution           |                  |
────────────────────────────┼─────────────────────────────┼──────────────────┼──────────────────
StickyAssignor              | Full stop-the-world         | MEDIUM           | Yes
                            | Minimizes partition moves   |                  |
────────────────────────────┼─────────────────────────────┼──────────────────┼──────────────────
CooperativeStickyAssignor   | Incremental (no stop)       | LOW — only       | Yes (recommended)
                            | Only moved partitions pause | moved partitions |
```

### Gotchas
- **max.poll.interval.ms is the rebalance trigger**: If your flow takes longer than `max.poll.interval.ms` to process a single poll batch, the broker triggers a rebalance. This is the #1 cause of unexpected rebalances in MuleSoft Kafka consumers. Set it to at least 2x your worst-case processing time.
- **maxConcurrency and max.poll.records interact**: With `maxConcurrency=4` and `max.poll.records=100`, the connector polls 100 messages and distributes them across 4 threads. Each thread processes 25 messages. The max.poll.interval clock starts from the poll, not per-thread. All 4 threads must finish before the next poll.
- **Cooperative sticky requires all consumers to agree**: If one consumer in the group uses `RangeAssignor` and another uses `CooperativeStickyAssignor`, the group falls back to eager rebalance. Coordinate assignment strategy across all consumers in the group.
- **Static group membership reduces rebalances**: Set `group.instance.id` to a stable identifier (e.g., pod name) to enable static membership. When a consumer restarts with the same ID, it gets its old partitions back without triggering a full rebalance. TTL is controlled by `session.timeout.ms`.
- **CloudHub 2.0 rolling deployments**: During a rolling deployment, old and new replicas coexist briefly. Each version change triggers a rebalance. With 4 replicas, you get 4 rebalances in sequence. Use cooperative sticky to minimize impact.
- **Offset commit frequency vs throughput**: Committing after every message (shown above) is safest but adds latency. For high-throughput scenarios, commit every N messages or every T seconds. Accept that up to N messages or T seconds of work may be duplicated on rebalance.
- **heartbeat.interval.ms must be < session.timeout.ms / 3**: The Kafka protocol requires at least 3 heartbeats per session timeout. If heartbeat is too close to session timeout, transient network blips cause unnecessary rebalances.

### Testing

```xml
<munit:test name="test-rebalance-safe-offset-commit"
    description="Verify offset is committed only after successful processing">

    <munit:behavior>
        <munit-tools:mock-when processor="flow-ref">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="name" whereValue="process-event" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#['processed']" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {eventId: "E-001", data: "test"}]' />
        <set-variable variableName="attributes"
            value="#[{topic: 'events', partition: 0, offset: 42}]" />
        <flow-ref name="kafka-rebalance-safe-consumer" />
    </munit:execution>

    <munit:validation>
        <!-- Verify kafka:commit was called exactly once -->
        <munit-tools:verify-call processor="kafka:commit" times="1" />
    </munit:validation>
</munit:test>

<munit:test name="test-failed-processing-no-commit"
    description="Verify offset is NOT committed when processing fails">

    <munit:behavior>
        <munit-tools:mock-when processor="flow-ref">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="name" whereValue="process-event" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:error typeId="APP:PROCESSING_ERROR" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {eventId: "E-002", data: "bad"}]' />
        <flow-ref name="kafka-rebalance-safe-consumer" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="kafka:commit" times="0" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [Kafka Exactly-Once](../kafka-exactly-once/) -- deduplication layer on top of rebalance-safe commits
- [Kafka Dead Letter Topic](../kafka-dead-letter-topic/) -- route failed messages instead of blocking the consumer
- [Kafka Schema Registry Evolution](../kafka-schema-registry-evolution/) -- schema mismatches during rolling deployments
- [Message Ordering Guarantees](../message-ordering-guarantees/) -- partition reassignment impact on ordering
