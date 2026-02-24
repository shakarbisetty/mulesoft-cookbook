## Bulkhead Isolation
> Isolate critical flows from non-critical ones using separate processing strategies.

### When to Use
- A failure storm in one area should not exhaust resources for others
- Critical APIs (payments) must remain responsive even when analytics APIs are overloaded
- You want per-flow resource limits (threads, connections)

### Configuration / Code

```xml
<!-- Critical flow with dedicated concurrency -->
<flow name="payment-api-flow" maxConcurrency="20">
    <http:listener config-ref="HTTP_Listener" path="/api/payments" method="POST"/>
    <flow-ref name="process-payment"/>
</flow>

<!-- Non-critical flow with lower concurrency -->
<flow name="analytics-api-flow" maxConcurrency="5">
    <http:listener config-ref="HTTP_Listener" path="/api/analytics"/>
    <flow-ref name="generate-report"/>
</flow>

<!-- Background flow with minimal concurrency -->
<flow name="notification-flow" maxConcurrency="2">
    <vm:listener config-ref="VM_Config" queueName="notifications"/>
    <try>
        <http:request config-ref="Notification_Service" path="/notify" method="POST"/>
        <error-handler>
            <on-error-continue type="ANY">
                <logger level="WARN" message="Notification failed: #[error.description]"/>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. `maxConcurrency` limits the number of simultaneous executions per flow
2. When a flow hits its limit, additional requests queue (HTTP back-pressure)
3. Critical flows get higher limits; non-critical flows get lower limits
4. A DoS or error storm in analytics cannot consume threads needed by payments

### Gotchas
- `maxConcurrency` applies to the flow source (listener), not individual components
- On CloudHub, all flows share the UBER thread pool — `maxConcurrency` limits concurrent executions, not dedicated threads
- Set `maxConcurrency` based on downstream capacity, not just upstream traffic
- Use separate HTTP listener configs with different ports for physical isolation

### Related
- [Max Concurrency Flow](../../performance/threading/max-concurrency-flow/) — detailed concurrency tuning
- [Async Back-Pressure](../../performance/threading/async-back-pressure/) — async concurrency limits
- [Circuit Breaker](../../retry/circuit-breaker-object-store/) — per-service failure isolation
