# Messaging Patterns

Production-grade messaging recipes for MuleSoft — covering Anypoint MQ, Kafka, JMS/IBM MQ, VM queues, event-driven architecture, and broker selection strategies.

## Recipes

| # | Recipe | Description |
|---|--------|-------------|
| 1 | [Anypoint MQ vs Kafka — Honest Comparison](anypoint-mq-vs-kafka-honest-comparison/) | Real throughput, latency, and cost numbers side by side |
| 2 | [Anypoint MQ FIFO Patterns](anypoint-mq-fifo-patterns/) | FIFO queue setup, prefetch pitfalls, exactly-once processing |
| 3 | [Anypoint MQ DLQ Reprocessing](anypoint-mq-dlq-reprocessing/) | Dead letter queue monitoring, replay, and alert configuration |
| 4 | [Anypoint MQ Large Payload](anypoint-mq-large-payload/) | 10MB limit workarounds — claim check, S3 reference, compression |
| 5 | [Anypoint MQ Circuit Breaker](anypoint-mq-circuit-breaker/) | Consumer circuit breaker for downstream protection |
| 6 | [VM Queue vs Anypoint MQ](vm-queue-vs-anypoint-mq/) | When to use in-app VM queues vs cross-app Anypoint MQ |
| 7 | [Message Ordering Guarantees](message-ordering-guarantees/) | Standard vs FIFO vs partitioned ordering trade-offs |
| 8 | [AMQ Subscriber Scaling](amq-subscriber-scaling/) | Prefetch tuning, maxConcurrency, and horizontal pod scaling |
| 9 | [Kafka Exactly-Once Semantics](kafka-exactly-once/) | Idempotent producer + transactional consumer + Object Store dedup |
| 10 | [Kafka Rebalance Handling](kafka-rebalance-handling/) | Cooperative sticky assignor, offset commit strategy, rebalance resilience |
| 11 | [Kafka Schema Registry Evolution](kafka-schema-registry-evolution/) | Avro schema setup, BACKWARD/FORWARD compatibility, consumer adaptation |
| 12 | [JMS XA Transaction Patterns](jms-xa-transaction-patterns/) | Two-phase commit with JMS + database, deadlock prevention |
| 13 | [JMS IBM MQ Production](jms-ibm-mq-production/) | Backout queues, durable subscriptions, MQ cluster failover |
| 14 | [VM vs AMQ vs JMS Decision Matrix](vm-vs-amq-vs-jms-decision/) | Latency, throughput, persistence, cost comparison across all three |
| 15 | [EDA Saga Orchestration](eda-saga-orchestration/) | Saga pattern with compensating actions across 3+ services |
| 16 | [EDA Event Sourcing](eda-event-sourcing-mulesoft/) | Event store, event replay, and projection rebuilding |
| 17 | [AMQ Batch Consumer](amq-batch-consumer/) | Batch message consumption, bulk acknowledge, error isolation |
| 18 | [Kafka Dead Letter Topic](kafka-dead-letter-topic/) | Custom DLT with error classification, retry scheduling, poison pill handling |

## How to Navigate

Each recipe folder contains a `README.md` with:
- **When to Use** — scenarios where the pattern applies
- **Configuration / Code** — production-grade Mule XML and config
- **How It Works** — step-by-step explanation
- **Gotchas** — common mistakes and edge cases
- **Related** — links to related recipes

## Related Sections

- [Error Handling](../error-handling/) — retry, DLQ, and circuit breaker patterns
- [Performance](../performance/) — threading, connection pools, and batch tuning
- [Architecture](../architecture/) — system design patterns that use messaging
