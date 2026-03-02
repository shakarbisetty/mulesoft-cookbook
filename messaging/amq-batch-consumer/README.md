## Anypoint MQ Batch Consumer

> Consume batches of Anypoint MQ messages efficiently with bulk acknowledgement strategies, batch aggregation, and error isolation.

### When to Use
- You need to insert hundreds of messages into a database and want batch INSERT instead of row-by-row
- Individual message processing is fast but the overhead per message (connection setup, ACK round-trip) dominates latency
- You want to reduce Anypoint MQ API call costs by acknowledging batches instead of individual messages
- Your downstream system performs better with bulk operations (batch API, bulk upsert)

### The Problem
The standard Anypoint MQ subscriber processes one message at a time: receive, process, ACK, repeat. For high-volume queues, the per-message overhead (network round-trip for ACK, database connection acquisition, HTTP request setup) is significant. If each message takes 5ms to process but 20ms of overhead, you are spending 80% of your time on overhead. Batch consumption aggregates multiple messages, processes them together, and acknowledges them as a group -- reducing overhead and improving throughput by 5-10x.

### Configuration

#### Batch Aggregation with Scheduler + Consume Loop

```xml
<!--
    Strategy: Use a scheduler to poll and consume multiple messages
    in a loop, aggregate them, then process as a batch.

    Why not use subscriber? The subscriber fires once per message.
    For true batch processing, we need to pull N messages in a tight loop.
-->
<os:object-store name="batch-state-store"
    persistent="true"
    entryTtl="1"
    entryTtlUnit="HOURS" />

<flow name="amq-batch-consumer">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="SECONDS" />
        </scheduling-strategy>
    </scheduler>

    <!-- Collect batch of messages -->
    <set-variable variableName="batch" value="#[[]]" />
    <set-variable variableName="messageRefs" value="#[[]]" />
    <set-variable variableName="batchSize" value="#[0]" />
    <set-variable variableName="maxBatchSize" value="#[50]" />

    <!-- Poll up to maxBatchSize messages -->
    <until-successful maxRetries="0">
        <foreach collection="#[1 to vars.maxBatchSize]">
            <try>
                <anypoint-mq:consume
                    config-ref="AMQ_Config"
                    destination="events-queue"
                    acknowledgementMode="MANUAL"
                    pollingTime="1000" />

                <!-- Add message to batch -->
                <set-variable variableName="batch"
                    value="#[vars.batch ++ [payload]]" />
                <set-variable variableName="messageRefs"
                    value="#[vars.messageRefs ++ [attributes]]" />
                <set-variable variableName="batchSize"
                    value="#[vars.batchSize + 1]" />

                <error-handler>
                    <!-- No more messages available: break the loop -->
                    <on-error-continue type="ANYPOINT-MQ:TIMEOUT">
                        <logger level="DEBUG" message="No more messages — batch has #[vars.batchSize] items" />
                    </on-error-continue>
                </error-handler>
            </try>
        </foreach>
    </until-successful>

    <!-- Only process if we have messages -->
    <choice>
        <when expression="#[vars.batchSize > 0]">
            <logger level="INFO"
                message="Processing batch of #[vars.batchSize] messages" />

            <try>
                <!-- Process entire batch -->
                <flow-ref name="process-batch" />

                <!-- ACK all messages in batch -->
                <foreach collection="#[vars.messageRefs]">
                    <anypoint-mq:ack
                        config-ref="AMQ_Config"
                        ackToken="#[payload.ackToken]" />
                </foreach>

                <logger level="INFO"
                    message="Batch of #[vars.batchSize] messages processed and ACKed" />

                <error-handler>
                    <on-error-propagate type="ANY">
                        <logger level="ERROR"
                            message="Batch processing failed: #[error.description]" />

                        <!-- NACK all messages for redelivery -->
                        <foreach collection="#[vars.messageRefs]">
                            <try>
                                <anypoint-mq:nack
                                    config-ref="AMQ_Config"
                                    ackToken="#[payload.ackToken]" />
                                <error-handler>
                                    <on-error-continue type="ANY">
                                        <logger level="WARN"
                                            message="Failed to NACK: #[error.description]" />
                                    </on-error-continue>
                                </error-handler>
                            </try>
                        </foreach>
                    </on-error-propagate>
                </error-handler>
            </try>
        </when>
    </choice>
</flow>
```

#### Batch Database Insert

