## Horizontal Scaling with Persistent Queues
> Scale to multiple workers with VM persistent queues for workload distribution.

### When to Use
- Single worker cannot handle the load
- You need processing distribution across workers
- Queue-based workload balancing

### Configuration / Code

```xml
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="work-items" queueType="PERSISTENT"/>
    </vm:queues>
</vm:config>

<!-- API receives requests on any worker -->
<flow name="api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/process"/>
    <vm:publish config-ref="VM_Config" queueName="work-items">
        <vm:content>#[payload]</vm:content>
    </vm:publish>
    <set-payload value=accepted mimeType="application/json"/>
    <set-variable variableName="httpStatus" value="202"/>
</flow>

<!-- All workers consume from the shared queue -->
<flow name="worker-flow">
    <vm:listener config-ref="VM_Config" queueName="work-items"/>
    <flow-ref name="process-item"/>
</flow>
```

### How It Works
1. The load balancer distributes HTTP requests across workers
2. Each worker publishes work items to a persistent VM queue
3. The queue is shared across all workers (Object Store V2)
4. VM listeners on all workers consume from the same queue (round-robin)

### Gotchas
- Persistent queues require Object Store V2 (CloudHub)
- In-memory (transient) queues are NOT shared across workers
- Consider Anypoint MQ for higher throughput and better monitoring

### Related
- [MQ Throughput Tuning](../mq-throughput-tuning/) — Anypoint MQ optimization
- [vCore Sizing Matrix](../vcore-sizing-matrix/) — per-worker sizing
