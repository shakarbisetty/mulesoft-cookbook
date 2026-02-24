## Synchronous to Event-Driven Architecture
> Migrate synchronous request-reply integrations to event-driven patterns

### When to Use
- Synchronous API calls create tight coupling
- Need to handle spiky loads with buffering
- Reduce latency for the caller (fire-and-forget)
- Implement eventual consistency patterns

### Configuration / Code

#### 1. Before: Synchronous Chain

```xml
<!-- Tight coupling: caller waits for entire chain -->
<flow name="syncOrderFlow">
    <http:listener config-ref="HTTP" path="/orders" method="POST" />
    <http:request config-ref="Inventory_API" method="POST" path="/reserve" />
    <http:request config-ref="Payment_API" method="POST" path="/charge" />
    <http:request config-ref="Shipping_API" method="POST" path="/schedule" />
    <http:request config-ref="Notification_API" method="POST" path="/email" />
    <!-- Total latency = sum of all calls -->
</flow>
```

#### 2. After: Event-Driven

```xml
<!-- Accept order and publish event -->
<flow name="acceptOrderFlow">
    <http:listener config-ref="HTTP" path="/orders" method="POST" />
    <!-- Validate and accept immediately -->
    <ee:transform>
        <ee:set-payload><![CDATA[%dw 2.0
output application/json
--- { orderId: uuid(), status: "ACCEPTED", timestamp: now() }]]></ee:set-payload>
    </ee:transform>
    <!-- Publish event -->
    <anypoint-mq:publish config-ref="MQ_Config"
        destination="order-events-exchange" />
    <!-- Return immediately to caller -->
</flow>

<!-- Inventory service subscribes -->
<flow name="inventorySubscriber">
    <anypoint-mq:subscriber config-ref="MQ_Config"
        destination="order-inventory-queue" />
    <http:request config-ref="Inventory_API" method="POST" path="/reserve" />
    <anypoint-mq:ack config-ref="MQ_Config" ackToken="#[attributes.ackToken]" />
</flow>

<!-- Payment service subscribes -->
<flow name="paymentSubscriber">
    <anypoint-mq:subscriber config-ref="MQ_Config"
        destination="order-payment-queue" />
    <http:request config-ref="Payment_API" method="POST" path="/charge" />
    <anypoint-mq:ack config-ref="MQ_Config" ackToken="#[attributes.ackToken]" />
</flow>
```

#### 3. Saga Pattern for Distributed Transactions

```xml
<!-- Order saga orchestrator -->
<flow name="orderSagaFlow">
    <anypoint-mq:subscriber config-ref="MQ_Config"
        destination="order-saga-queue" />

    <!-- Step 1: Reserve inventory -->
    <try>
        <http:request config-ref="Inventory_API" path="/reserve" method="POST" />
        <error-handler>
            <on-error-continue>
                <anypoint-mq:publish config-ref="MQ_Config"
                    destination="saga-compensation-queue" />
            </on-error-continue>
        </error-handler>
    </try>

    <!-- Step 2: Charge payment -->
    <try>
        <http:request config-ref="Payment_API" path="/charge" method="POST" />
        <error-handler>
            <on-error-continue>
                <!-- Compensate: release inventory -->
                <http:request config-ref="Inventory_API" path="/release" method="POST" />
                <anypoint-mq:publish config-ref="MQ_Config"
                    destination="saga-compensation-queue" />
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Publisher sends events to Anypoint MQ exchange
2. Multiple subscribers process events independently
3. Caller receives immediate response (accepted, not completed)
4. Saga pattern handles distributed transactions via compensating actions

### Migration Checklist
- [ ] Identify synchronous chains that can be decoupled
- [ ] Design event schema for each business event
- [ ] Create Anypoint MQ queues and exchanges
- [ ] Implement publisher flows (accept + publish)
- [ ] Implement subscriber flows for each service
- [ ] Add dead letter queues for failed processing
- [ ] Implement saga pattern where transactions are needed
- [ ] Add event tracking/correlation for observability
- [ ] Test failure scenarios and compensation logic

### Gotchas
- Event-driven means eventual consistency, not immediate
- Callers must be designed to handle async responses (webhooks, polling)
- Message ordering may not be guaranteed (use FIFO queues if needed)
- Duplicate message handling (idempotency) is essential
- Debugging async flows is harder than synchronous

### Related
- [batch-to-streaming](../batch-to-streaming/) - Real-time processing
- [persistent-queues-to-mq](../../cloudhub/persistent-queues-to-mq/) - Queue migration
- [monolith-to-api-led](../monolith-to-api-led/) - API decomposition