```xml
<sub-flow name="process-batch">
    <!-- Transform batch to database-ready format -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
vars.batch map (msg) -> {
    eventId: msg.eventId,
    eventType: msg.eventType,
    data: write(msg, "application/json"),
    receivedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Bulk insert all records in one statement -->
    <db:bulk-insert config-ref="Database_Config">
        <db:sql>INSERT INTO events (event_id, event_type, data, received_at)
                 VALUES (:eventId, :eventType, :data, :receivedAt)
                 ON CONFLICT (event_id) DO NOTHING</db:sql>
        <db:bulk-input-parameters><![CDATA[#[payload map (item) -> {
            eventId: item.eventId,
            eventType: item.eventType,
            data: item.data,
            receivedAt: item.receivedAt
        }]]]></db:bulk-input-parameters>
    </db:bulk-insert>
</sub-flow>
```

#### Batch with Error Isolation (Partial ACK)

```xml
<!--
    Alternative strategy: process each message individually but
    ACK/NACK per message. Failed messages go back to queue,
    successful ones are ACKed.
    This avoids the all-or-nothing problem of batch ACK.
-->
<flow name="amq-batch-consumer-with-isolation">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="SECONDS" />
        </scheduling-strategy>
    </scheduler>

    <!-- Consume batch (same as above) -->
    <set-variable variableName="batch" value="#[[]]" />
    <set-variable variableName="maxBatchSize" value="#[50]" />
    <flow-ref name="collect-batch" />

    <set-variable variableName="successCount" value="#[0]" />
    <set-variable variableName="failCount" value="#[0]" />

    <!-- Process each message with individual error handling -->
    <foreach collection="#[vars.batch]">
        <set-variable variableName="currentMsg" value="#[payload.message]" />
        <set-variable variableName="currentRef" value="#[payload.attributes]" />

        <try>
            <set-payload value="#[vars.currentMsg]" />
            <flow-ref name="process-single-event" />

            <!-- ACK on success -->
            <anypoint-mq:ack config-ref="AMQ_Config"
                ackToken="#[vars.currentRef.ackToken]" />
            <set-variable variableName="successCount"
                value="#[vars.successCount + 1]" />

            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                        message="Failed message #[vars.currentRef.messageId]: #[error.description]" />

                    <!-- NACK only the failed message -->
                    <anypoint-mq:nack config-ref="AMQ_Config"
                        ackToken="#[vars.currentRef.ackToken]" />
                    <set-variable variableName="failCount"
                        value="#[vars.failCount + 1]" />
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>

    <logger level="INFO"
        message="Batch complete: #[vars.successCount] succeeded, #[vars.failCount] failed" />
</flow>
```

#### Subscriber-Based Batch with Aggregator

```xml
<!--
    Alternative: use the subscriber with an aggregator to collect
    messages into batches. The aggregator groups N messages or
    waits T seconds before releasing the batch.
-->
<flow name="amq-subscriber-with-aggregator" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="AMQ_Config"
        destination="events-queue"
        acknowledgementMode="MANUAL">
        <anypoint-mq:subscriber-config
            prefetch="10"
            acknowledgementTimeout="120000" />
    </anypoint-mq:subscriber>

    <!-- Store message and its ack token -->
    <set-variable variableName="messageWithRef" value="#[{
        message: payload,
        ackToken: attributes.ackToken,
        messageId: attributes.messageId
    }]" />

    <!-- Aggregate into batches of 25 or every 10 seconds -->
    <aggregators:group-based-aggregator name="message-batch"
        groupId="event-batch"
        groupSize="25"
        evictionTime="10"
        evictionTimeUnit="SECONDS">
        <aggregators:content>#[vars.messageWithRef]</aggregators:content>

        <aggregators:aggregation-complete>
            <logger level="INFO"
                message="Aggregated batch of #[sizeOf(payload)] messages" />

            <flow-ref name="process-aggregated-batch" />

            <!-- ACK all messages in the aggregated batch -->
            <foreach collection="#[payload]">
                <anypoint-mq:ack config-ref="AMQ_Config"
                    ackToken="#[payload.ackToken]" />
            </foreach>
        </aggregators:aggregation-complete>
    </aggregators:group-based-aggregator>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

/**
 * Partition a batch into successful and failed items
 * after attempting to validate each one.
 */
fun partitionBatch(batch: Array) =
    batch reduce (item, acc = {valid: [], invalid: []}) ->
        if (item.eventId? and item.eventType? and item.data?)
            {valid: acc.valid ++ [item], invalid: acc.invalid}
        else
            {valid: acc.valid, invalid: acc.invalid ++ [item]}

/**
 * Build a bulk INSERT VALUES clause for PostgreSQL.
 * More efficient than individual parameterized inserts for large batches.
 */
fun buildBulkValues(items: Array) =
    items map (item, idx) ->
        "(\$" ++ ((idx * 4) + 1) as String ++ ", \$" ++
        ((idx * 4) + 2) as String ++ ", \$" ++
        ((idx * 4) + 3) as String ++ ", \$" ++
        ((idx * 4) + 4) as String ++ ")"
    joinBy ", "
---
{
    example: partitionBatch([
        {eventId: "1", eventType: "A", data: {}},
        {eventType: "B"},
        {eventId: "3", eventType: "C", data: {}}
    ])
}
```

