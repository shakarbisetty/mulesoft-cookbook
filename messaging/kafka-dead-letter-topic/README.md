## Kafka Dead Letter Topic

> Custom dead letter topic (DLT) implementation with error classification, retry scheduling, and poison pill handling for MuleSoft Kafka consumers.

### When to Use
- Your Kafka consumer encounters messages it cannot process (schema errors, validation failures, downstream outages)
- You need to separate transient failures (retry-safe) from poison pills (permanently unprocessable)
- You want automatic retry scheduling with exponential backoff for transient errors
- You need a complete error classification and audit trail for failed messages

### The Problem
Kafka has no built-in dead letter queue mechanism. When a consumer cannot process a message, the default behavior is: (1) retry indefinitely (blocking the partition), (2) skip the message and commit the offset (losing the message), or (3) crash the consumer (stopping all processing). None of these are acceptable in production. A custom DLT routes failed messages to a separate topic with error metadata, classifies errors to determine retry eligibility, and schedules retries with backoff -- all without blocking the main consumer.

### Configuration

#### Error Classification Utility

```xml
<!--
    Classify errors into categories that determine DLT routing:
    - TRANSIENT: retry later (downstream timeout, rate limit, temp DB error)
    - POISON: never retry (schema error, validation failure, corrupt data)
    - UNKNOWN: needs investigation
-->
<sub-flow name="classify-error">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var errorType = vars.errorType default "UNKNOWN"
var errorMsg = vars.errorMessage default ""

var transientPatterns = [
    "CONNECTIVITY", "TIMEOUT", "SERVICE_UNAVAILABLE",
    "TOO_MANY_REQUESTS", "RETRY_EXHAUSTED", "DB:CONNECTIVITY"
]

var poisonPatterns = [
    "VALIDATION", "EXPRESSION", "TRANSFORMATION",
    "BAD_REQUEST", "UNAUTHORIZED", "NOT_FOUND",
    "JSON:READER", "XML:READER", "SCHEMA"
]

fun matchesAny(value, patterns) =
    patterns some (p) -> value contains p
---
{
    category: if (matchesAny(errorType, transientPatterns)) "TRANSIENT"
              else if (matchesAny(errorType, poisonPatterns)) "POISON"
              else "UNKNOWN",
    errorType: errorType,
    errorMessage: errorMsg,
    retryable: matchesAny(errorType, transientPatterns),
    classifiedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>
```

#### Main Consumer with DLT Routing

```xml
<flow name="kafka-consumer-with-dlt" maxConcurrency="4">
    <kafka:consumer
        config-ref="Kafka_Consumer_Config"
        topic="orders"
        groupId="order-processor"
        offsetCommit="MANUAL">
        <kafka:consumer-config
            autoOffsetReset="EARLIEST"
            maxPollRecords="10" />
    </kafka:consumer>

    <!-- Capture original message metadata -->
    <set-variable variableName="originalTopic" value="#[attributes.topic]" />
    <set-variable variableName="originalPartition" value="#[attributes.partition]" />
    <set-variable variableName="originalOffset" value="#[attributes.offset]" />
    <set-variable variableName="originalKey" value="#[attributes.key]" />
    <set-variable variableName="originalPayload" value="#[payload]" />

    <try>
        <!-- Attempt processing -->
        <flow-ref name="process-order-message" />

        <!-- Success: commit offset -->
        <kafka:commit config-ref="Kafka_Consumer_Config" />

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                    message="Processing failed for P#[vars.originalPartition]:O#[vars.originalOffset] — routing to DLT" />

                <!-- Classify the error -->
                <set-variable variableName="errorType" value="#[error.errorType.asString]" />
                <set-variable variableName="errorMessage" value="#[error.description]" />
                <flow-ref name="classify-error" />

                <set-variable variableName="errorClassification" value="#[payload]" />

                <!-- Route to appropriate DLT -->
                <flow-ref name="route-to-dlt" />

                <!-- Commit offset to move past the failed message -->
                <kafka:commit config-ref="Kafka_Consumer_Config" />
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### DLT Router with Error Category Topics

```xml
<sub-flow name="route-to-dlt">
    <choice>
        <!-- Transient errors: route to retry topic -->
        <when expression="#[vars.errorClassification.category == 'TRANSIENT']">
            <flow-ref name="publish-to-retry-topic" />
        </when>

        <!-- Poison pills: route to poison topic (no retry) -->
        <when expression="#[vars.errorClassification.category == 'POISON']">
            <flow-ref name="publish-to-poison-topic" />
        </when>

        <!-- Unknown errors: route to investigation topic -->
        <otherwise>
            <flow-ref name="publish-to-investigation-topic" />
        </otherwise>
    </choice>
