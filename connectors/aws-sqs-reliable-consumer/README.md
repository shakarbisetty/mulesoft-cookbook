## AWS SQS Reliable Consumer

> SQS visibility timeout management, Dead Letter Queue configuration, FIFO deduplication, and exactly-once processing for Mule 4.

### When to Use

- Building event-driven integrations that consume messages from SQS queues
- Need guaranteed message processing with automatic retry and dead letter handling
- Processing S3 event notifications (file upload triggers) via SQS
- Implementing FIFO ordering guarantees for message sequences (e.g., order state changes)

### The Problem

SQS's default visibility timeout (30 seconds) is too short for most Mule processing flows. If your flow takes 45 seconds, SQS re-delivers the message while the first instance is still processing, causing duplicates. Without a Dead Letter Queue, poison messages (messages that always fail processing) retry infinitely, consuming all your worker capacity. FIFO queues add ordering guarantees but require explicit deduplication IDs and message group IDs.

### Configuration

#### SQS Connector Config

```xml
<sqs:config name="Amazon_SQS_Config" doc:name="Amazon SQS Config">
    <sqs:basic-connection
        accessKey="${aws.accessKey}"
        secretKey="${aws.secretKey}"
        region="${aws.region}" />
</sqs:config>
```

#### Standard Queue Consumer with Visibility Timeout

```xml
<flow name="sqs-reliable-consumer-flow">
    <sqs:receive-messages config-ref="Amazon_SQS_Config"
        doc:name="SQS Listener"
        queueUrl="${sqs.queue.url}"
        numberOfMessages="10"
        visibilityTimeout="120"
        waitTimeOut="20">
        <scheduling-strategy>
            <fixed-frequency frequency="1" timeUnit="SECONDS" />
        </scheduling-strategy>
    </sqs:receive-messages>

    <foreach doc:name="Process Each Message">
        <set-variable variableName="receiptHandle"
            value="#[payload.receiptHandle]" />
        <set-variable variableName="messageId"
            value="#[payload.messageId]" />

        <try doc:name="Process with Ack/Nack">
            <!-- Parse message body -->
            <ee:transform doc:name="Parse SQS Message">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
var body = read(payload.body, "application/json")
---
{
    messageId: vars.messageId,
    eventType: body.eventType default "unknown",
    data: body.data default {},
    attributes: {
        sentTimestamp: payload.attributes.SentTimestamp default "",
        approximateReceiveCount: payload.attributes.ApproximateReceiveCount default "1",
        messageGroupId: payload.attributes.MessageGroupId default null
    }
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <set-variable variableName="receiveCount"
                value="#[payload.attributes.approximateReceiveCount as Number]" />

            <!-- Business logic -->
            <choice doc:name="Route by Event Type">
                <when expression="#[payload.eventType == 'order.created']">
                    <flow-ref name="handle-order-created-subflow" />
                </when>
                <when expression="#[payload.eventType == 'order.updated']">
                    <flow-ref name="handle-order-updated-subflow" />
                </when>
                <otherwise>
                    <logger level="WARN"
                        message="Unknown event type: #[payload.eventType]. Discarding." />
                </otherwise>
            </choice>

            <!-- Delete message on successful processing (ACK) -->
            <sqs:delete-message config-ref="Amazon_SQS_Config"
                doc:name="ACK - Delete Message"
                queueUrl="${sqs.queue.url}"
                receiptHandle="#[vars.receiptHandle]" />

            <logger level="DEBUG"
                message="Message #[vars.messageId] processed and deleted." />

            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                        message="Failed to process message #[vars.messageId] (attempt #[vars.receiveCount]): #[error.description]" />

                    <!-- Extend visibility timeout if processing needs more time -->
                    <choice doc:name="Extend or Let Retry">
                        <when expression="#[vars.receiveCount as Number < 3]">
                            <!-- Let SQS redeliver after visibility timeout expires -->
                            <logger level="INFO"
                                message="Message #[vars.messageId] will be retried by SQS." />
                        </when>
                        <otherwise>
                            <!-- After 3 failures, message will go to DLQ (configured on queue) -->
                            <logger level="ERROR"
                                message="Message #[vars.messageId] has failed #[vars.receiveCount] times. Will go to DLQ." />
                        </otherwise>
                    </choice>
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>
</flow>
```

