## Anypoint MQ Dead Letter Queue
> Configure a DLQ on an Anypoint MQ queue so poison messages route automatically after max delivery attempts.

### When to Use
- Messages that repeatedly fail processing should be quarantined
- You want platform-managed DLQ without custom code
- Poison messages should not block the main queue

### Configuration / Code

Configure in **Anypoint Platform > MQ > Queues**:

| Setting | Value |
|---------|-------|
| Queue Name | `orders-queue` |
| Dead Letter Queue | `orders-dlq` |
| Max Deliveries | `3` |

**Mule flow (consumer):**

```xml
<flow name="orders-consumer">
    <anypoint-mq:subscriber config-ref="MQ_Config" destination="orders-queue"
                            acknowledgementMode="MANUAL"/>
    <try>
        <flow-ref name="process-order"/>
        <anypoint-mq:ack config-ref="MQ_Config"/>
        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR" message="Processing failed: #[error.description]"/>
                <anypoint-mq:nack config-ref="MQ_Config"/>
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Configure the DLQ binding in Anypoint Platform (not in Mule code)
2. When processing fails, NACK the message — MQ redelivers it
3. After `maxDeliveries` NACKs, MQ automatically routes the message to the DLQ
4. Messages in the DLQ retain original headers and body for investigation

### Gotchas
- The DLQ must exist before you bind it — create it first in the MQ admin
- `maxDeliveries` counts include the first delivery, so `3` means 1 original + 2 retries
- DLQ messages have no TTL by default — they stay forever unless you configure one
- Always NACK (not just throw) to trigger the redelivery count

### Related
- [Manual Error Queue](../manual-error-queue/) — custom DLQ with enriched metadata
- [DLQ Reprocessing](../dlq-reprocessing/) — replaying DLQ messages
- [Idempotent Redelivery](../../retry/idempotent-redelivery/) — Mule-side redelivery policy
