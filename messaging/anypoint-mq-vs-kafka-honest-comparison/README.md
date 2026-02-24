## Anypoint MQ vs Kafka — Honest Comparison
> Real throughput, latency, and cost numbers for an informed messaging decision

### When to Use
- You're choosing between Anypoint MQ and Apache Kafka for a new integration
- Stakeholders need data-driven justification for a messaging platform
- You're migrating from one broker to another and need to understand trade-offs
- Architecture review board needs a comparison that isn't vendor marketing

### Configuration / Code

#### Feature-by-Feature Comparison

| Feature | Anypoint MQ | Apache Kafka (self-managed) | Confluent Cloud |
|---------|------------|---------------------------|-----------------|
| **Throughput** | ~1,000 msg/sec per queue | 100,000+ msg/sec per partition | 100,000+ msg/sec |
| **Latency (p50)** | ~50ms | <10ms | ~15ms |
| **Latency (p99)** | ~150ms | <50ms | ~80ms |
| **Message Size Limit** | 10 MB | 1 MB default (configurable to ~10 MB) | 8 MB default |
| **Ordering** | FIFO queues only (~300 msg/sec) | Per-partition ordering | Per-partition ordering |
| **Replay** | 7-day retention, manual requeue | Configurable retention (days/size), offset replay | Same as Kafka |
| **Partitioning** | No native partitioning | Topic partitions (consumer groups) | Same as Kafka |
| **Transactions** | No native transactions | Exactly-once semantics (EOS) | Same as Kafka |
| **Dead Letter Queue** | Built-in DLQ per queue | No native DLQ (app-level) | Built-in DLQ |
| **Ops Overhead** | Zero — fully managed | High — ZooKeeper/KRaft, brokers, monitoring | Low — fully managed |
| **MuleSoft Integration** | Native connector, CloudHub affinity | Kafka connector (community or MuleSoft) | Kafka connector |

#### Cost Comparison

| Scenario | Anypoint MQ | Kafka (self-managed on AWS) | Confluent Cloud |
|----------|------------|---------------------------|-----------------|
| **Cost per message** | $0.001–0.002 | ~$0.0001 at scale | ~$0.0005 |
| **1M messages/day** | ~$1,000–2,000/mo | ~$500–800/mo (3-broker min) | ~$400–600/mo |
| **10M messages/day** | ~$10,000–20,000/mo | ~$800–1,500/mo | ~$2,000–4,000/mo |
| **100M messages/day** | Not practical | ~$2,000–5,000/mo | ~$8,000–15,000/mo |
| **Hidden costs** | None — included in Anypoint Platform license | Ops team, monitoring, storage, cross-AZ traffic | Schema Registry, connectors, ksqlDB |
| **FIFO surcharge** | 2x standard rate | N/A (ordering is free) | N/A |

> **Note on Anypoint MQ pricing**: If you already have an Anypoint Platform subscription with MQ entitlements, the marginal cost per message may be near zero up to your included quota. Check your contract.

#### Decision Matrix

```
START
  │
  ├─ Already on Anypoint Platform with MQ entitlements?
  │   ├─ YES → Volume < 5M msg/day?
  │   │         ├─ YES → Anypoint MQ (simplest, zero ops)
  │   │         └─ NO  → Evaluate Kafka (cost savings at scale)
  │   └─ NO  → Continue ↓
  │
  ├─ Need < 10ms latency?
  │   ├─ YES → Kafka
  │   └─ NO  → Continue ↓
  │
  ├─ Need > 10,000 msg/sec sustained?
  │   ├─ YES → Kafka
  │   └─ NO  → Continue ↓
  │
  ├─ Team has Kafka ops expertise?
  │   ├─ YES → Kafka (lower cost at any volume)
  │   └─ NO  → Continue ↓
  │
  ├─ Want zero operational burden?
  │   ├─ YES → Anypoint MQ or Confluent Cloud
  │   └─ NO  → Kafka self-managed
  │
  └─ Need event streaming (replay, compaction, streams)?
      ├─ YES → Kafka (it's a log, not a queue)
      └─ NO  → Anypoint MQ (simpler queue semantics)
```

### How It Works

1. **Anypoint MQ** is a cloud-native message queue built into the Anypoint Platform. It uses a traditional queue/exchange model — producers publish, consumers acknowledge, messages are removed after processing. It trades raw throughput for operational simplicity and tight MuleSoft integration.

2. **Apache Kafka** is a distributed event streaming platform. It uses an append-only log model — producers append to partitions, consumers track offsets, messages persist based on retention policy. It trades operational complexity for extreme throughput and replay capability.

3. **The fundamental difference**: Anypoint MQ is a **queue** (message consumed = message gone). Kafka is a **log** (messages persist, consumers move through them). This changes everything about replay, consumer patterns, and scaling.

4. **Throughput gap**: Kafka achieves 100x+ throughput because it batches writes to disk sequentially and replicates partitions in parallel. Anypoint MQ is optimized for per-message reliability, not raw throughput.

5. **Latency gap**: Kafka's sequential I/O and zero-copy transfers yield sub-10ms latency. Anypoint MQ's HTTP-based protocol and cloud routing add ~50ms overhead.

6. **Cost crossover**: At low volumes (<1M msg/day), Anypoint MQ wins on total cost of ownership because there's nothing to operate. At high volumes (>10M msg/day), Kafka's per-message cost is 10–20x lower.

### Gotchas
- **Apples to oranges**: Comparing fully-managed Anypoint MQ to self-managed Kafka ignores ops cost. Compare Anypoint MQ to Confluent Cloud for a fair managed-vs-managed comparison.
- **Anypoint MQ throughput is per-queue**: You can scale horizontally by adding queues, but this adds application complexity and loses cross-queue ordering.
- **Kafka "free ordering" isn't free**: You need to design partition keys correctly. Wrong partition keys = hot partitions = ordering violations under load.
- **Anypoint MQ FIFO cost**: FIFO queues cost 2x and cap at ~300 msg/sec. If you need ordered + high throughput, you need Kafka.
- **Kafka consumer lag**: Without operational monitoring (Burrow, Confluent Control Center), consumer lag can silently grow until you have hours of backlog.
- **Vendor lock-in**: Anypoint MQ ties you to MuleSoft. Kafka is open-source but self-managed Kafka ties you to your ops team's expertise.
- **Message size**: Anypoint MQ supports 10 MB natively. Kafka's default is 1 MB — increasing it requires broker and producer config changes and can degrade cluster performance.

### Related
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) — deep dive into FIFO ordering
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) — for in-app vs cross-app decisions
- [Message Ordering Guarantees](../message-ordering-guarantees/) — ordering patterns across all broker types
- [Anypoint MQ Large Payload](../anypoint-mq-large-payload/) — working around message size limits
