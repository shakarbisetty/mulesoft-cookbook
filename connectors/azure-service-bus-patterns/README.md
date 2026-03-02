## Azure Service Bus Patterns

> Competing consumers, sessions for ordered processing, scheduled delivery, and Dead Letter handling for Mule 4 with Azure Service Bus.

### When to Use

- Building event-driven integrations on Azure using Service Bus queues and topics
- Need ordered message processing per entity (e.g., all events for customer X processed sequentially)
- Implementing scheduled/delayed message delivery for future processing
- Migrating from IBM MQ or RabbitMQ to Azure Service Bus

### The Problem

Azure Service Bus offers advanced messaging features (sessions, scheduled delivery, duplicate detection, transactions) that most developers do not use because the configuration is non-obvious in MuleSoft. The default consumer setup processes messages out of order and does not handle poison messages. Competing consumers on a single queue need careful configuration to avoid message loss and ensure load balancing.

### Configuration

#### Azure Service Bus Connector Config

```xml
<azure-service-bus:config name="Azure_SB_Config"
    doc:name="Azure Service Bus Config">
    <azure-service-bus:sas-connection
        namespace="${azure.sb.namespace}"
        sharedAccessKeyName="${azure.sb.keyName}"
        sharedAccessKey="${azure.sb.key}" />
</azure-service-bus:config>
```

#### Competing Consumers Pattern

```xml
<!-- Multiple workers consuming from the same queue -->
<flow name="azure-sb-competing-consumer-flow"
    maxConcurrency="${azure.sb.maxConcurrency}">
    <azure-service-bus:listener config-ref="Azure_SB_Config"
        doc:name="SB Queue Listener"
        sourceType="QUEUE"
        destination="${azure.sb.queue}"
        numberOfConsumers="4"
        acknowledgementMode="AUTO"
        prefetchCount="10"
        receiveMode="PEEK_LOCK">
        <azure-service-bus:lock-renewal-config
            lockRenewalTime="60"
            lockRenewalTimeUnit="SECONDS" />
    </azure-service-bus:listener>

    <set-variable variableName="messageId"
        value="#[attributes.messageId]" />
    <set-variable variableName="deliveryCount"
        value="#[attributes.deliveryCount]" />
    <set-variable variableName="lockToken"
        value="#[attributes.lockToken]" />

    <try doc:name="Process Message">
        <ee:transform doc:name="Parse Message Body">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
var body = if (typeOf(payload) == "String") read(payload, "application/json") else payload
---
{
    messageId: vars.messageId,
    deliveryCount: vars.deliveryCount,
    eventType: body.eventType default "unknown",
    data: body.data default {},
    correlationId: attributes.correlationId default "",
    enqueuedTime: attributes.enqueuedTimeUtc default ""
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Business logic -->
        <flow-ref name="process-event-subflow" />

        <!-- Message auto-acknowledged on success (ACK mode = AUTO) -->
        <logger level="DEBUG"
            message="Message #[vars.messageId] processed successfully." />

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                    message="Message #[vars.messageId] failed (delivery #[vars.deliveryCount]): #[error.description]" />

                <choice doc:name="Abandon or Dead Letter">
                    <when expression="#[vars.deliveryCount as Number < 3]">
                        <!-- Abandon: return to queue for retry -->
                        <azure-service-bus:abandon config-ref="Azure_SB_Config"
                            doc:name="Abandon Message"
                            lockToken="#[vars.lockToken]" />
                    </when>
                    <otherwise>
                        <!-- Dead letter after 3 attempts -->
                        <azure-service-bus:dead-letter config-ref="Azure_SB_Config"
                            doc:name="Dead Letter Message"
                            lockToken="#[vars.lockToken]"
                            deadLetterReason="MaxRetriesExceeded"
                            deadLetterDescription="#[error.description]" />
                    </otherwise>
                </choice>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### Session-Based Ordered Processing

```xml
<!-- Sessions guarantee ordered processing per session ID (e.g., per customer) -->
<flow name="azure-sb-session-consumer-flow"
    maxConcurrency="4">
    <azure-service-bus:listener config-ref="Azure_SB_Config"
        doc:name="Session Queue Listener"
        sourceType="QUEUE"
        destination="${azure.sb.session.queue}"
        numberOfConsumers="4"
        acknowledgementMode="MANUAL"
        receiveMode="PEEK_LOCK"
        sessionEnabled="true" />

    <set-variable variableName="sessionId"
        value="#[attributes.sessionId]" />
    <set-variable variableName="lockToken"
        value="#[attributes.lockToken]" />
    <set-variable variableName="sequenceNumber"
        value="#[attributes.sequenceNumber]" />

    <try doc:name="Process Session Message">
        <ee:transform doc:name="Parse">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
