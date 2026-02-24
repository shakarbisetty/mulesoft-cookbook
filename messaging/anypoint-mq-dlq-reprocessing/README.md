## Anypoint MQ DLQ Reprocessing
> Dead letter queue monitoring, replay patterns, and alert configuration to prevent silent data loss

### When to Use
- Messages are failing processing and landing in a DLQ — you need a strategy to recover them
- You want automated alerting when DLQ depth increases
- You need to distinguish between transient failures (retry-safe) and poison messages (manual intervention)
- Compliance requires proof that no messages are silently dropped

### Configuration / Code

#### DLQ Subscriber — Inspect and Replay

```xml
<!--
    DLQ reprocessing flow.
    Reads from the DLQ, inspects each message, and either:
    1. Re-publishes to the original queue (transient error, now fixed)
    2. Routes to a manual review queue (poison message)
    3. Logs and archives (unrecoverable)
-->
<flow name="dlq-reprocessor" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-dlq"
        acknowledgementMode="MANUAL" />

    <logger level="WARN"
        message="DLQ message: #[attributes.messageId] — delivery count: #[attributes.headers.redeliveryCount default 0]" />

    <!-- Extract failure metadata -->
    <set-variable variableName="originalQueue"
        value="#[attributes.properties.originalQueue default 'orders']" />
    <set-variable variableName="failureReason"
        value="#[attributes.properties.failureReason default 'unknown']" />
    <set-variable variableName="redeliveryCount"
        value="#[attributes.headers.redeliveryCount default 0 as Number]" />

    <choice>
        <!-- Poison message: too many retries -->
        <when expression="#[vars.redeliveryCount > 5]">
            <logger level="ERROR"
                message="Poison message detected: #[attributes.messageId] — routing to manual review" />

            <anypoint-mq:publish
                config-ref="Anypoint_MQ_Config"
                destination="manual-review-queue">
                <anypoint-mq:message>
                    <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
                    <anypoint-mq:properties>
                        <anypoint-mq:property key="originalQueue" value="#[vars.originalQueue]" />
                        <anypoint-mq:property key="failureReason" value="#[vars.failureReason]" />
                        <anypoint-mq:property key="messageId" value="#[attributes.messageId]" />
                        <anypoint-mq:property key="routedAt" value="#[now() as String {format: 'yyyy-MM-dd HH:mm:ss'}]" />
                    </anypoint-mq:properties>
                </anypoint-mq:message>
            </anypoint-mq:publish>

            <anypoint-mq:ack doc:name="ACK after routing to review" />
        </when>

        <!-- Transient error: re-publish to original queue with delay -->
        <otherwise>
            <logger level="INFO"
                message="Re-publishing #[attributes.messageId] to #[vars.originalQueue]" />

            <anypoint-mq:publish
                config-ref="Anypoint_MQ_Config"
                destination="#[vars.originalQueue]">
                <anypoint-mq:message>
                    <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
                    <anypoint-mq:properties>
                        <anypoint-mq:property key="reprocessedFrom" value="dlq" />
                        <anypoint-mq:property key="reprocessedAt"
                            value="#[now() as String {format: 'yyyy-MM-dd HH:mm:ss'}]" />
                        <anypoint-mq:property key="originalMessageId"
                            value="#[attributes.messageId]" />
                    </anypoint-mq:properties>
                </anypoint-mq:message>
            </anypoint-mq:publish>

            <anypoint-mq:ack doc:name="ACK after requeue" />
        </otherwise>
    </choice>
</flow>
```

#### DLQ Depth Monitoring and Alerting

```xml
<!--
    Scheduled flow: check DLQ depth every 5 minutes.
    Alert if depth > 0 (any message in DLQ = something is wrong).
-->
<flow name="dlq-monitor">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <!-- Get DLQ stats via Anypoint MQ Stats API -->
    <http:request
        config-ref="Anypoint_Platform_Config"
        method="GET"
        path="/mq/stats/api/v1/organizations/${anypoint.org.id}/environments/${anypoint.env.id}/regions/${mq.region}/queues/orders-dlq">
        <http:headers>
            <![CDATA[#[{
                "Authorization": "Bearer " ++ vars.accessToken,
                "Content-Type": "application/json"
            }]]]>
        </http:headers>
    </http:request>

    <set-variable variableName="dlqDepth"
        value="#[payload.messagesVisible default 0]" />

    <choice>
        <when expression="#[vars.dlqDepth > 0]">
            <logger level="ERROR"
                message="ALERT: DLQ 'orders-dlq' has #[vars.dlqDepth] messages pending" />

            <!-- Slack webhook alert -->
            <http:request
                config-ref="Slack_Webhook_Config"
                method="POST"
                path="${slack.webhook.path}">
                <http:body><![CDATA[#[output application/json ---
{
    text: ":warning: *DLQ Alert* — `orders-dlq` has " ++ (vars.dlqDepth as String) ++ " messages",
    blocks: [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": ":warning: *Dead Letter Queue Alert*\n" ++
                    "• Queue: `orders-dlq`\n" ++
                    "• Messages: " ++ (vars.dlqDepth as String) ++ "\n" ++
                    "• Time: " ++ (now() as String {format: "yyyy-MM-dd HH:mm:ss z"}) ++ "\n" ++
                    "• Environment: `" ++ p('mule.env') ++ "`"
            }
        }
    ]
}]]]></http:body>
            </http:request>
        </when>
    </choice>
</flow>
```

