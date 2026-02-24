## API Analytics Dashboard
> Build custom dashboards in Anypoint Monitoring for API performance and usage visibility.

### When to Use
- Monitoring API health and performance trends
- Tracking API adoption and usage by client
- SLA compliance reporting

### Configuration / Code

**Key dashboard panels:**
```
┌─────────────────────────────────────────────┐
│  API Analytics Dashboard                     │
├──────────────┬──────────────┬───────────────┤
│ Request Rate │ Error Rate   │ Avg Latency   │
│  1,234/min   │   0.5%       │   145ms       │
├──────────────┴──────────────┴───────────────┤
│  Top Clients by Request Volume              │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓ partner-a (45%)           │
│  ▓▓▓▓▓▓▓▓▓ mobile-app (30%)               │
│  ▓▓▓▓▓ web-app (25%)                       │
├─────────────────────────────────────────────┤
│  Response Time Distribution (p50/p95/p99)   │
│  p50: 45ms  |  p95: 250ms  |  p99: 890ms  │
└─────────────────────────────────────────────┘
```

**Anypoint Monitoring query examples:**
```
# Request rate by status code
rate(http_requests_total{api="orders-api"}[5m])

# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{api="orders-api"}[5m]))
```

### How It Works
1. Anypoint Monitoring automatically collects API metrics
2. Custom dashboards visualize request rates, errors, and latency
3. Filters allow drilling down by API, version, client, and environment
4. Alerts trigger on threshold breaches (error rate > 5%, latency > 1s)

### Gotchas
- Dashboard data retention varies by subscription tier (7 days to 90 days)
- High-cardinality labels (per-request-id) are not suitable for dashboards
- Custom dashboards do not auto-refresh — set the refresh interval
- Export dashboard configs for version control and replication across environments

### Related
- [Custom Metrics Connector](../custom-metrics-connector/) — pushing custom metrics
- [Error Rate Alerts](../error-rate-alerts/) — alerting setup
