## JMS Dead Letter Queue
> Configure JMS connector with DLQ redelivery policy for ActiveMQ or MSK.

### When to Use
- Your Mule app consumes from JMS (ActiveMQ, MSK, IBM MQ)
- The broker should manage dead-letter routing after max redeliveries
- Standard JMS DLQ behavior is sufficient

### Configuration / Code

**ActiveMQ broker config** (`activemq.xml`):
```xml
<policyEntry queue=">" >
    <deadLetterStrategy>
        <individualDeadLetterStrategy queuePrefix="DLQ." useQueueForQueueMessages="true"/>
    </deadLetterStrategy>
</policyEntry>
```

**Mule JMS consumer:**
```xml
<jms:config name="JMS_Config">
    <jms:active-mq-connection>
        <jms:factory-configuration brokerUrl="tcp://activemq:61616"
                                   maxRedelivery="3"/>
    </jms:active-mq-connection>
</jms:config>

<flow name="jms-consumer-flow">
    <jms:listener config-ref="JMS_Config" destination="orders-queue" ackMode="AUTO"/>
    <flow-ref name="process-order"/>
</flow>
```

### How It Works
1. ActiveMQ tracks redelivery count per message
2. After `maxRedelivery` failures, the broker moves the message to `DLQ.orders-queue`
3. With `AUTO` ack mode, failed message processing triggers automatic redelivery
4. The `individualDeadLetterStrategy` creates a separate DLQ per source queue

### Gotchas
- `maxRedelivery` is set on the JMS connection, not the Mule flow
- ActiveMQ's default DLQ is `ActiveMQ.DLQ` (shared) — use `individualDeadLetterStrategy` for per-queue DLQs
- IBM MQ uses `BOTHRESH` and `BOQNAME` for backout queue configuration — different syntax

### Related
- [Anypoint MQ DLQ](../anypoint-mq-dlq/) — cloud-managed alternative
- [VM Queue DLQ](../vm-queue-dlq/) — lightweight in-app DLQ
