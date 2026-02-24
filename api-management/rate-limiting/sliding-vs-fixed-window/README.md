## Sliding Window vs Fixed Window Rate Limiting
> Choose the right rate limiting algorithm for your traffic patterns.

### When to Use
- **Fixed window**: simple, predictable limits (good for most APIs)
- **Sliding window**: smoother enforcement without boundary spikes

### Configuration / Code

**Fixed window (resets every minute):**
```yaml
configuration:
  rateLimits:
  - maximumRequests: 100
    timePeriodInMilliseconds: 60000
```

**Sliding window (rolling 60-second window):**
```yaml
configuration:
  rateLimits:
  - maximumRequests: 100
    timePeriodInMilliseconds: 60000
  windowType: sliding
```

### How It Works
1. **Fixed window**: counter resets at the start of each period (e.g., every minute at :00)
2. A client can make 100 requests at :59 and 100 more at :00 (200 in 2 seconds)
3. **Sliding window**: counts requests in the last 60 seconds from NOW
4. Prevents the boundary burst problem but uses more memory (per-request timestamps)

### Gotchas
- Fixed window is simpler and uses less memory — prefer it unless boundary bursts matter
- Sliding window requires storing individual request timestamps
- In distributed mode, sliding window synchronization is more expensive
- Some policies only support fixed window — check your policy version

### Related
- [Per Client ID](../per-client-id/) — per-client limits
- [Spike Control](../spike-control/) — burst smoothing
