## Connection Pool Sizing by Database Type
> Size pools differently for Oracle (thick connections) vs PostgreSQL (lightweight).

### When to Use
- Multi-database environments with different resource profiles
- Optimizing connection limits per database vendor

### Configuration / Code

| Database | Recommended maxPoolSize | Per-Connection Memory | Notes |
|----------|------------------------|----------------------|-------|
| Oracle | 5–15 | ~20–50 MB | Thick connections; keep pool small |
| MySQL | 20–50 | ~1–5 MB | Lightweight; can have larger pools |
| PostgreSQL | 15–30 | ~5–10 MB | Each connection = OS process |
| SQL Server | 10–25 | ~5–15 MB | Windows auth adds overhead |

**Formula:** `maxPoolSize = (availableConnections / appInstances) * 0.8`

### How It Works
1. Oracle connections are memory-heavy — fewer connections, longer reuse
2. PostgreSQL forks a process per connection — OS limits matter
3. MySQL connections are lightweight — can scale to higher pool sizes
4. Reserve 20% headroom for connection spikes

### Gotchas
- Database-side max_connections limits ALL clients, not just your app
- Monitor `Threads_connected` (MySQL) or `numbackends` (PostgreSQL) to verify
- Connection pool leaks are the #1 cause of pool exhaustion — always close connections

### Related
- [DB HikariCP Pool](../../connections/db-hikaricp-pool/) — pool configuration
- [Pool Monitoring JMX](../../connections/pool-monitoring-jmx/) — runtime monitoring
