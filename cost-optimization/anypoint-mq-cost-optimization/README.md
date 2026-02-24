## Anypoint MQ Cost Optimization
> Reduce Anypoint MQ costs with message batching, payload compression, and queue consolidation strategies.

### When to Use
- Anypoint MQ costs are a significant portion of your MuleSoft bill (>15%)
- Processing millions of messages per month with large payloads
- Multiple queues with low individual throughput that could be consolidated
- Event-driven architecture with high message volume between services
- Seeing unexpected MQ cost increases due to payload size growth

### Configuration / Code

#### Anypoint MQ Pricing Reference

| Payload Size | Cost per Million Messages (approx.) | Cost per Message |
|-------------|--------------------------------------|------------------|
| < 2 KB | $1.00 | $0.000001 |
| 2-10 KB | $1.00 (1 API request) | $0.000001 |
| 10-50 KB | $5.00 (5 chunks at 10KB) | $0.000005 |
| 50-100 KB | $10.00 (10 chunks) | $0.00001 |
| 100-200 KB | $20.00 (20 chunks) | $0.00002 |
| 1 MB | $100.00 (100 chunks) | $0.0001 |
| 10 MB (max) | $1,000.00 (1000 chunks) | $0.001 |

*Anypoint MQ bills per 10KB chunk. A 50KB message = 5 billable API requests.*

#### Strategy 1: Message Batching

Batch multiple small messages into a single MQ publish to reduce per-message overhead:

```xml
<!-- Collect individual events and publish as a batch -->
<flow name="batch-publisher-flow">
    <!-- Receive individual events -->
    <http:listener config-ref="http-listener" path="/events" />

    <!-- Aggregate into batches of 100 or every 5 seconds -->
    <aggregators:group-based-aggregator name="event-batcher"
        groupId="#['event-batch']"
        groupSize="100"
        evictionTime="5"
        evictionTimeUnit="SECONDS">

        <aggregators:aggregation-complete>
            <!-- Batch is ready — publish as single message -->
            <set-payload value='#[output application/json --- {
                batchId: uuid(),
                count: sizeOf(payload),
                timestamp: now(),
                events: payload
            }]' />

            <anypoint-mq:publish config-ref="mq-config"
                                 destination="events-batch-queue">
                <anypoint-mq:properties>
                    <anypoint-mq:property key="batchSize" value="#[sizeOf(payload.events)]" />
                    <anypoint-mq:property key="compressed" value="false" />
                </anypoint-mq:properties>
            </anypoint-mq:publish>
        </aggregators:aggregation-complete>
    </aggregators:group-based-aggregator>
</flow>

<!-- Consumer unpacks the batch -->
<flow name="batch-consumer-flow">
    <anypoint-mq:subscriber config-ref="mq-config"
                             destination="events-batch-queue" />

    <set-variable variableName="batch" value="#[payload]" />

    <!-- Process each event in the batch -->
    <foreach collection="#[vars.batch.events]">
        <flow-ref name="process-single-event" />
    </foreach>

    <anypoint-mq:ack config-ref="mq-config" />
</flow>
```

**Savings: 100 individual publishes at $0.000001 each = $0.0001 vs 1 batched publish = $0.000001 — 99% reduction in publish costs.**

#### Strategy 2: Payload Compression

Compress payloads before publishing to reduce chunk count:

```xml
<!-- Compress before publish -->
<flow name="compressed-publisher-flow">
    <http:listener config-ref="http-listener" path="/large-events" />

    <!-- Original payload: ~200KB JSON -->
    <set-variable variableName="originalSize" value="#[sizeOf(payload)]" />

    <!-- Compress with gzip — typically 80-90% reduction for JSON -->
    <ee:transform>
        <ee:set-payload><![CDATA[%dw 2.0
            import * from dw::core::Binaries
            output application/octet-stream
            ---
            // Convert JSON to string, then compress
            toBase64(payload as String {encoding: "UTF-8"} as Binary)
        ]]></ee:set-payload>
    </ee:transform>

    <!-- Use Java gzip compression -->
    <scripting:execute engine="groovy">
        <scripting:code>
            import java.util.zip.GZIPOutputStream
            def baos = new ByteArrayOutputStream()
            def gzip = new GZIPOutputStream(baos)
            gzip.write(message.payload.getBytes("UTF-8"))
            gzip.close()
            return baos.toByteArray()
        </scripting:code>
    </scripting:execute>

    <anypoint-mq:publish config-ref="mq-config"
                         destination="compressed-events-queue">
        <anypoint-mq:properties>
            <anypoint-mq:property key="content-encoding" value="gzip" />
            <anypoint-mq:property key="original-size" value="#[vars.originalSize]" />
        </anypoint-mq:properties>
    </anypoint-mq:publish>
</flow>

<!-- Decompress on consume -->
<flow name="compressed-consumer-flow">
    <anypoint-mq:subscriber config-ref="mq-config"
                             destination="compressed-events-queue" />

    <!-- Decompress gzip payload -->
    <scripting:execute engine="groovy">
        <scripting:code>
            import java.util.zip.GZIPInputStream
            def bais = new ByteArrayInputStream(message.payload)
            def gzip = new GZIPInputStream(bais)
            return new String(gzip.readAllBytes(), "UTF-8")
        </scripting:code>
    </scripting:execute>

    <!-- Parse back to JSON -->
    <ee:transform>
        <ee:set-payload><![CDATA[%dw 2.0
            output application/json
            ---
            read(payload, "application/json")
        ]]></ee:set-payload>
    </ee:transform>

    <flow-ref name="process-event" />
    <anypoint-mq:ack config-ref="mq-config" />
</flow>
```

