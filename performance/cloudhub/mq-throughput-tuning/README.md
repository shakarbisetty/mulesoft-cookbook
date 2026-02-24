## Anypoint MQ Throughput Tuning
> Configure pollingFrequency, fetchSize, and maxConcurrency for MQ consumers.

### When to Use
- Anypoint MQ consumers not processing messages fast enough
- Tuning for high-throughput message processing
- Balancing throughput vs resource usage

### Configuration / Code

```xml
<anypoint-mq:subscriber config-ref="MQ_Config"
                         destination="high-volume-queue"
                         fetchSize="10"
                         fetchTimeout="1000"
                         acknowledgementMode="MANUAL">
    <anypoint-mq:subscriber-polling-frequency frequency="100" timeUnit="MILLISECONDS"/>
</anypoint-mq:subscriber>
```

| Parameter | Default | High Throughput | Low Latency |
|-----------|---------|----------------|-------------|
| fetchSize | 10 | 10 | 1 |
| fetchTimeout | 10000 ms | 1000 ms | 100 ms |
| pollingFrequency | 1000 ms | 100 ms | 50 ms |
| maxConcurrency (flow) | default | 20 | 10 |

### How It Works
1. `fetchSize` controls how many messages are prefetched per poll
2. `fetchTimeout` is how long to wait for messages before returning empty
3. `pollingFrequency` is the delay between polls when no messages are found
4. Flow `maxConcurrency` limits parallel message processing

### Gotchas
- Higher `fetchSize` = better throughput but higher memory per poll
- Very low `pollingFrequency` generates API calls even when queue is empty — costs money
- Always use MANUAL acknowledgement for reliable processing

### Related
- [Horizontal Scaling](../horizontal-scaling-queues/) — multi-worker consumers
- [Anypoint MQ DLQ](../../../error-handling/dead-letter-queues/anypoint-mq-dlq/) — DLQ setup
