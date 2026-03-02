## Anypoint MQ Subscriber Scaling

> Tune prefetch count, maxConcurrency, and horizontal pod scaling to maximize Anypoint MQ throughput without message loss.

### When to Use
- Your Anypoint MQ consumer cannot keep up with incoming message volume
- You need to process thousands of messages per second from a single queue
- You want to scale horizontally across CloudHub 2.0 replicas or Runtime Fabric pods
- You need to tune prefetch and concurrency for different message processing profiles (fast vs slow)

### The Problem
Out-of-the-box Anypoint MQ subscriber settings are conservative. Default `prefetch=10` and `maxConcurrency=1` mean a single thread processes one message at a time while 9 sit in the local buffer. For high-throughput queues, this leaves 90% of capacity unused. Blindly increasing these values without understanding the trade-offs causes memory pressure, duplicate processing during crashes, and uneven load distribution across replicas.

### Configuration

#### Baseline: Conservative Settings for Slow Processing

```xml
<!--
    Scenario: Each message triggers a 2-second API call.
    Low prefetch prevents buffering messages you can't process before lock TTL.
    Low concurrency because the downstream API can't handle parallel calls.
-->
<flow name="slow-processor" maxConcurrency="2">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue"
        acknowledgementMode="MANUAL">
        <anypoint-mq:subscriber-config
            prefetch="2"
            acknowledgementTimeout="120000" />
    </anypoint-mq:subscriber>

    <try>
        <http:request config-ref="Slow_API"
            method="POST" path="/api/process"
            responseTimeout="30000">
            <http:body>#[payload]</http:body>
        </http:request>

        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                    message="Failed #[attributes.messageId]: #[error.description]" />
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### High-Throughput: Fast Processing with Aggressive Tuning

```xml
<!--
    Scenario: Each message takes <50ms to process (lightweight transforms).
    High prefetch fills the buffer so threads never wait for broker round-trips.
    High concurrency saturates CPU cores.
-->
<flow name="fast-processor" maxConcurrency="8">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="events-queue"
        acknowledgementMode="MANUAL">
        <anypoint-mq:subscriber-config
            prefetch="10"
            acknowledgementTimeout="60000" />
    </anypoint-mq:subscriber>

    <try>
        <!-- Lightweight transformation -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    eventId: payload.id,
    normalized: upper(payload.name),
    timestamp: now()
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Batch insert to database -->
        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO events (event_id, data, created_at)
                     VALUES (:eventId, :data, :createdAt)</db:sql>
            <db:input-parameters><![CDATA[#[{
                eventId: payload.eventId,
                data: write(payload, "application/json"),
                createdAt: now()
            }]]]></db:input-parameters>
        </db:insert>

        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate type="ANY">
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Anypoint MQ Global Config with Connection Tuning

```xml
<anypoint-mq:config name="Anypoint_MQ_Config">
    <anypoint-mq:connection
        clientId="${amq.client.id}"
        clientSecret="${amq.client.secret}"
        url="${amq.broker.url}">
        <!-- Connection pool for high concurrency -->
        <reconnection>
            <reconnect frequency="3000" count="5" />
        </reconnection>
    </anypoint-mq:connection>
</anypoint-mq:config>
```

#### Horizontal Scaling: CloudHub 2.0 Replicas

```yaml
# deployment.yaml for CloudHub 2.0 / Runtime Fabric
spec:
  replicas: 4                    # 4 pods consuming from same queue
  mule:
    jvmArgs: "-Xmx512m -Xms512m"
  resources:
    cpu:
      reserved: "500m"
      limit: "1000m"
    memory:
      reserved: "1000Mi"
      limit: "1500Mi"
```

```
# Throughput calculation:
#   4 replicas x 8 maxConcurrency x 20 msg/sec per thread = 640 msg/sec
#   4 replicas x 10 prefetch = 40 messages buffered across cluster
#
# Anypoint MQ limits:
#   Standard queue: ~1000 msg/sec per queue (varies by region)
#   FIFO queue: ~300 msg/sec per queue (strict ordering)
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json
---
/**
 * Calculate optimal prefetch and concurrency based on message profile.
 * Use this to document your tuning rationale.
 */
{
    profile: "order-processing",
    avgProcessingTimeMs: 200,
    lockTtlMs: 120000,
    recommendations: {
        // prefetch = lockTTL / avgProcessingTime / 2 (safety margin)
        prefetch: floor(120000 / 200 / 2),
        // maxConcurrency = available cores - 1 (leave 1 for runtime)
        maxConcurrency: max([1, 4 - 1]),
        // replicas = target throughput / (maxConcurrency * (1000 / avgProcessingTime))
        replicasFor1000MsgSec: ceil(1000 / (3 * (1000 / 200)))
    }
}
```

