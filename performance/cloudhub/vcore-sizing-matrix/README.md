## vCore Right-Sizing Decision Matrix
> Decision tree for choosing 0.1–4 vCore based on TPS, payload size, and concurrency.

### When to Use
- Planning CloudHub deployment sizing
- Optimizing costs without sacrificing performance

### Configuration / Code

| Metric | 0.1 vCore | 0.5 vCore | 1.0 vCore | 2.0 vCore | 4.0 vCore |
|--------|-----------|-----------|-----------|-----------|-----------|
| TPS | < 5 | 5–20 | 20–50 | 50–100 | 100+ |
| Payload | < 100 KB | < 1 MB | < 10 MB | < 50 MB | < 100 MB |
| Heap | 256 MB | 512 MB | 1 GB | 2 GB | 4 GB |
| Cost | $ | $$ | $$$ | $$$$ | $$$$$ |

**Decision tree:**
1. Start with 0.5 vCore for most APIs
2. If p95 latency > SLA, try 1.0 vCore
3. If batch processing or large payloads, use 2.0+ vCore
4. 0.1 vCore only for health checks, schedulers, low-traffic internal APIs

### Gotchas
- Measure with production-like load — dev traffic is not representative
- vCore affects CPU AND memory — both scale together
- CloudHub 2.0 allows fractional vCore configurations
- Multiple small workers often outperform one large worker for HTTP APIs

### Related
- [Heap Sizing vCore](../../memory/heap-sizing-vcore/) — JVM heap per worker
- [Horizontal Scaling](../horizontal-scaling-queues/) — multi-worker patterns
