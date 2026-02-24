# Performance Optimization

> 48 recipes for handling large payloads, tuning memory, and maximizing throughput in MuleSoft.

## Categories

| Category | Recipes | Description |
|----------|---------|-------------|
| [streaming/](streaming/) | 5 | Repeatable file store, non-repeatable, in-memory sizing, DB cursors |
| [memory/](memory/) | 5 | Heap sizing, G1GC tuning, leak detection, large payload OOM, metaspace |
| [batch/](batch/) | 5 | Block size, aggregator sizing, max failed records, watermarks, concurrency |
| [connections/](connections/) | 5 | HTTP pools, HikariCP, SFTP pools, timeouts, JMX monitoring |
| [caching/](caching/) | 5 | Cache scope + Object Store, HTTP caching, distributed cache, invalidation |
| [threading/](threading/) | 5 | UBER pool sizing, CPU light vs intensive, maxConcurrency, async back-pressure |
| [api-performance/](api-performance/) | 5 | Rate limiting, SLA throttling, gzip, cursor pagination, content negotiation |
| [database/](database/) | 5 | Bulk insert, upsert, pool sizing by vendor, query timeout, parameterized queries |
| [cloudhub/](cloudhub/) | 5 | vCore sizing, horizontal scaling, MQ throughput, CH2 HPA, worker restart |
| [monitoring/](monitoring/) | 3 | Custom business metrics, distributed tracing, flow throughput measurement |

## Related

- [DataWeave Performance patterns](../dataweave/patterns/15-performance-optimization/) — Lazy evaluation, streaming reduce, parallel chunking

---

Part of [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