### Performance Comparison

```
Strategy                    | Throughput       | API Calls/msg  | Error Handling
────────────────────────────┼──────────────────┼────────────────┼──────────────────
Individual (subscriber)     | ~200 msg/sec     | 3 (poll+proc   | Per-message
                            |                  |  +ack)         |
────────────────────────────┼──────────────────┼────────────────┼──────────────────
Batch (all-or-nothing)      | ~1000 msg/sec    | ~1.2 (amort.)  | All fail if
                            |                  |                | one fails
────────────────────────────┼──────────────────┼────────────────┼──────────────────
Batch (error isolation)     | ~600 msg/sec     | ~2 (amort.)    | Per-message
                            |                  |                | ACK/NACK
────────────────────────────┼──────────────────┼────────────────┼──────────────────
Subscriber + Aggregator     | ~800 msg/sec     | ~1.5 (amort.)  | Per-batch
                            |                  |                |
```

### Gotchas
- **Lock TTL must exceed batch processing time**: If your batch of 50 messages takes 30 seconds to process but the lock TTL (acknowledgementTimeout) is 20 seconds, the broker redelivers messages before you ACK them. Set `acknowledgementTimeout >= batchSize * avgProcessingTimePerMessage * 2`.
- **All-or-nothing batch ACK risks**: If you ACK a batch of 50 after processing all 50, but message #48 fails, you must NACK all 50. The 47 successfully processed messages are redelivered and reprocessed (duplicates). Use the error isolation pattern to avoid this.
- **Anypoint MQ consume vs subscriber**: `anypoint-mq:consume` is a synchronous pull (like JMS receive). `anypoint-mq:subscriber` is an async push. For batch collection, `consume` in a loop gives you control over batch size. `subscriber` requires an aggregator for batching.
- **Memory pressure with large batches**: Storing 50 messages in a `vars.batch` array means 50 payloads in memory simultaneously. For 1MB messages, that is 50MB per batch. Monitor heap usage and reduce batch size for large payloads.
- **Scheduler frequency vs batch size**: If the scheduler fires every 5 seconds and collects 50 messages, you process 10 messages/second average. If the queue receives 20 messages/second, the backlog grows. Either increase batch size, decrease scheduler interval, or run multiple replicas.
- **NACK does not guarantee immediate redelivery**: NACKing a message returns it to the queue, but it may not be immediately available. There is a visibility timeout (lock TTL) that must expire before the message is redeliverable. During this window, the message is invisible.
- **Aggregator eviction creates incomplete batches**: The 10-second eviction timeout means you always wait 10 seconds if fewer than 25 messages arrive. For low-volume queues, this adds unnecessary latency. Tune eviction time based on your SLA requirements.

### Testing

```xml
<munit:test name="test-batch-processing-all-succeed"
    description="Verify all messages in batch are ACKed on success">

    <munit:behavior>
        <munit-tools:mock-when processor="db:bulk-insert">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{affectedRows: 5}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- Simulate a batch of 5 messages -->
        <set-variable variableName="batch" value='#[output application/json --- (1 to 5) map {
            eventId: "EVT-" ++ ($ as String),
            eventType: "ORDER_CREATED",
            data: {orderId: "ORD-" ++ ($ as String)}
        }]' />
        <set-variable variableName="batchSize" value="#[5]" />

        <flow-ref name="process-batch" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="db:bulk-insert" times="1" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [AMQ Subscriber Scaling](../amq-subscriber-scaling/) -- scaling individual message processing
- [Anypoint MQ Large Payload](../anypoint-mq-large-payload/) -- claim-check pattern for large messages in batches
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) -- batching with FIFO ordering constraints