**Savings: 200KB payload = 20 chunks ($0.00002/msg). After gzip (~30KB) = 3 chunks ($0.000003/msg) — 85% reduction.**

#### Strategy 3: Queue Consolidation

Merge low-traffic queues using message type headers:

```xml
<!-- Before: 5 separate queues -->
<!--
    order-created-queue      (1K msgs/day)
    order-updated-queue      (500 msgs/day)
    order-cancelled-queue    (100 msgs/day)
    order-shipped-queue      (800 msgs/day)
    order-delivered-queue    (700 msgs/day)
    = 5 queues, 5 subscribers, 5× polling overhead
-->

<!-- After: 1 consolidated queue with type-based routing -->
<flow name="order-events-publisher">
    <anypoint-mq:publish config-ref="mq-config"
                         destination="order-events-queue">
        <anypoint-mq:properties>
            <anypoint-mq:property key="eventType" value="#[vars.eventType]" />
            <anypoint-mq:property key="orderId" value="#[vars.orderId]" />
        </anypoint-mq:properties>
    </anypoint-mq:publish>
</flow>

<flow name="order-events-consumer">
    <anypoint-mq:subscriber config-ref="mq-config"
                             destination="order-events-queue" />

    <!-- Route by event type -->
    <choice>
        <when expression="#[attributes.properties.eventType == 'ORDER_CREATED']">
            <flow-ref name="handle-order-created" />
        </when>
        <when expression="#[attributes.properties.eventType == 'ORDER_UPDATED']">
            <flow-ref name="handle-order-updated" />
        </when>
        <when expression="#[attributes.properties.eventType == 'ORDER_CANCELLED']">
            <flow-ref name="handle-order-cancelled" />
        </when>
        <when expression="#[attributes.properties.eventType == 'ORDER_SHIPPED']">
            <flow-ref name="handle-order-shipped" />
        </when>
        <when expression="#[attributes.properties.eventType == 'ORDER_DELIVERED']">
            <flow-ref name="handle-order-delivered" />
        </when>
        <otherwise>
            <logger level="WARN" message="Unknown event type: #[attributes.properties.eventType]" />
        </otherwise>
    </choice>

    <anypoint-mq:ack config-ref="mq-config" />
</flow>
```

#### Combined Savings Example

| Optimization | Messages/Month | Before ($/mo) | After ($/mo) | Savings |
|-------------|----------------|---------------|--------------|---------|
| Batching (100:1 ratio) | 10M → 100K publishes | $10.00 | $0.10 | $9.90 |
| Compression (200KB→30KB) | 5M messages | $100.00 | $15.00 | $85.00 |
| Queue consolidation | 3.1K/day polling | $5.00 | $1.00 | $4.00 |
| **Combined** | — | **$115.00** | **$16.10** | **$98.90 (86%)** |

*For high-volume orgs processing 100M+ messages/month, savings scale to $1,000+/month.*

### How It Works
1. Audit current MQ usage — total messages per queue, average payload size, and monthly cost from the Anypoint MQ dashboard
2. Identify large-payload queues (>10KB average) as compression candidates — JSON and XML compress 80-90% with gzip
3. Identify high-frequency, small-payload queues as batching candidates — aggregate 50-100 messages per publish
4. Identify low-traffic queues in the same domain as consolidation candidates — merge into a single queue with type-based routing
5. Implement compression first (lowest risk, highest per-message savings), then batching, then consolidation
6. Monitor consumer processing time after changes — batched messages take longer to process per delivery, requiring adjusted timeout settings
7. Track MQ costs weekly for the first month to validate savings projections

### Gotchas
- **FIFO queue premium** — FIFO queues cost ~2.5x standard queues and have lower throughput (300 msgs/sec vs 4000 msgs/sec); use FIFO only when message ordering is a strict business requirement
- **Message size limit is 10MB** — Anypoint MQ rejects messages over 10MB; after batching, ensure the aggregate payload stays under this limit; set batch size based on average individual message size
- **Compression adds latency** — gzip compression/decompression adds 1-5ms per message; for sub-millisecond latency requirements, the overhead may not be acceptable
- **Batching increases blast radius** — if one message in a batch of 100 is poison (unparseable), naive error handling rejects the entire batch; implement per-record error handling within the batch consumer
- **Queue consolidation reduces parallelism** — 5 separate queues can be consumed by 5 independent subscribers in parallel; 1 consolidated queue has a single consumption stream unless you add prefetch/concurrent consumers
- **MQ billing counts both publish and consume** — don't forget that each message is billed twice (once for publish, once for consume); compression savings apply to both operations
- **Dead letter queue costs** — DLQ messages are billed the same as regular messages; a poison message that retries 3 times then goes to DLQ = 4× the cost of a successfully processed message

### Related
- [Anypoint MQ DLQ](../../error-handling/dead-letter-queues/anypoint-mq-dlq/) — dead letter queue configuration
- [VM Queue DLQ](../../error-handling/dead-letter-queues/vm-queue-dlq/) — VM queues as a free alternative for intra-app messaging
- [Batch Block Size Optimization](../../performance/batch/block-size-optimization/) — optimize batch processing throughput
- [Aggregator Commit Sizing](../../performance/batch/aggregator-commit-sizing/) — tune aggregator for batching
- [API Consolidation Patterns](../api-consolidation-patterns/) — similar consolidation approach for APIs