var body = read(payload, "application/json")
---
{
    sessionId: vars.sessionId,
    sequenceNumber: vars.sequenceNumber,
    orderId: body.orderId,
    eventType: body.eventType,
    data: body.data,
    processedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <logger level="INFO"
            message="Processing session #[vars.sessionId], seq #[vars.sequenceNumber]: #[payload.eventType]" />

        <!-- Process in order for this session -->
        <flow-ref name="process-ordered-event-subflow" />

        <!-- Manual acknowledgment -->
        <azure-service-bus:complete config-ref="Azure_SB_Config"
            doc:name="Complete Message"
            lockToken="#[vars.lockToken]" />

        <error-handler>
            <on-error-continue type="ANY">
                <azure-service-bus:abandon config-ref="Azure_SB_Config"
                    doc:name="Abandon for Retry"
                    lockToken="#[vars.lockToken]" />
                <logger level="ERROR"
                    message="Session message failed: session=#[vars.sessionId], error=#[error.description]" />
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### Scheduled Message Delivery

```xml
<flow name="azure-sb-scheduled-send-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/events/schedule"
        allowedMethods="POST" />

    <ee:transform doc:name="Build Scheduled Message">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    body: write(payload.event, "application/json"),
    scheduledEnqueueTime: payload.deliverAt,
    sessionId: payload.sessionId default null,
    correlationId: payload.correlationId default uuid(),
    label: payload.eventType default "scheduled-event",
    customProperties: {
        source: "MuleSoft",
        scheduledBy: "api",
        originalRequestTime: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <azure-service-bus:send config-ref="Azure_SB_Config"
        doc:name="Send Scheduled Message"
        destinationType="QUEUE"
        destination="${azure.sb.queue}">
        <azure-service-bus:message
            body="#[payload.body]"
            scheduledEnqueueTimeUtc="#[payload.scheduledEnqueueTime]"
            correlationId="#[payload.correlationId]"
            label="#[payload.label]"
            sessionId="#[payload.sessionId]">
            <azure-service-bus:properties><![CDATA[#[payload.customProperties]]]></azure-service-bus:properties>
        </azure-service-bus:message>
    </azure-service-bus:send>

    <ee:transform doc:name="Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "scheduled",
    deliverAt: payload.scheduledEnqueueTime,
    sequenceNumber: payload.sequenceNumber default "N/A",
    correlationId: payload.correlationId
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Topic Subscription with Filters

```xml
<flow name="azure-sb-topic-subscriber-flow">
    <azure-service-bus:listener config-ref="Azure_SB_Config"
        doc:name="Topic Subscriber"
        sourceType="TOPIC"
        destination="${azure.sb.topic}"
        subscription="${azure.sb.subscription}"
        numberOfConsumers="2"
        acknowledgementMode="AUTO"
        receiveMode="PEEK_LOCK" />

    <ee:transform doc:name="Process Topic Message">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var body = read(payload, "application/json")
---
{
    topic: p('azure.sb.topic'),
    subscription: p('azure.sb.subscription'),
    messageId: attributes.messageId,
    label: attributes.label default "",
    data: body,
    customProperties: attributes.properties default {}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <logger level="INFO"
        message="Topic message from #[payload.subscription]: #[payload.label]" />
</flow>
```

#### Dead Letter Queue Processor

```xml
<flow name="azure-sb-dlq-processor-flow">
    <scheduler doc:name="Check DLQ Every 5 Minutes">
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <!-- DLQ path is: queue/$deadletterqueue -->
    <azure-service-bus:receive config-ref="Azure_SB_Config"
        doc:name="Receive DLQ Messages"
        sourceType="QUEUE"
        destination="${azure.sb.queue}/$deadletterqueue"
        receiveMode="PEEK_LOCK"
        maxMessages="50"
        serverWaitTime="5" />

    <choice doc:name="Has DLQ Messages?">
        <when expression="#[sizeOf(payload default []) > 0]">
            <foreach doc:name="Process DLQ Messages">
                <ee:transform doc:name="Build DLQ Report">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    messageId: attributes.messageId,
    deadLetterReason: attributes.deadLetterReason default "unknown",
    deadLetterDescription: attributes.deadLetterDescription default "",
    originalEnqueueTime: attributes.enqueuedTimeUtc,
    deliveryCount: attributes.deliveryCount,
    body: payload
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <!-- Log for analysis -->
                <logger level="WARN"
                    message="DLQ Message: #[payload.messageId] - Reason: #[payload.deadLetterReason]" />

                <!-- Store in database for investigation -->
                <db:insert config-ref="Database_Config"
                    doc:name="Store DLQ Record">
                    <db:sql><![CDATA[INSERT INTO dlq_messages (message_id, reason, description, body, received_at)
VALUES (:messageId, :reason, :description, :body, NOW())]]></db:sql>
                    <db:input-parameters><![CDATA[#[{
    messageId: payload.messageId,
    reason: payload.deadLetterReason,
    description: payload.deadLetterDescription,
    body: write(payload.body, "application/json")
}]]]></db:input-parameters>
                </db:insert>
            </foreach>
        </when>
    </choice>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Build Service Bus message with required properties
