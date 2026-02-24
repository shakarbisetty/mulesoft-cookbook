## Persistent VM Queues to Anypoint MQ
> Replace Mule persistent VM queues with Anypoint MQ for reliable cross-app messaging

### When to Use
- Migrating from CloudHub 1.0 persistent queues to CloudHub 2.0
- VM persistent queues are used for reliability in current apps
- Need cross-application messaging (VM queues are app-scoped in Mule 4)
- Require message replay, dead letter queues, or message TTL

### Configuration / Code

#### 1. Before: Persistent VM Queue

```xml
<!-- Mule 4 VM with persistent queue -->
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="orders" queueType="PERSISTENT" />
    </vm:queues>
</vm:config>

<flow name="publishFlow">
    <vm:publish config-ref="VM_Config" queueName="orders" />
</flow>

<flow name="consumeFlow">
    <vm:listener config-ref="VM_Config" queueName="orders" />
    <logger message="Processing: #[payload]" />
</flow>
```

#### 2. After: Anypoint MQ

```xml
<!-- Anypoint MQ Configuration -->
<anypoint-mq:config name="Anypoint_MQ_Config">
    <anypoint-mq:connection
        url="${anypoint.mq.url}"
        clientId="${secure::anypoint.mq.clientId}"
        clientSecret="${secure::anypoint.mq.clientSecret}" />
</anypoint-mq:config>

<!-- Publisher flow -->
<flow name="publishFlow">
    <anypoint-mq:publish config-ref="Anypoint_MQ_Config"
        destination="orders-queue">
        <anypoint-mq:body>#[payload]</anypoint-mq:body>
        <anypoint-mq:properties>
            <anypoint-mq:property key="correlationId"
                value="#[correlationId]" />
        </anypoint-mq:properties>
    </anypoint-mq:publish>
</flow>

<!-- Subscriber flow -->
<flow name="consumeFlow">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ_Config"
        destination="orders-queue"
        acknowledgementMode="MANUAL">
        <anypoint-mq:subscriber-ack-config
            acknowledgementTimeout="120000" />
    </anypoint-mq:subscriber>

    <logger message="Processing: #[payload]" />

    <anypoint-mq:ack config-ref="Anypoint_MQ_Config"
        ackToken="#[attributes.ackToken]" />
</flow>
```

#### 3. Create Queue via CLI

```bash
# Create queue
anypoint-cli-v4 anypoint-mq queue create \
    --name "orders-queue" \
    --region us-east-1 \
    --ttl 604800000 \
    --max-deliveries 5 \
    --dead-letter-queue "orders-dlq" \
    --environment "Production" \
    --organization "My Org"

# Create dead letter queue
anypoint-cli-v4 anypoint-mq queue create \
    --name "orders-dlq" \
    --region us-east-1 \
    --ttl 1209600000 \
    --environment "Production" \
    --organization "My Org"

# Create client app for credentials
anypoint-cli-v4 anypoint-mq client-app create \
    --name "orders-app" \
    --environment "Production" \
    --organization "My Org"
```

#### 4. Exchange/FIFO Queue Setup

```bash
# Create exchange (topic-like fan-out)
anypoint-cli-v4 anypoint-mq exchange create \
    --name "orders-exchange" \
    --region us-east-1 \
    --environment "Production"

# Bind queues to exchange
anypoint-cli-v4 anypoint-mq exchange bind \
    --name "orders-exchange" \
    --queue "orders-fulfillment" \
    --environment "Production"

anypoint-cli-v4 anypoint-mq exchange bind \
    --name "orders-exchange" \
    --queue "orders-analytics" \
    --environment "Production"

# Create FIFO queue (guaranteed ordering)
anypoint-cli-v4 anypoint-mq queue create \
    --name "payments-fifo" \
    --fifo \
    --region us-east-1 \
    --environment "Production"
```

### How It Works
1. VM persistent queues store messages on disk within the Mule runtime — lost if the app redeploys
2. Anypoint MQ is a fully managed cloud messaging service independent of the Mule runtime
3. Messages persist in Anypoint MQ across app restarts, redeployments, and scaling events
4. Dead letter queues capture failed messages after max delivery attempts

### Migration Checklist
- [ ] Inventory all VM queues (`queueType="PERSISTENT"`) across applications
- [ ] Create corresponding Anypoint MQ queues and DLQs
- [ ] Create MQ client applications for credentials
- [ ] Replace `vm:publish` with `anypoint-mq:publish`
- [ ] Replace `vm:listener` with `anypoint-mq:subscriber`
- [ ] Add MQ connector dependency to POM
- [ ] Configure acknowledgment mode (AUTO vs MANUAL)
- [ ] Test message flow end-to-end
- [ ] Set up MQ monitoring alerts

### Gotchas
- Anypoint MQ has per-message and per-request costs — review pricing for high-volume queues
- VM queues support request-reply (`vm:publish-consume`); Anypoint MQ is async-only — implement correlation patterns for request-reply
- Message size limit: 10 MB for standard queues — compress or use Object Store for large payloads
- Acknowledgment timeout must exceed your processing time or messages will be redelivered
- FIFO queues have lower throughput than standard queues — only use when ordering matters

### Related
- [ch1-app-to-ch2](../ch1-app-to-ch2/) — Full CloudHub migration
- [sync-to-event-driven](../../architecture/sync-to-event-driven/) — Event-driven patterns
- [properties-to-secure](../properties-to-secure/) — Secure MQ credentials
