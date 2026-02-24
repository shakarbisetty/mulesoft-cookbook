## CPU-Light vs CPU-Intensive Classification
> Understand which operations run on which thread pool to optimize resource usage.

### When to Use
- Diagnosing thread pool exhaustion
- Understanding why certain operations are slow
- Designing flows for optimal thread usage

### Configuration / Code

**Classification table:**
| Operation | Thread Pool | Blocking? |
|-----------|-----------|-----------|
| Logger | CPU Light | No |
| Set Variable | CPU Light | No |
| Choice Router | CPU Light | No |
| Flow Reference | CPU Light | No |
| DataWeave Transform | CPU Intensive | No |
| Compression/Encryption | CPU Intensive | No |
| HTTP Request | I/O | Yes |
| DB Select/Insert | I/O | Yes |
| File Read/Write | I/O | Yes |
| SFTP/FTP | I/O | Yes |
| Anypoint MQ Publish | I/O | Yes |

### How It Works
1. Mule automatically classifies operations into CPU Light, CPU Intensive, or I/O
2. Thread handoffs happen automatically between pools as the flow executes
3. Each pool has its own size and saturation behavior

### Gotchas
- Groovy/Java scripts run on CPU Intensive by default — blocking I/O in scripts starves this pool
- Custom Java components need `@Processor` annotations to indicate their classification
- Async scope uses CPU Light by default — heavy transforms inside async should be in a sub-flow

### Related
- [UBER Pool Sizing](../uber-pool-sizing/) — pool configuration
- [Max Concurrency Flow](../max-concurrency-flow/) — flow-level limits
