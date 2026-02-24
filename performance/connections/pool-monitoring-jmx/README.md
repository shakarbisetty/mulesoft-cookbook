## Connection Pool Monitoring via JMX
> Expose pool metrics through JMX for runtime visibility.

### When to Use
- Production monitoring of connection pool health
- Detecting pool exhaustion before it causes errors
- Dashboarding active/idle/waiting connection counts

### Configuration / Code

```
# Enable JMX agent (JVM args)
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9010
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
```

**Key JMX MBeans:**
| MBean | Metric | Alert Threshold |
|-------|--------|----------------|
| `com.mulesoft.mule.runtime.module.extension:type=HTTP` | Active connections | > 80% of maxActive |
| `com.zaxxer.hikari:type=Pool` | Active, Idle, Waiting | Waiting > 0 sustained |
| `java.lang:type=MemoryPool` | Heap usage | > 85% |

### How It Works
1. JMX agent exposes MBeans for Mule connectors and JVM
2. Monitoring tools (Prometheus JMX Exporter, Datadog) scrape these metrics
3. Set alerts on pool exhaustion (active = max, waiting > 0)

### Gotchas
- JMX on CloudHub is not directly accessible — use Anypoint Monitoring instead
- On-premises deployments can expose JMX on a dedicated port
- Disable JMX authentication only in development — enable in production

### Related
- [Custom Business Metrics](../../monitoring/custom-business-metrics/) — Anypoint Monitoring metrics
- [HTTP Connection Pool](../http-connection-pool/) — pool configuration
