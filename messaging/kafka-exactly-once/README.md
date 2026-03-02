## Kafka Exactly-Once Semantics in MuleSoft

> Achieve exactly-once message processing with Kafka idempotent producers, transactional consumers, and Object Store deduplication.

### When to Use
- You are processing financial transactions or inventory updates where duplicates cause real business damage
- Your Kafka consumer can be restarted or rebalanced mid-processing, causing offset commit gaps
- You need end-to-end exactly-once from Kafka topic to database or downstream API
- At-least-once with manual dedup is not reliable enough for your SLA

### The Problem
Kafka guarantees at-least-once delivery by default. If a consumer processes a message but crashes before committing the offset, the message is redelivered after rebalance. The downstream system sees it twice. MuleSoft's Kafka connector does not expose Kafka's transactional API directly, so you must implement exactly-once semantics at the application level using idempotent writes and Object Store-based deduplication.

### Configuration

#### Idempotent Kafka Producer

```xml
<!--
    Kafka producer with idempotence enabled.
    Prevents duplicate publishes when the producer retries after a network error.
    Requires: acks=all, retries > 0, max.in.flight.requests.per.connection <= 5
-->
<kafka:producer-config name="Kafka_Idempotent_Producer"
    doc:name="Kafka Idempotent Producer">
    <kafka:producer-connection
        bootstrapServers="${kafka.bootstrap.servers}">
        <kafka:producer-properties>
            <kafka:producer-property key="enable.idempotence" value="true" />
            <kafka:producer-property key="acks" value="all" />
            <kafka:producer-property key="retries" value="5" />
            <kafka:producer-property key="max.in.flight.requests.per.connection" value="5" />
            <kafka:producer-property key="delivery.timeout.ms" value="120000" />
        </kafka:producer-properties>
    </kafka:producer-connection>
</kafka:producer-config>

<!-- Publish with idempotent guarantees -->
<flow name="publish-order-event">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST" />

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.orderId,
    amount: payload.amount,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <kafka:publish config-ref="Kafka_Idempotent_Producer"
        topic="orders"
        key="#[payload.orderId]">
        <kafka:message>
            <kafka:body>#[payload]</kafka:body>
            <kafka:headers><![CDATA[#[{
                "correlation-id": correlationId,
                "source": "order-api"
            }]]]></kafka:headers>
        </kafka:message>
    </kafka:publish>
</flow>
```

#### Consumer with Object Store Deduplication

```xml
<!--
    Object Store for tracking processed message keys.
    TTL = 7 days (must exceed your max reprocessing window).
-->
<os:object-store name="kafka-dedup-store"
    persistent="true"
    entryTtl="7"
    entryTtlUnit="DAYS"
    maxEntries="1000000" />

<!--
    Consumer flow with manual offset commit and dedup.
    Key insight: commit offset AFTER successful processing + dedup store write.
-->
<flow name="kafka-exactly-once-consumer" maxConcurrency="1">
    <kafka:consumer
        config-ref="Kafka_Consumer_Config"
        topic="orders"
        groupId="order-processor"
        offsetCommit="MANUAL">
        <kafka:consumer-config
            autoOffsetReset="EARLIEST"
            maxPollRecords="1" />
    </kafka:consumer>

    <!-- Step 1: Build dedup key from message content -->
    <set-variable variableName="dedupKey"
        value="#[payload.orderId ++ '-' ++ (attributes.offset as String)]" />

    <!-- Step 2: Check if already processed -->
    <try>
        <os:contains objectStore="kafka-dedup-store" key="#[vars.dedupKey]" target="alreadyProcessed" />
        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <set-variable variableName="alreadyProcessed" value="#[false]" />
            </on-error-continue>
        </error-handler>
    </try>

    <choice>
        <!-- Already processed: skip and commit -->
        <when expression="#[vars.alreadyProcessed == true]">
            <logger level="INFO"
                message="Duplicate detected, skipping: #[vars.dedupKey]" />
            <kafka:commit config-ref="Kafka_Consumer_Config" />
        </when>

        <!-- Not processed: execute business logic -->
        <otherwise>
            <try>
                <!-- Step 3: Process the message -->
                <flow-ref name="process-order-exactly-once" />

                <!-- Step 4: Record in dedup store BEFORE committing offset -->
                <os:store objectStore="kafka-dedup-store" key="#[vars.dedupKey]">
                    <os:value>#[now() as String]</os:value>
                </os:store>

                <!-- Step 5: Commit offset LAST -->
                <kafka:commit config-ref="Kafka_Consumer_Config" />

                <error-handler>
                    <on-error-propagate type="ANY">
                        <logger level="ERROR"
                            message="Processing failed for #[vars.dedupKey]: #[error.description]" />
                        <!-- Do NOT commit offset — message will be redelivered -->
                        <!-- Do NOT store in dedup — next attempt should retry -->
                    </on-error-propagate>
                </error-handler>
            </try>
        </otherwise>
    </choice>
</flow>
```

