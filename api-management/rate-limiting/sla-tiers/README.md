## SLA-Based Rate Limiting Tiers
> Define Gold/Silver/Bronze rate limits based on client API contracts.

### When to Use
- Monetized APIs with different service levels
- Partner APIs with contractual rate limits
- Internal APIs with priority-based access

### Configuration / Code

**API Manager SLA Tiers:**
```
| Tier     | Requests/min | Requests/day | Approval |
|----------|-------------|--------------|----------|
| Bronze   | 10          | 1,000        | Auto     |
| Silver   | 100         | 50,000       | Auto     |
| Gold     | 1,000       | Unlimited    | Manual   |
```

**Mule 4 SLA policy enforcement:**
```xml
<flow name="sla-protected-api">
    <http:listener config-ref="HTTP_Listener" path="/api/data"/>
    <!-- SLA policy applied via API Manager — no code needed -->
    <!-- Client must pass client_id and client_secret -->
    <logger message="Client: #[attributes.headers.x-client-id] | Tier: #[attributes.headers.x-sla-tier]"/>
</flow>
```

### How It Works
1. Define SLA tiers in API Manager with rate limits per tier
2. Clients register for an API contract and receive client credentials
3. Each request includes `client_id`/`client_secret` (query params or headers)
4. Gateway enforces the rate limit based on the client tier

### Gotchas
- SLA enforcement requires the Rate Limiting - SLA policy (not plain Rate Limiting)
- Client credentials must be passed on every request — use headers, not query params
- Tier changes take effect on the next rate limit window, not immediately
- Monitor `429 Too Many Requests` responses to identify clients hitting limits

### Related
- [Per Client ID](../per-client-id/) — per-client rate limiting
- [Spike Control](../spike-control/) — burst protection
