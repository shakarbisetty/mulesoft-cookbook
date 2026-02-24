# Messaging Patterns

Production-grade messaging recipes for MuleSoft — covering Anypoint MQ, VM queues, ordering guarantees, and integration with external brokers.

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