### Tuning Decision Matrix

```
Processing Time  |  Prefetch  |  maxConcurrency  |  Replicas (1000 msg/s target)
─────────────────┼────────────┼──────────────────┼──────────────────────────────
< 50ms           |     10     |       8          |  2
50-200ms         |      5     |       4-6        |  3-4
200ms-1s         |      2     |       2-4        |  5-8
1s-5s            |      1     |       1-2        |  10+
> 5s             |      1     |       1          |  Scale downstream first
```

### Gotchas
- **Prefetch > maxConcurrency is wasteful**: If `prefetch=10` but `maxConcurrency=2`, 8 messages sit in the buffer doing nothing. They hold locks that will expire, causing redelivery and duplicate processing. Rule: `prefetch <= maxConcurrency + 2` (small buffer for thread handoff).
- **Lock TTL vs processing time**: If `acknowledgementTimeout` (lock TTL) expires before processing completes, the broker redelivers the message to another consumer. You get duplicates. Set `acknowledgementTimeout >= 2 * maxProcessingTime` as a safety margin.
- **Horizontal scaling is not free**: Each replica opens its own connection to the Anypoint MQ broker and polls independently. With 10 replicas and `prefetch=10`, you have 100 messages locked simultaneously. If consumers crash, all 100 messages wait for lock TTL expiry before redelivery.
- **FIFO queues limit parallelism**: FIFO queues deliver messages in order within a message group. `maxConcurrency > 1` only helps if you have multiple message groups. With a single group, only 1 thread is active regardless of concurrency settings.
- **Memory pressure with large messages**: `prefetch=10` with 1MB messages = 10MB buffer per flow. With `maxConcurrency=8`, that is 80MB just for message buffers. For large payloads, use `prefetch=1` and the claim-check pattern (see Large Payload recipe).
- **CloudHub 1.0 vs 2.0 workers**: CloudHub 1.0 workers share an Object Store and use sticky sessions. CloudHub 2.0 replicas are independent pods. Scaling behavior differs — test in your target runtime.
- **Auto-scaling lag**: Runtime Fabric HPA (Horizontal Pod Autoscaler) reacts to CPU/memory, not queue depth. By the time CPU triggers a scale-up, your queue may already have a backlog. Consider custom metrics or proactive scaling for predictable traffic spikes.

### Testing

```xml
<!-- MUnit: Verify concurrency behavior -->
<munit:test name="test-concurrent-processing"
    description="Verify maxConcurrency processes messages in parallel">

    <munit:behavior>
        <!-- Mock slow downstream to prove parallel execution -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="config-ref"
                    whereValue="Slow_API" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#[output application/json --- {status: 'ok'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- Publish 10 messages rapidly -->
        <foreach collection="#[1 to 10]">
            <anypoint-mq:publish
                config-ref="Anypoint_MQ_Config"
                destination="events-queue">
                <anypoint-mq:message>
                    <anypoint-mq:body>#[output application/json --- {id: vars.counter}]</anypoint-mq:body>
                </anypoint-mq:message>
            </anypoint-mq:publish>
        </foreach>
    </munit:execution>

    <munit:validation>
        <!-- All 10 messages should be processed within ~2x single message time -->
        <munit-tools:assert-that
            expression="#[MunitTools::queueSize('events-queue')]"
            is="#[MunitTools::equalTo(0)]" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [Anypoint MQ Large Payload](../anypoint-mq-large-payload/) -- claim-check pattern for large messages that blow up prefetch buffers
- [Anypoint MQ Circuit Breaker](../anypoint-mq-circuit-breaker/) -- throttle consumption when downstream is slow
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) -- VM queues scale differently (in-memory, single app)
- [AMQ Batch Consumer](../amq-batch-consumer/) -- batch processing as an alternative to high concurrency
