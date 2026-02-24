## Per-Client ID Rate Limiting
> Apply individual rate limits per API client using client_id as the key.

### When to Use
- Each client should have its own independent rate limit
- Preventing a single client from consuming all capacity
- Fair usage enforcement across API consumers

### Configuration / Code

```yaml
policyRef:
  name: rate-limiting
configuration:
  keySelector: "#[attributes.headers.client_id]"
  rateLimits:
  - maximumRequests: 100
    timePeriodInMilliseconds: 60000
  clusterizable: true
  exposeHeaders: true
```

### How It Works
1. `keySelector` extracts the client identifier from the request
2. Each unique client_id gets its own rate limit counter
3. `clusterizable: true` shares counters across gateway replicas
4. `exposeHeaders: true` returns `X-RateLimit-Remaining` in the response

### Gotchas
- Missing client_id falls back to a shared "anonymous" bucket
- Distributed counters (clusterizable) add ~2ms latency per check
- Key cardinality matters — 10K unique clients = 10K counters in memory
- Rate limit headers help clients implement backoff strategies

### Related
- [SLA Tiers](../sla-tiers/) — contract-based rate limits
- [Distributed Redis](../distributed-redis/) — Redis-backed counters
