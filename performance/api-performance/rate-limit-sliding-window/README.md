## Rate Limiting with Sliding Window
> Apply per-client rate limiting using sliding window algorithm.

### When to Use
- Protecting APIs from abuse with per-client quotas
- Fair usage enforcement across API consumers
- SLA-based rate differentiation

### Configuration / Code

Apply via **API Manager** or **Flex Gateway Local Mode**:

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: rate-limiting
spec:
  targetRef:
    kind: ApiInstance
    name: orders-api
  policyRef:
    name: rate-limiting
  config:
    rateLimits:
      - maximumRequests: 100
        timePeriodInMilliseconds: 60000
    keySelector: "#[attributes.headers['x-client-id']]"
    clusterizable: true
    exposeHeaders: true
```

### How It Works
1. Each client identified by `keySelector` gets an independent rate counter
2. The sliding window counts requests in the last 60 seconds
3. When limit is exceeded, returns 429 Too Many Requests with `X-RateLimit-*` headers
4. `clusterizable: true` synchronizes counters across gateway replicas

### Gotchas
- Sliding window is more accurate but uses more memory than fixed window
- Without `clusterizable`, each gateway replica has its own counter (effective limit = N × replicas)
- `keySelector` must return a consistent client identifier

### Related
- [SLA Throttling](../sla-throttling/) — queuing instead of rejecting
- [Per Client ID](../../../api-management/rate-limiting/per-client-id/) — client-specific limits