#### Idempotent Database Write (Downstream)

```xml
<sub-flow name="process-order-exactly-once">
    <!-- Upsert: INSERT if new, ignore if exists -->
    <db:insert config-ref="Database_Config">
        <db:sql><![CDATA[
            INSERT INTO processed_orders (order_id, amount, processed_at)
            VALUES (:orderId, :amount, :processedAt)
            ON CONFLICT (order_id) DO NOTHING
        ]]></db:sql>
        <db:input-parameters><![CDATA[#[{
            orderId: payload.orderId,
            amount: payload.amount,
            processedAt: now()
        }]]]></db:input-parameters>
    </db:insert>

    <logger level="INFO"
        message="Order #[payload.orderId] processed (rows affected: #[payload.affectedRows])" />
</sub-flow>
```

### How It Works

```
Producer Side                          Consumer Side
─────────────                          ─────────────
1. enable.idempotence=true             1. Poll message (offset N)
2. Broker assigns ProducerID           2. Check dedup store for key
3. Broker deduplicates retries         3. If exists → skip, commit offset
   (same PID + sequence number)        4. If new → process business logic
4. acks=all ensures all replicas       5. Store key in Object Store
   have the message                    6. Commit offset N
                                       7. If crash between 5 and 6:
                                          message redelivered, dedup catches it
```

### Gotchas
- **Object Store is not transactional with Kafka**: There is a window between storing the dedup key (step 4) and committing the offset (step 5). If the app crashes after the OS write but before the commit, the message is redelivered but the dedup store catches it. This is safe. The dangerous window is between processing (step 3) and storing the dedup key (step 4) -- if the downstream write succeeds but the dedup store write fails, you get a duplicate on retry. Mitigate with idempotent downstream writes (UPSERT/ON CONFLICT).
- **maxPollRecords=1 is slow but safe**: Processing one message at a time ensures you never commit offsets for unprocessed messages. For higher throughput, increase `maxPollRecords` but implement batch dedup and batch offset commit.
- **Dedup store TTL must exceed reprocessing window**: If you set TTL=1 hour but a consumer is down for 2 hours, the dedup keys expire and duplicates slip through. Use TTL >= 7 days.
- **Object Store maxEntries**: CloudHub Object Store has a 10M entry limit. With 1M messages/day, you fill it in 10 days. Monitor usage and consider partitioning by date.
- **Consumer group rebalance resets in-flight**: During a rebalance, any in-flight messages are abandoned. The new consumer picks up from the last committed offset, not the last processed message. The dedup store handles this, but processing latency spikes during rebalance.
- **enable.idempotence requires specific settings**: If you set `enable.idempotence=true` without `acks=all`, the Kafka client throws a ConfigException at startup. Always set both together.
- **Kafka transactions vs app-level dedup**: Kafka's native transactional API (read-process-write atomicity) is not exposed by the MuleSoft Kafka connector. The Object Store approach is the MuleSoft-native equivalent.

### Testing

```xml
<munit:test name="test-exactly-once-dedup"
    description="Verify duplicate messages are skipped">

    <munit:behavior>
        <munit-tools:mock-when processor="db:insert">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{affectedRows: 1}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- Process first message -->
        <set-payload value='#[output application/json --- {orderId: "ORD-001", amount: 100}]' />
        <flow-ref name="kafka-exactly-once-consumer" />

        <!-- Process same message again (simulate redelivery) -->
        <set-payload value='#[output application/json --- {orderId: "ORD-001", amount: 100}]' />
        <flow-ref name="kafka-exactly-once-consumer" />
    </munit:execution>

    <munit:validation>
        <!-- DB insert should only be called once -->
        <munit-tools:verify-call processor="db:insert" times="1" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [Kafka Dead Letter Topic](../kafka-dead-letter-topic/) -- handle messages that fail processing
- [Kafka Rebalance Handling](../kafka-rebalance-handling/) -- graceful rebalance to minimize duplicate window
- [Kafka Schema Registry Evolution](../kafka-schema-registry-evolution/) -- schema changes that break consumers
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) -- Anypoint MQ's approach to exactly-once
