## Idempotent Retry with Redelivery Policy
> Configure redelivery policy on a listener to automatically retry failed messages before routing to error handler.

### When to Use
- Message-driven flows (Anypoint MQ, JMS, VM) that should retry on transient failures
- You want the runtime to manage retry count without custom logic
- Messages that exceed max redeliveries should go to a dead letter queue

### Configuration / Code

```xml
<flow name="mq-consumer-flow">
    <anypoint-mq:subscriber config-ref="MQ_Config" destination="orders-queue">
        <redelivery-policy maxRedeliveryCount="3" useSecureHash="true"/>
    </anypoint-mq:subscriber>

    <db:insert config-ref="Database_Config">
        <db:sql>INSERT INTO orders (id, data) VALUES (:id, :data)</db:sql>
        <db:input-parameters>#[{id: payload.orderId, data: write(payload, "application/json")}]</db:input-parameters>
    </db:insert>

    <anypoint-mq:ack config-ref="MQ_Config"/>

    <error-handler>
        <on-error-propagate type="MULE:REDELIVERY_EXHAUSTED">
            <logger level="ERROR" message="Max redeliveries exceeded for message: #[payload.orderId]"/>
            <!-- Route to DLQ -->
            <anypoint-mq:publish config-ref="MQ_Config" destination="orders-dlq">
                <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
            </anypoint-mq:publish>
            <anypoint-mq:ack config-ref="MQ_Config"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `redelivery-policy` tracks how many times a message has been delivered
2. If the flow throws an error, the message is nacked and redelivered
3. After `maxRedeliveryCount` failures, Mule throws `MULE:REDELIVERY_EXHAUSTED`
4. The exhausted handler routes the poison message to a DLQ and ACKs it

### Gotchas
- `useSecureHash="true"` identifies messages by content hash — if two different messages have the same hash, they share a counter
- The redelivery counter is per-instance; if you have multiple workers, each counts independently
- Always ACK the message in the exhausted handler, or it will be redelivered indefinitely
- Redelivery policy works on the source (listener), not on individual components

### Related
- [Anypoint MQ DLQ](../../dead-letter-queues/anypoint-mq-dlq/) — platform-managed DLQ
- [Until Successful Basic](../until-successful-basic/) — in-flow retry
- [DLQ Reprocessing](../../dead-letter-queues/dlq-reprocessing/) — replaying failed messages
