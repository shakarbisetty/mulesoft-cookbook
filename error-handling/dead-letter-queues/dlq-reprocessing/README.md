## DLQ Reprocessing
> Admin API to read from DLQ, optionally fix messages, and republish to the original queue.

### When to Use
- After fixing a bug that caused messages to fail
- Bulk replay of messages from the dead letter queue
- Admin endpoint for operations teams to trigger reprocessing

### Configuration / Code

```xml
<flow name="dlq-reprocess-admin">
    <http:listener config-ref="Admin_Listener" path="/admin/dlq/reprocess" method="POST"
                   allowedMethods="POST"/>

    <!-- Read batch from DLQ -->
    <anypoint-mq:consume config-ref="MQ_Config" destination="orders-dlq"
                          acknowledgementMode="MANUAL" pollingTime="1000"/>

    <choice>
        <when expression="#[payload != null]">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
var msg = if (payload.originalPayload?) payload.originalPayload else payload
---
msg]]></ee:set-payload>
                </ee:message>
            </ee:transform>
            <!-- Republish to original queue -->
            <anypoint-mq:publish config-ref="MQ_Config" destination="orders-queue"/>
            <anypoint-mq:ack config-ref="MQ_Config"/>
            <set-payload value='{"status":"reprocessed","message":"Message republished to orders-queue"}' mimeType="application/json"/>
        </when>
        <otherwise>
            <set-payload value='{"status":"empty","message":"No messages in DLQ"}' mimeType="application/json"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Admin POSTs to the reprocess endpoint
2. Flow consumes one message from the DLQ with manual acknowledgement
3. Extracts the original payload (unwrapping error metadata if present)
4. Republishes to the source queue for normal processing
5. ACKs the DLQ message on success

### Gotchas
- Protect the admin endpoint with authentication — this moves messages between queues
- Reprocessing a message that still has the original bug will send it right back to the DLQ
- Consider adding a `reprocessed: true` flag to prevent infinite loops
- For bulk replay, wrap in a loop with a batch size limit

### Related
- [Anypoint MQ DLQ](../anypoint-mq-dlq/) — DLQ setup
- [Manual Error Queue](../manual-error-queue/) — enriched error metadata to unwrap