#### MaxRedelivery Configuration on Source Queue

```xml
<!--
    Source queue configuration with maxDeliveries.
    After 3 failed delivery attempts, messages move to the DLQ.
-->

<!-- Queue creation via Anypoint CLI -->
<!--
anypoint-cli-v4 mq:queue:create \
  -\-region us-east-1 \
  -\-environment Production \
  -\-defaultTtl 604800000 \
  -\-defaultLockTtl 120000 \
  -\-deadLetterQueue orders-dlq \
  -\-maxDeliveries 3 \
  orders
-->

<!-- Consumer with explicit redelivery handling -->
<flow name="orders-processor">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders"
        acknowledgementMode="MANUAL" />

    <try>
        <flow-ref name="process-order" />
        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                    message="Processing failed for #[attributes.messageId]: #[error.description]" />
                <!-- NACK triggers redelivery. After maxDeliveries, goes to DLQ -->
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

### How It Works

1. **DLQ attachment**: When creating a queue in Anypoint MQ, you attach a DLQ by specifying the `deadLetterQueue` name and `maxDeliveries` count. After N failed acknowledgements, the broker moves the message to the DLQ automatically.

2. **Why messages end up in DLQ**: A message reaches the DLQ after it has been delivered `maxDeliveries` times without being acknowledged. This happens when: (a) the consumer NACKs, (b) the lock TTL expires (consumer didn't ACK in time), or (c) the consumer crashes mid-processing.

3. **Reprocessing strategy**: The DLQ reprocessor subscribes to the DLQ, inspects each message, and decides whether to replay (transient error), route to manual review (poison message), or archive (unrecoverable).

4. **Transient vs poison**: Transient errors (downstream timeout, temporary DB outage) are safe to retry after the root cause is fixed. Poison messages (malformed payload, schema violation, business rule error) will fail every time — they need human intervention.

5. **Monitoring cadence**: Check DLQ depth every 5 minutes. Any non-zero depth means something failed. Alert immediately — DLQ messages have TTL, and if they expire before reprocessing, they are lost permanently.

6. **Re-publish preserves nothing**: When you re-publish a DLQ message to the original queue, it gets a new message ID and resets its delivery count. The original message metadata is lost unless you explicitly copy it as message properties.

### Gotchas
- **Poison message infinite loop**: If you blindly re-publish all DLQ messages to the original queue without fixing the root cause, they fail again and return to the DLQ. Always check redelivery count and route poison messages to manual review.
- **DLQ messages have TTL**: DLQ messages inherit the TTL of the source queue (default 7 days). If you don't reprocess within that window, messages are permanently deleted. Set up monitoring on day 1, not after your first data loss incident.
- **maxDeliveries is required**: If you don't configure `maxDeliveries`, failed messages bounce between NACK and redelivery indefinitely, burning subscriber resources and never reaching the DLQ.
- **DLQ is just another queue**: There's nothing magic about a DLQ — it's a standard Anypoint MQ queue. It needs its own subscriber, monitoring, and TTL management.
- **No automatic replay**: Anypoint MQ does not have a built-in "replay all DLQ messages" button. You must build the reprocessor flow yourself (as shown above) or use the Anypoint MQ API to move messages programmatically.
- **FIFO + DLQ interaction**: With FIFO queues, a message going to DLQ unblocks the next message in the FIFO. This means FIFO ordering has a gap — the DLQ'd message is missing from the sequence. Your consumer must handle this gap.
- **Alert fatigue**: Alerting on DLQ depth > 0 every 5 minutes can cause alert storms during outages. Implement escalation: first alert at depth > 0, escalate at depth > 100, page on-call at depth > 1000 or growth rate > 10/min.

### Related
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) — FIFO + DLQ interaction
- [Anypoint MQ Circuit Breaker](../anypoint-mq-circuit-breaker/) — prevent messages from reaching DLQ by stopping consumption
- [Anypoint MQ Large Payload](../anypoint-mq-large-payload/) — large messages may fail deserialization and land in DLQ
- [Message Ordering Guarantees](../message-ordering-guarantees/) — DLQ impact on ordering
