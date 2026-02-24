## Distributed Tracing for Bottleneck Detection
> Trace request flow across API layers to find the slowest hop.

### When to Use
- Multi-layer API architecture (experience → process → system)
- Identifying which service contributes most to latency
- SLA compliance investigation

### Configuration / Code

Enable in Runtime Manager or via system properties:
```properties
# Enable distributed tracing
anypoint.platform.config.analytics.agent.enabled=true
anypoint.platform.config.analytics.agent.tracing.enabled=true
```

### How It Works
1. Anypoint Monitoring automatically traces requests across Mule apps
2. Correlation IDs propagate through HTTP headers (`x-correlation-id`)
3. The trace view shows time spent in each service and connector
4. Identify the slowest span and optimize it

### Gotchas
- Requires Anypoint Monitoring (Titanium for full distributed tracing)
- Tracing adds ~1% overhead — negligible for most apps
- External services (non-Mule) need manual trace propagation via headers
- On CloudHub 2.0, use OpenTelemetry export for external tools

### Related
- [Custom Business Metrics](../custom-business-metrics/) — business-level metrics
- [Flow Throughput](../flow-throughput-measurement/) — throughput monitoring
