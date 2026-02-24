## Manual Error Queue
> On failure, publish to an error queue with enriched metadata for investigation and retry.

### When to Use
- You need more context in failed messages than platform DLQ provides
- Error messages should include retry count, error details, and source queue
- Multiple failure modes need different error queues

### Configuration / Code

```xml
<flow name="enriched-dlq-flow">
    <anypoint-mq:subscriber config-ref="MQ_Config" destination="orders-queue"/>
    <try>
        <flow-ref name="process-order"/>
        <error-handler>
            <on-error-continue type="ANY">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    originalPayload: payload,
    errorMetadata: {
        errorType: error.errorType.identifier,
        errorDescription: error.description,
        sourceQueue: "orders-queue",
        failedAt: now(),
        flowName: flow.name,
        correlationId: correlationId,
        retryCount: (vars.retryCount default 0) + 1
    }
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
                <anypoint-mq:publish config-ref="MQ_Config" destination="orders-error-queue"/>
                <logger level="WARN" message="Routed failed message to error queue"/>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. On any processing error, the handler wraps the original payload with error metadata
2. The enriched message is published to a dedicated error queue
3. `on-error-continue` swallows the error so the original message is ACKed (not redelivered)
4. A separate monitoring flow or admin API can inspect the error queue

### Gotchas
- Use `on-error-continue` to ACK the original message; `on-error-propagate` would NACK and cause redelivery loops
- The error metadata payload must be serializable — avoid putting Java objects in it
- Monitor error queue depth to detect systemic failures

### Related
- [Anypoint MQ DLQ](../anypoint-mq-dlq/) — platform-managed DLQ
- [DLQ Reprocessing](../dlq-reprocessing/) — replaying from error queues
- [Slack Webhook Alert](../../notifications/slack-webhook-alert/) — alert on DLQ growth