</sub-flow>

<!-- Publish to retry topic with backoff metadata -->
<sub-flow name="publish-to-retry-topic">
    <!-- Calculate retry metadata -->
    <set-variable variableName="retryCount"
        value="#[(vars.originalPayload.retryCount default 0) + 1]" />
    <set-variable variableName="maxRetries" value="#[5]" />

    <choice>
        <!-- Max retries exceeded: promote to poison -->
        <when expression="#[vars.retryCount > vars.maxRetries]">
            <logger level="ERROR"
                message="Max retries (#[vars.maxRetries]) exceeded — promoting to poison topic" />
            <flow-ref name="publish-to-poison-topic" />
        </when>

        <otherwise>
            <!-- Calculate exponential backoff: 30s, 60s, 120s, 240s, 480s -->
            <set-variable variableName="backoffMs"
                value="#[30000 * (2 pow (vars.retryCount - 1))]" />
            <set-variable variableName="retryAfter"
                value="#[(now() as Number {unit: 'milliseconds'}) + vars.backoffMs]" />

            <kafka:publish config-ref="Kafka_Producer_Config"
                topic="orders.retry"
                key="#[vars.originalKey]">
                <kafka:message>
                    <kafka:body><![CDATA[#[output application/json --- {
                        originalPayload: vars.originalPayload,
                        dltMetadata: {
                            originalTopic: vars.originalTopic,
                            originalPartition: vars.originalPartition,
                            originalOffset: vars.originalOffset,
                            errorType: vars.errorClassification.errorType,
                            errorMessage: vars.errorClassification.errorMessage,
                            errorCategory: "TRANSIENT",
                            retryCount: vars.retryCount,
                            maxRetries: vars.maxRetries,
                            retryAfterMs: vars.retryAfter,
                            backoffMs: vars.backoffMs,
                            firstFailedAt: vars.originalPayload.dltMetadata.firstFailedAt
                                default now(),
                            lastFailedAt: now()
                        }
                    }]]]></kafka:body>
                    <kafka:headers><![CDATA[#[{
                        "x-error-category": "TRANSIENT",
                        "x-retry-count": vars.retryCount as String,
                        "x-retry-after": vars.retryAfter as String
                    }]]]></kafka:headers>
                </kafka:message>
            </kafka:publish>

            <logger level="INFO"
                message="Routed to retry topic — attempt #[vars.retryCount], backoff #[vars.backoffMs]ms" />
        </otherwise>
    </choice>
</sub-flow>

<!-- Publish to poison topic (permanent failure) -->
<sub-flow name="publish-to-poison-topic">
    <kafka:publish config-ref="Kafka_Producer_Config"
        topic="orders.poison"
        key="#[vars.originalKey]">
        <kafka:message>
            <kafka:body><![CDATA[#[output application/json --- {
                originalPayload: vars.originalPayload,
                dltMetadata: {
                    originalTopic: vars.originalTopic,
                    originalPartition: vars.originalPartition,
                    originalOffset: vars.originalOffset,
                    errorType: vars.errorClassification.errorType,
                    errorMessage: vars.errorClassification.errorMessage,
                    errorCategory: "POISON",
                    retryCount: vars.retryCount default 0,
                    failedAt: now()
                }
            }]]]></kafka:body>
            <kafka:headers><![CDATA[#[{
                "x-error-category": "POISON",
                "x-original-topic": vars.originalTopic
            }]]]></kafka:headers>
        </kafka:message>
    </kafka:publish>

    <!-- Alert operations team -->
    <http:request config-ref="Alert_API" method="POST" path="/alerts">
        <http:body><![CDATA[#[output application/json --- {
            severity: "HIGH",
            type: "POISON_MESSAGE",
            topic: vars.originalTopic,
            partition: vars.originalPartition,
            offset: vars.originalOffset,
            error: vars.errorClassification.errorMessage,
            timestamp: now()
        }]]]></http:body>
    </http:request>

    <logger level="ERROR"
        message="POISON message routed — topic: #[vars.originalTopic], offset: #[vars.originalOffset]" />
</sub-flow>