#### DLQ Processing and Alerting

```xml
<flow name="sqs-dlq-processor-flow">
    <sqs:receive-messages config-ref="Amazon_SQS_Config"
        doc:name="DLQ Listener"
        queueUrl="${sqs.dlq.url}"
        numberOfMessages="10"
        visibilityTimeout="300"
        waitTimeOut="20">
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS" />
        </scheduling-strategy>
    </sqs:receive-messages>

    <choice doc:name="Has DLQ Messages?">
        <when expression="#[sizeOf(payload) > 0]">
            <ee:transform doc:name="Build DLQ Alert">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    alert: "DLQ_MESSAGES_DETECTED",
    severity: "HIGH",
    queueUrl: p('sqs.dlq.url'),
    messageCount: sizeOf(payload),
    messages: payload map {
        messageId: $.messageId,
        body: $.body,
        sentTimestamp: $.attributes.SentTimestamp,
        receiveCount: $.attributes.ApproximateReceiveCount,
        firstReceived: $.attributes.ApproximateFirstReceiveTimestamp
    },
    detectedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <!-- Send alert to monitoring system -->
            <http:request config-ref="Monitoring_API"
                method="POST"
                path="/api/alerts" />

            <!-- Store DLQ messages for analysis -->
            <foreach collection="#[payload.messages]">
                <os:store key="#['dlq_' ++ payload.messageId]"
                    objectStore="DLQ_Store">
                    <os:value><![CDATA[#[write(payload, 'application/json')]]]></os:value>
                </os:store>
            </foreach>
        </when>
    </choice>
</flow>
```

#### FIFO Queue Consumer with Deduplication

```xml
<flow name="sqs-fifo-consumer-flow">
    <sqs:receive-messages config-ref="Amazon_SQS_Config"
        doc:name="FIFO Queue Listener"
        queueUrl="${sqs.fifo.queue.url}"
        numberOfMessages="10"
        visibilityTimeout="120"
        waitTimeOut="20">
        <scheduling-strategy>
            <fixed-frequency frequency="1" timeUnit="SECONDS" />
        </scheduling-strategy>
    </sqs:receive-messages>

    <foreach doc:name="Process in Order">
        <set-variable variableName="receiptHandle"
            value="#[payload.receiptHandle]" />
        <set-variable variableName="messageGroupId"
            value="#[payload.attributes.MessageGroupId]" />
        <set-variable variableName="sequenceNumber"
            value="#[payload.attributes.SequenceNumber]" />

        <try doc:name="Process FIFO Message">
            <ee:transform doc:name="Parse">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
read(payload.body, "application/json") ++ {
    _meta: {
        messageGroupId: vars.messageGroupId,
        sequenceNumber: vars.sequenceNumber
    }
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <!-- Process maintaining order within message group -->
            <flow-ref name="process-ordered-message-subflow" />

            <sqs:delete-message config-ref="Amazon_SQS_Config"
                doc:name="ACK"
                queueUrl="${sqs.fifo.queue.url}"
                receiptHandle="#[vars.receiptHandle]" />

            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                        message="FIFO message failed. Group: #[vars.messageGroupId], Seq: #[vars.sequenceNumber]" />
                    <!-- FIFO: failing message blocks all subsequent messages in the same group -->
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>
</flow>
```

#### Send to SQS with Deduplication

