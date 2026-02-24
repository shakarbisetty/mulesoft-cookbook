## Spike Control Policy
> Smooth traffic bursts by queuing excess requests instead of rejecting them.

### When to Use
- APIs that receive bursty traffic patterns
- You prefer queuing over immediate rejection (better UX)
- Protecting backends from sudden traffic spikes

### Configuration / Code

```yaml
policyRef:
  name: spike-control
configuration:
  maximumRequests: 100
  timePeriodInMilliseconds: 1000
  delayTimeInMillis: 500
  delayAttempts: 3
  queuingLimit: 50
```

### How It Works
1. Allows `maximumRequests` per `timePeriod` through immediately
2. Excess requests are delayed (queued) for up to `delayAttempts` × `delayTimeInMillis`
3. If still over capacity after delays, requests are rejected with 429
4. `queuingLimit` caps the total number of queued requests

### Gotchas
- Queued requests consume gateway memory — set `queuingLimit` appropriately
- Client timeout may expire while the request is queued — coordinate timeouts
- Spike control adds latency to queued requests — monitor p99 response times
- Unlike rate limiting, spike control smooths traffic rather than hard-capping it

### Related
- [SLA Tiers](../sla-tiers/) — tiered rate limits
- [Sliding vs Fixed Window](../sliding-vs-fixed-window/) — window algorithms