<!-- Publish to investigation topic (unknown errors) -->
<sub-flow name="publish-to-investigation-topic">
    <kafka:publish config-ref="Kafka_Producer_Config"
        topic="orders.investigate"
        key="#[vars.originalKey]">
        <kafka:message>
            <kafka:body><![CDATA[#[output application/json --- {
                originalPayload: vars.originalPayload,
                dltMetadata: {
                    originalTopic: vars.originalTopic,
                    originalPartition: vars.originalPartition,
                    originalOffset: vars.originalOffset,
                    errorType: vars.errorClassification.errorType,
                    errorMessage: vars.errorClassification.errorMessage,
                    errorCategory: "UNKNOWN",
                    failedAt: now()
                }
            }]]]></kafka:body>
        </kafka:message>
    </kafka:publish>
</sub-flow>
```

#### Retry Topic Consumer (Scheduled Replay)

```xml
<!--
    Consume from the retry topic and republish to the original topic
    after the backoff period has elapsed.
-->
<flow name="kafka-retry-consumer" maxConcurrency="1">
    <kafka:consumer
        config-ref="Kafka_Consumer_Config"
        topic="orders.retry"
        groupId="retry-scheduler"
        offsetCommit="MANUAL">
        <kafka:consumer-config
            autoOffsetReset="EARLIEST"
            maxPollRecords="50" />
    </kafka:consumer>

    <set-variable variableName="retryMsg" value="#[payload]" />

    <!-- Check if backoff period has elapsed -->
    <set-variable variableName="now"
        value="#[now() as Number {unit: 'milliseconds'}]" />

    <choice>
        <!-- Backoff not elapsed: NACK (put back for later) -->
        <when expression="#[vars.now &lt; (vars.retryMsg.dltMetadata.retryAfterMs default 0)]">
            <logger level="DEBUG"
                message="Retry not due yet — #[(vars.retryMsg.dltMetadata.retryAfterMs - vars.now) / 1000] seconds remaining" />
            <!-- Do not commit — message will be repolled -->
        </when>

        <!-- Backoff elapsed: republish to original topic -->
        <otherwise>
            <logger level="INFO"
                message="Retrying message — attempt #[vars.retryMsg.dltMetadata.retryCount] for #[vars.retryMsg.dltMetadata.originalTopic]" />

            <kafka:publish config-ref="Kafka_Producer_Config"
                topic="#[vars.retryMsg.dltMetadata.originalTopic]"
                key="#[vars.retryMsg.originalPayload.orderId default '']">
                <kafka:message>
                    <kafka:body><![CDATA[#[output application/json --- {
                        (vars.retryMsg.originalPayload),
                        retryCount: vars.retryMsg.dltMetadata.retryCount,
                        dltMetadata: vars.retryMsg.dltMetadata
                    }]]]></kafka:body>
                </kafka:message>
            </kafka:publish>

            <kafka:commit config-ref="Kafka_Consumer_Config" />
        </otherwise>
    </choice>
</flow>
```

#### Poison Topic Dashboard API

```xml
<!--
    API to query poison messages for manual investigation.
-->
<flow name="poison-messages-api">
    <http:listener config-ref="HTTP_Listener"
        path="/api/dlt/poison" method="GET" />

    <!-- Consume recent poison messages (non-destructive via separate group) -->
    <kafka:consume config-ref="Kafka_Consumer_Config"
        topic="orders.poison"
        groupId="poison-dashboard"
        timeout="5000"
        offsetCommit="MANUAL">
        <kafka:consumer-config
            autoOffsetReset="EARLIEST"
            maxPollRecords="100" />
    </kafka:consume>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    poisonMessages: payload map (msg) -> {
        originalTopic: msg.dltMetadata.originalTopic,
        errorType: msg.dltMetadata.errorType,
        errorMessage: msg.dltMetadata.errorMessage,
        failedAt: msg.dltMetadata.failedAt,
        retryAttempts: msg.dltMetadata.retryCount default 0
    },
    totalCount: sizeOf(payload),
    queriedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### Topic Naming Convention

```
Source Topic          | DLT Topics
──────────────────────┼──────────────────────────────
orders                | orders.retry        (transient errors, auto-retry)
                      | orders.poison       (permanent failures, manual fix)
                      | orders.investigate  (unknown errors, needs triage)
──────────────────────┼──────────────────────────────
payments              | payments.retry
                      | payments.poison
                      | payments.investigate
```

### Retry Backoff Schedule

```
Attempt  | Backoff     | Cumulative Wait
─────────┼─────────────┼─────────────────
1        | 30 seconds  | 30 seconds
2        | 60 seconds  | 1.5 minutes
3        | 2 minutes   | 3.5 minutes
4        | 4 minutes   | 7.5 minutes
5        | 8 minutes   | 15.5 minutes
─────────┼─────────────┼─────────────────
6+       | → POISON    | No more retries
```

