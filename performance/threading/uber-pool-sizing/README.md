## UBER Thread Pool Sizing
> Tune the unified UBER pool via schedulers-pools.conf for on-premises Mule 4.3+.

### When to Use
- On-premises Mule runtime where you control JVM settings
- Default thread pool does not match your workload characteristics
- You need more CPU-intensive threads for heavy transformations

### Configuration / Code

**conf/schedulers-pools.conf:**
```properties
# CPU Light pool (quick, non-blocking operations)
org.mule.runtime.scheduler.cpuLight.threadCount=4

# CPU Intensive pool (DataWeave transforms, encryption)
org.mule.runtime.scheduler.cpuIntensive.threadCount=4

# I/O pool (HTTP requests, DB calls, file operations)
org.mule.runtime.scheduler.io.threadCount.core=4
org.mule.runtime.scheduler.io.threadCount.max=256
org.mule.runtime.scheduler.io.threadKeepAlive=30000
```

### How It Works
1. Mule 4.3+ uses a unified UBER thread pool with three sub-pools
2. CPU Light: quick operations like loggers, set-variable, choice routers
3. CPU Intensive: DataWeave transforms, encryption, compression
4. I/O: blocking operations like HTTP requests, DB queries, file reads

### Gotchas
- This file only works on-premises; CloudHub manages thread pools automatically
- Over-allocating CPU threads on a small vCore wastes context-switching overhead
- Default values are derived from available CPU cores — manual tuning is rarely needed
- Changes require app restart

### Related
- [CPU Light vs Intensive](../cpu-light-vs-intensive/) — operation classification
- [Max Concurrency Flow](../max-concurrency-flow/) — flow-level concurrency
