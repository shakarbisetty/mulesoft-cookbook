## VM Queue as Lightweight DLQ
> Use VM queues as an in-app dead letter queue for flows that do not use external messaging.

### When to Use
- HTTP-triggered flows where you want to capture failures without external MQ
- Development and testing environments
- Simple error capture without broker infrastructure

### Configuration / Code

```xml
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="error-dlq" queueType="PERSISTENT" maxOutstandingMessages="1000"/>
    </vm:queues>
</vm:config>

<flow name="api-with-vm-dlq">
    <http:listener config-ref="HTTP_Listener" path="/api/process"/>
    <try>
        <flow-ref name="business-logic"/>
        <error-handler>
            <on-error-continue type="ANY">
                <vm:publish config-ref="VM_Config" queueName="error-dlq">
                    <vm:content>#[output application/json --- {payload: payload, error: error.description, timestamp: now()}]</vm:content>
                </vm:publish>
                <set-variable variableName="httpStatus" value="500"/>
                <set-payload value='{"error":"Processing failed, captured for review"}' mimeType="application/json"/>
            </on-error-continue>
        </error-handler>
    </try>
</flow>

<!-- Separate flow to drain the error queue -->
<flow name="error-reviewer">
    <vm:listener config-ref="VM_Config" queueName="error-dlq"/>
    <logger level="ERROR" message="DLQ message: #[payload]"/>
</flow>
```

### How It Works
1. On error, publish the failed payload + error context to a VM queue
2. A separate VM listener flow processes the error queue (log, alert, or store)
3. `PERSISTENT` queue type survives app restarts (CloudHub)
4. `maxOutstandingMessages` prevents unbounded queue growth

### Gotchas
- VM queues are app-local — not shared across workers unless using persistent queues on CloudHub
- `PERSISTENT` requires Object Store V2 on CloudHub
- VM queues are lost on on-premises app restart unless you use persistent mode
- Not suitable for high-volume error capture — use Anypoint MQ for that

### Related
- [Anypoint MQ DLQ](../anypoint-mq-dlq/) — production-grade DLQ
- [Manual Error Queue](../manual-error-queue/) — enriched error metadata