fun buildMessage(eventType: String, data: Object, sessionId: String = ""): Object = {
    body: write(data, "application/json"),
    label: eventType,
    correlationId: uuid(),
    (sessionId: sessionId) if (sessionId != ""),
    customProperties: {
        eventType: eventType,
        source: "MuleSoft",
        timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    }
}

// Schedule a message for future delivery
fun scheduleMessage(eventType: String, data: Object, deliverAt: DateTime): Object =
    buildMessage(eventType, data) ++ {
        scheduledEnqueueTimeUtc: deliverAt as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    }
---
{
    immediate: buildMessage("order.created", {orderId: "ORD-001"}),
    scheduled: scheduleMessage("reminder.send", {userId: "U-001"}, now() + |P1D|)
}
```

### Gotchas

- **Peek-Lock timeout** — Default lock duration is 30 seconds. If your processing exceeds this, the message becomes visible to other consumers. Configure `lockRenewalConfig` to automatically extend the lock, or increase the queue's lock duration in Azure Portal (max 5 minutes)
- **Session queues block per session** — When using sessions, a consumer that accepts a session holds exclusive access to that session until it closes or the session lock expires. If one consumer is slow, messages for that session wait, while other sessions are processed in parallel
- **Dead letter reason codes** — Service Bus dead-letters for: `MaxDeliveryCountExceeded`, `HeaderSizeExceeded`, `MessageLockLost`, `SessionLockLost`, and TTL expiry. Your DLQ processor should handle each differently
- **Topic subscription filters** — SQL-like filters on topic subscriptions reduce unnecessary message delivery. Without filters, every subscription receives every message published to the topic. Create filters in Azure Portal or via ARM templates
- **Duplicate detection window** — Service Bus can deduplicate messages by `messageId` within a configurable window (default: 10 minutes, max: 7 days). This is set on the queue/topic, not in MuleSoft. Enable it for exactly-once publishing
- **Connection string vs SAS** — The MuleSoft connector supports SAS (Shared Access Signature) authentication. For Azure AD (managed identity) authentication on CloudHub 2.0, you need custom token acquisition similar to the OAuth2 email pattern
- **Premium tier for sessions** — Session-enabled queues require Azure Service Bus Premium tier. Standard tier does not support sessions, partitioning does not work with sessions, and throughput is limited

### Testing

```xml
<munit:test name="azure-sb-session-processing-test"
    description="Verify session messages are processed in order">

    <munit:behavior>
        <munit-tools:mock-when processor="azure-service-bus:complete">
            <munit-tools:then-return>
                <munit-tools:payload value="#[null]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="sessionId" value="customer-001" />
        <set-variable variableName="lockToken" value="lock-abc" />
        <set-variable variableName="sequenceNumber" value="1" />
        <set-payload value='#["{\"orderId\": \"ORD-001\", \"eventType\": \"order.created\", \"data\": {}}"]' />
        <flow-ref name="azure-sb-session-consumer-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="azure-service-bus:complete"
            times="1" />
    </munit:validation>
</munit:test>
```

### Related

- [AWS SQS Reliable Consumer](../aws-sqs-reliable-consumer/) — Equivalent patterns for AWS SQS
- [ServiceNow Incident Lifecycle](../servicenow-incident-lifecycle/) — Event-driven incident automation consuming from Service Bus