```xml
<flow name="sqs-send-fifo-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/events/publish"
        allowedMethods="POST" />

    <ee:transform doc:name="Build SQS Message">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    body: write(payload.event, "application/json"),
    messageGroupId: payload.groupId default "default",
    messageDeduplicationId: payload.deduplicationId default
        (payload.event.id ++ "_" ++ (now() as Number as String))
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <sqs:send-message config-ref="Amazon_SQS_Config"
        doc:name="Send to FIFO Queue"
        queueUrl="${sqs.fifo.queue.url}"
        messageBody="#[payload.body]"
        messageGroupId="#[payload.messageGroupId]"
        messageDeduplicationId="#[payload.messageDeduplicationId]" />

    <ee:transform doc:name="Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "published",
    messageId: payload.messageId,
    sequenceNumber: payload.sequenceNumber
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Calculate optimal visibility timeout
fun visibilityTimeout(avgProcessingTimeMs: Number, safetyMultiplier: Number = 3): Number =
    ceil((avgProcessingTimeMs * safetyMultiplier) / 1000)

// Build dedup ID for FIFO queues
fun buildDedupId(eventType: String, entityId: String): String =
    eventType ++ "_" ++ entityId ++ "_" ++ (now() as Number as String)

// Parse S3 event notification from SQS
fun parseS3Event(sqsBody: String): Object = do {
    var event = read(sqsBody, "application/json")
    var record = event.Records[0] default {}
    ---
    {
        eventName: record.eventName,
        bucket: record.s3.bucket.name,
        key: record.s3.object.key,
        size: record.s3.object.size,
        region: record.awsRegion
    }
}
---
{
    timeout: visibilityTimeout(30000),
    dedupId: buildDedupId("order.created", "ORD-123")
}
```

### Gotchas

- **Visibility timeout must exceed processing time** — If your flow takes 60 seconds but visibility timeout is 30 seconds, SQS delivers the message to another consumer while the first is still processing. Set visibility timeout to at least 3x your average processing time
- **DLQ `maxReceiveCount` determines retry count** — The DLQ redrive policy's `maxReceiveCount` sets how many times a message is retried before going to the DLQ. Set it to 3-5. Setting it to 1 means no retries; setting it too high delays DLQ arrival for poison messages
- **FIFO head-of-line blocking** — In a FIFO queue, a failing message blocks all subsequent messages in the same message group. If message 3 of 10 fails, messages 4-10 wait until message 3 succeeds or goes to DLQ. Use fine-grained message group IDs (e.g., per order ID, not per event type)
- **SQS long polling** — Set `waitTimeOut=20` (maximum) to enable long polling. Without long polling, each receive call returns immediately (even if empty), wasting API calls and increasing cost. Long polling waits up to 20 seconds for messages to arrive
- **Message size limit** — SQS messages are limited to 256 KB. For larger payloads, store the data in S3 and put only the S3 reference in the SQS message. The SQS Extended Client Library supports this pattern
- **FIFO deduplication window** — FIFO queues deduplicate messages by `messageDeduplicationId` within a 5-minute window. If you resend the same dedup ID within 5 minutes, SQS silently discards it. This is intentional but can cause confusion during testing
- **Standard queues deliver at-least-once** — Standard SQS queues can deliver the same message more than once. Your consumer must be idempotent. Use a database or Object Store to track processed message IDs

### Testing

```xml
<munit:test name="sqs-message-processing-test"
    description="Verify message is processed and deleted">

    <munit:behavior>
        <munit-tools:mock-when processor="sqs:receive-messages">
            <munit-tools:then-return>
                <munit-tools:payload value="#[[{
                    messageId: 'msg-001',
                    body: '{\"eventType\": \"order.created\", \"data\": {\"id\": \"ORD-1\"}}',
                    receiptHandle: 'receipt-001',
                    attributes: {
                        SentTimestamp: '1700000000000',
                        ApproximateReceiveCount: '1'
                    }
                }]]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
        <munit-tools:mock-when processor="sqs:delete-message">
            <munit-tools:then-return>
                <munit-tools:payload value="#[null]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="sqs-reliable-consumer-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="sqs:delete-message"
            times="1" />
    </munit:validation>
</munit:test>
```

### Related

- [AWS S3 Streaming Upload](../aws-s3-streaming-upload/) — S3 event notifications consumed via SQS
- [Azure Service Bus Patterns](../azure-service-bus-patterns/) — Similar messaging patterns for Azure
