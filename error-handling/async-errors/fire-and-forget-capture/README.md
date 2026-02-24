## Fire and Forget with Error Capture
> Publish to a VM queue for async processing; the consumer handles its own errors.

### When to Use
- HTTP API needs to respond immediately while processing happens asynchronously
- Async processing errors should be captured without blocking the client
- You want guaranteed processing via persistent VM queues

### Configuration / Code

```xml
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="async-tasks" queueType="PERSISTENT"/>
    </vm:queues>
</vm:config>

<!-- Producer: responds immediately -->
<flow name="api-producer-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/tasks" method="POST"/>
    <vm:publish config-ref="VM_Config" queueName="async-tasks">
        <vm:content>#[payload]</vm:content>
    </vm:publish>
    <set-payload value='{"status":"accepted","message":"Task queued for processing"}' mimeType="application/json"/>
    <set-variable variableName="httpStatus" value="202"/>
</flow>

<!-- Consumer: processes with error handling -->
<flow name="async-consumer-flow">
    <vm:listener config-ref="VM_Config" queueName="async-tasks"/>
    <try>
        <flow-ref name="process-task"/>
        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR" message="Async task failed: #[error.description]"/>
                <os:store key="#['failed-' ++ correlationId]" objectStore="error-store">
                    <os:value>#[output application/json --- {error: error.description, payload: payload, timestamp: now()}]</os:value>
                </os:store>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. The API publishes the task to a persistent VM queue and returns 202 Accepted
2. A separate listener flow consumes and processes tasks asynchronously
3. Errors are caught with `on-error-continue` and stored in Object Store for review
4. The VM queue ensures tasks survive worker restarts

### Gotchas
- Return 202, not 200, to indicate asynchronous processing
- Persistent VM queues require Object Store V2 on CloudHub
- If the consumer flow fails with `on-error-propagate`, the message is redelivered — use `on-error-continue` to prevent loops
- Consider adding a correlation ID header so clients can check task status later

### Related
- [Async Scope Errors](../async-scope-errors/) — inline async error handling
- [VM Queue DLQ](../../dead-letter-queues/vm-queue-dlq/) — VM-based dead letter queue
