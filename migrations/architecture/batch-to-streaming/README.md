## Batch Processing to Real-Time Streaming
> Migrate from batch file processing to real-time event streaming

### When to Use
- Nightly batch jobs need to become near-real-time
- Business requires fresher data (minutes instead of hours/days)
- File-based integrations creating operational issues
- Need to process data as it arrives, not in bulk

### Configuration / Code

#### 1. Before: Batch File Processing

```xml
<!-- Batch: poll for file, process all records, write output -->
<flow name="batchOrderFlow">
    <file:listener config-ref="File_Config" directory="/input">
        <scheduling-strategy>
            <cron expression="0 0 2 * * ?" /> <!-- 2 AM daily -->
        </scheduling-strategy>
    </file:listener>

    <batch:job name="processOrders">
        <batch:process-records>
            <batch:step name="validate">
                <validation:is-not-null value="#[payload.orderId]" />
            </batch:step>
            <batch:step name="enrich">
                <http:request config-ref="Customer_API"
                    path="/customers/{id}" method="GET" />
            </batch:step>
            <batch:step name="load">
                <db:insert config-ref="DB_Config">
                    <db:sql>INSERT INTO orders VALUES (:id, :amount)</db:sql>
                </db:insert>
            </batch:step>
        </batch:process-records>
    </batch:job>
</flow>
```

#### 2. After: Real-Time Event Streaming

```xml
<!-- Stream: process each event as it arrives -->
<flow name="streamOrderFlow">
    <anypoint-mq:subscriber config-ref="MQ_Config"
        destination="order-events"
        acknowledgementMode="MANUAL">
        <anypoint-mq:subscriber-ack-config
            acknowledgementTimeout="60000" />
    </anypoint-mq:subscriber>

    <!-- Process individual event -->
    <flow-ref name="validateOrder" />
    <flow-ref name="enrichOrder" />
    <flow-ref name="loadOrder" />

    <anypoint-mq:ack config-ref="MQ_Config"
        ackToken="#[attributes.ackToken]" />
</flow>

<flow name="validateOrder">
    <validation:is-not-null value="#[payload.orderId]"
        message="Order ID is required" />
</flow>

<flow name="enrichOrder">
    <http:request config-ref="Customer_API"
        path="/customers/{id}" method="GET">
        <http:uri-params>#[{ 'id': payload.customerId }]</http:uri-params>
    </http:request>
</flow>

<flow name="loadOrder">
    <db:insert config-ref="DB_Config">
        <db:sql>INSERT INTO orders (id, amount, processed_at)
            VALUES (:id, :amount, :processedAt)</db:sql>
        <db:input-parameters>#[{
            'id': payload.orderId,
            'amount': payload.amount,
            'processedAt': now()
        }]</db:input-parameters>
    </db:insert>
</flow>
```

#### 3. Hybrid: Micro-Batch with Scheduler

```xml
<!-- Compromise: frequent small batches -->
<flow name="microBatchFlow">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <!-- Fetch unprocessed records -->
    <db:select config-ref="Source_DB">
        <db:sql>SELECT * FROM staging WHERE processed = false LIMIT 100</db:sql>
    </db:select>

    <!-- Process batch -->
    <foreach>
        <flow-ref name="processRecord" />
    </foreach>
</flow>
```

### How It Works
1. Batch: accumulates records, processes in bulk on a schedule
2. Streaming: processes each record as it arrives via message queue
3. Micro-batch: hybrid approach with frequent small batches
4. Source systems publish events instead of writing files

### Migration Checklist
- [ ] Identify all batch jobs and their schedules
- [ ] Determine acceptable latency for each (real-time vs near-real-time)
- [ ] Set up event sources (Anypoint MQ, CDC, webhooks)
- [ ] Rewrite batch steps as individual flow processing
- [ ] Implement error handling per-record (not per-batch)
- [ ] Add dead letter queue for failed records
- [ ] Set up monitoring for streaming throughput
- [ ] Run parallel (batch + stream) during transition
- [ ] Verify data completeness
- [ ] Decommission batch jobs

### Gotchas
- Streaming does not guarantee ordering (use FIFO queues if needed)
- Per-record API calls can be slow; use caching for enrichment
- Error handling changes from batch-level to record-level
- Source systems must support event publishing (CDC, webhooks, etc.)
- Total throughput may need horizontal scaling (multiple replicas)

### Related
- [sync-to-event-driven](../sync-to-event-driven/) - Event-driven patterns
- [persistent-queues-to-mq](../../cloudhub/persistent-queues-to-mq/) - MQ setup
