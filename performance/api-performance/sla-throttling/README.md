## SLA-Based Throttling
> Queue excess requests instead of rejecting, with configurable wait windows.

### When to Use
- Premium API tiers with guaranteed throughput
- Spiky traffic that can be smoothed with queuing
- You prefer queuing over immediate rejection

### Configuration / Code

```yaml
policyRef:
  name: rate-limiting-sla
config:
  rateLimits:
    - maximumRequests: 50
      timePeriodInMilliseconds: 1000
  delayTimeInMillis: 5000
  delayAttempts: 3
  clusterizable: true
```

### How It Works
1. When rate limit is exceeded, the request is queued for up to `delayTimeInMillis`
2. The gateway retries internally up to `delayAttempts` times
3. If still over limit after delays, returns 429
4. SLA tiers give different clients different limits

### Gotchas
- Delayed requests consume gateway threads — set `delayAttempts` low
- Clients experience higher latency during throttling (not rejection)
- Queue depth can mask backend overload — monitor actual throughput

### Related
- [Rate Limit Sliding Window](../rate-limit-sliding-window/) — reject-based limiting
- [SLA Tiers](../../../api-management/rate-limiting/sla-tiers/) — tier configuration