### Gotchas
- **Committing offset for failed messages**: After routing a failed message to the DLT, you MUST commit the offset on the source topic. Otherwise, the consumer reprocesses the same failing message in an infinite loop. This is the most critical step.
- **Retry topic ordering is not guaranteed**: Messages enter the retry topic at different times with different backoff durations. The retry consumer may process them out of order. If your business logic requires ordering, add a sequence number and reorder in the retry consumer.
- **Retry topic consumer lag with long backoffs**: If most messages have 8-minute backoffs, the retry consumer polls them repeatedly but cannot process them (backoff not elapsed). This creates high consumer lag metrics. Use a separate consumer group for monitoring vs processing.
- **Poison topic retention**: Set a long retention period on poison topics (30+ days) so operations teams have time to investigate. Default Kafka retention (7 days) may be too short for complex debugging.
- **Error classification drift**: As new error types are added (new API endpoints, new connectors), they default to UNKNOWN. Review UNKNOWN errors weekly and update the classification patterns. A growing UNKNOWN category means your classifier is stale.
- **DLT messages are larger than originals**: Each DLT message wraps the original payload with error metadata, roughly doubling the message size. Plan topic partitions and broker storage accordingly.
- **Testing error classification**: Unit test every error type your application can produce against the classifier. A misclassified TRANSIENT error as POISON means permanent message loss. A misclassified POISON as TRANSIENT means infinite retries.
- **Replay from poison topic**: To replay poison messages after fixing the root cause, publish them back to the original topic. Do this with a dedicated replay flow, not by manually resetting consumer group offsets.

### Testing

```xml
<munit:test name="test-transient-error-routes-to-retry"
    description="Verify transient errors are routed to retry topic">

    <munit:behavior>
        <munit-tools:mock-when processor="flow-ref">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="name"
                    whereValue="process-order-message" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:error typeId="HTTP:TIMEOUT" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {orderId: "ORD-001", amount: 100}]' />
        <set-variable variableName="attributes" value="#[{
            topic: 'orders', partition: 0, offset: 42, key: 'ORD-001'
        }]" />
        <flow-ref name="kafka-consumer-with-dlt" />
    </munit:execution>

    <munit:validation>
        <!-- Verify message published to retry topic -->
        <munit-tools:verify-call processor="kafka:publish" times="1">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="topic"
                    whereValue="orders.retry" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>

        <!-- Verify offset was committed (message not reprocessed) -->
        <munit-tools:verify-call processor="kafka:commit" times="1" />
    </munit:validation>
</munit:test>

<munit:test name="test-poison-error-routes-to-poison-topic"
    description="Verify validation errors are routed to poison topic">

    <munit:behavior>
        <munit-tools:mock-when processor="flow-ref">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="name"
                    whereValue="process-order-message" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:error typeId="VALIDATION:INVALID_VALUE" />
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="config-ref"
                    whereValue="Alert_API" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#[{status: 'ok'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {orderId: "BAD", amount: "not-a-number"}]' />
        <set-variable variableName="attributes" value="#[{
            topic: 'orders', partition: 0, offset: 99, key: 'BAD'
        }]" />
        <flow-ref name="kafka-consumer-with-dlt" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="kafka:publish" times="1">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="topic"
                    whereValue="orders.poison" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>
    </munit:validation>
</munit:test>

<munit:test name="test-max-retries-promotes-to-poison"
    description="Verify messages exceeding max retries are promoted to poison">

    <munit:execution>
        <set-variable variableName="originalPayload"
            value='#[{orderId: "ORD-001", retryCount: 5}]' />
        <set-variable variableName="retryCount" value="#[6]" />
        <set-variable variableName="errorClassification"
            value="#[{category: 'TRANSIENT', errorType: 'HTTP:TIMEOUT', errorMessage: 'timeout'}]" />
        <flow-ref name="publish-to-retry-topic" />
    </munit:execution>

    <munit:validation>
        <!-- Should be promoted to poison, not retry -->
        <munit-tools:verify-call processor="kafka:publish" times="1">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="topic"
                    whereValue="orders.poison" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>
    </munit:validation>
</munit:test>
```

### Related Recipes
- [Kafka Exactly-Once](../kafka-exactly-once/) -- exactly-once processing to avoid DLT for duplicates
- [Kafka Rebalance Handling](../kafka-rebalance-handling/) -- rebalance impact on DLT routing
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) -- equivalent pattern for Anypoint MQ
- [EDA Saga Orchestration](../eda-saga-orchestration/) -- saga compensation when DLT messages indicate partial failure
