## Distributed Rate Limiting with Redis
> Use Redis as a shared counter store for consistent rate limiting across gateway replicas.

### When to Use
- Multi-replica Flex Gateway deployments
- Accurate rate limiting that cannot be bypassed by hitting different replicas
- High-throughput APIs requiring low-latency counter operations

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: redis-rate-limit
spec:
  targetRef:
    name: orders-api
  policyRef:
    name: rate-limiting
  config:
    rateLimits:
    - maximumRequests: 1000
      timePeriodInMilliseconds: 60000
    clusterizable: true
    clusterConfig:
      type: redis
      address: redis://redis-service:6379
      password: "${REDIS_PASSWORD}"
```

### How It Works
1. Each gateway replica increments a shared Redis counter on each request
2. Redis INCR + EXPIRE provides atomic, TTL-based counting
3. All replicas see the same counter — rate limit is globally enforced
4. Redis latency (~1ms) is acceptable for rate limit checks

### Gotchas
- Redis becomes a single point of failure — use Redis Sentinel or Cluster
- Network partition between gateway and Redis may cause over-admission
- Redis memory grows with the number of unique rate limit keys
- Connection pool to Redis needs tuning for high-throughput gateways

### Related
- [Per Client ID](../per-client-id/) — client-level limits
- [HA Cluster](../../flex-gateway/ha-cluster/) — multi-replica gateway
