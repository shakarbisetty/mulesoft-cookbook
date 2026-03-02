## Rate Limiting Architecture
> Multi-tier rate limiting across API gateway, application, and backend layers

### When to Use
- You need to protect backend systems from traffic surges and denial-of-service
- Different API consumers have different usage tiers (free, standard, premium)
- A single abusive client is consuming resources that affect all other clients
- You want to implement fair usage policies without rejecting legitimate traffic

### The Problem

A single layer of rate limiting at the API gateway is insufficient. If the gateway allows 1000 req/min per client but you have 100 clients, the backend receives up to 100,000 req/min — far beyond what most systems can handle. Conversely, if you set the gateway limit too low, legitimate high-volume clients are throttled unnecessarily.

Effective rate limiting requires multiple tiers: per-client limits at the gateway, aggregate limits at the application layer, and backend-specific throttling to protect databases and external APIs from overload.

### Configuration / Code

#### Multi-Tier Rate Limiting Architecture

```
                    ┌─────────────────────────────────────────┐
  Tier 1:           │          API Manager / Gateway          │
  Per-Client        │                                         │
                    │  Client A: 100 req/min (Free tier)      │
                    │  Client B: 1000 req/min (Standard)      │
                    │  Client C: 10000 req/min (Premium)      │
                    │                                         │
                    │  429 Too Many Requests if exceeded       │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
  Tier 2:           │       Application Layer                 │
  Aggregate         │                                         │
                    │  Total incoming: max 5000 req/min       │
                    │  Per-endpoint: /orders max 2000 req/min │
                    │  Burst: allow 2x for 10 seconds         │
                    │                                         │
                    │  503 Service Unavailable if exceeded     │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
  Tier 3:           │       Backend Protection                │
  Per-Backend       │                                         │
                    │  Database: max 500 queries/min           │
                    │  SAP: max 200 calls/min (license limit)  │
                    │  Salesforce: max 100 calls/min (API cap) │
                    │                                         │
                    │  Queue overflow requests                 │
                    └─────────────────────────────────────────┘
```

#### Tier 1: API Manager Rate Limiting

```
API Manager Policy Configuration:

┌─────────────────────────────────────────────────────────────┐
│ Policy: Rate Limiting - SLA Based                          │
│                                                             │
│ SLA Tier: Free                                              │
│   ├── Rate: 100 requests                                    │
│   ├── Period: 1 minute                                      │
│   ├── Expose headers: true                                  │
│   └── Clusterizable: true                                   │
│                                                             │
│ SLA Tier: Standard                                          │
│   ├── Rate: 1000 requests                                   │
│   ├── Period: 1 minute                                      │
│   └── Expose headers: true                                  │
│                                                             │
│ SLA Tier: Premium                                           │
│   ├── Rate: 10000 requests                                  │
│   ├── Period: 1 minute                                      │
│   └── Expose headers: true                                  │
│                                                             │
│ Response headers on rate limit:                              │
│   X-RateLimit-Limit: 1000                                   │
│   X-RateLimit-Remaining: 342                                │
│   X-RateLimit-Reset: 1709136000                             │
└─────────────────────────────────────────────────────────────┘
```

#### RAML SLA Tier Definition

```yaml
# api.raml
#%RAML 1.0
title: Orders API
version: v2

traits:
  rate-limited:
    responses:
      429:
        description: Rate limit exceeded
        headers:
          X-RateLimit-Limit:
            type: integer
            description: Maximum requests per window
          X-RateLimit-Remaining:
            type: integer
            description: Remaining requests in current window
          X-RateLimit-Reset:
            type: integer
            description: Unix timestamp when the window resets
          Retry-After:
            type: integer
            description: Seconds until the client should retry
        body:
          application/json:
            example: |
              {
                "error": "RATE_LIMIT_EXCEEDED",
                "message": "You have exceeded your rate limit of 1000 requests per minute",
                "retryAfter": 23
              }

/orders:
  is: [rate-limited]
  get:
    description: List orders (rate limited per SLA tier)
```

#### Tier 2: Application-Level Aggregate Throttling

```xml
<!-- Application-level rate limiter using Object Store -->
<flow name="aggregate-rate-limiter">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders/*" />

    <!-- Check aggregate rate -->
    <flow-ref name="check-aggregate-rate" />

    <!-- Process request -->
    <apikit:router config-ref="orders-api-config" />
</flow>

<sub-flow name="check-aggregate-rate">
    <set-variable variableName="rateLimitKey"
                  value="#['agg-rate-' ++ now() as String { format: 'yyyy-MM-dd-HH-mm' }]" />

    <!-- Increment counter atomically -->
    <try>
        <os:retrieve key="#[vars.rateLimitKey]"
                     objectStore="Rate_Limit_Store" />
        <set-variable variableName="currentCount"
                      value="#[payload as Number]" />
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <set-variable variableName="currentCount" value="#[0]" />
        </on-error-continue>
    </error-handler>
    </try>

    <choice>
        <when expression="#[vars.currentCount >= p('rate.limit.aggregate')]">
            <!-- Aggregate limit exceeded -->
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "SERVICE_OVERLOADED",
    message: "Service is experiencing high traffic. Please retry.",
    retryAfter: 60 - (now().seconds as Number)
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{
    httpStatus: 503,
    headers: {
        "Retry-After": 60 - (now().seconds as Number)
    }
}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </when>
        <otherwise>
            <!-- Increment counter -->
            <os:store key="#[vars.rateLimitKey]"
                      objectStore="Rate_Limit_Store">
                <os:value>#[vars.currentCount + 1]</os:value>
            </os:store>
        </otherwise>
    </choice>
</sub-flow>

<os:object-store name="Rate_Limit_Store"
                 persistent="false"
                 entryTtl="120"
                 entryTtlUnit="SECONDS" />
```

#### Tier 3: Backend Protection with Queuing

```xml
<!-- Backend rate limiter: queue requests that exceed backend capacity -->
<flow name="backend-protected-sap-call">
    <set-variable variableName="sapRateKey"
                  value="#['sap-rate-' ++ now() as String { format: 'yyyy-MM-dd-HH-mm' }]" />

    <!-- Check SAP rate -->
    <try>
        <os:retrieve key="#[vars.sapRateKey]"
                     objectStore="Backend_Rate_Store" />
        <set-variable variableName="sapCallCount"
                      value="#[payload as Number]" />
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <set-variable variableName="sapCallCount" value="#[0]" />
        </on-error-continue>
    </error-handler>
    </try>

    <choice>
        <when expression="#[vars.sapCallCount &lt; p('rate.limit.sap.perMinute')]">
            <!-- Under limit — call SAP directly -->
            <os:store key="#[vars.sapRateKey]" objectStore="Backend_Rate_Store">
                <os:value>#[vars.sapCallCount + 1]</os:value>
            </os:store>

            <http:request config-ref="SAP_Config" path="#[vars.sapPath]"
                         method="#[vars.sapMethod]" />
        </when>
        <otherwise>
            <!-- Over limit — queue for deferred processing -->
            <anypoint-mq:publish config-ref="Anypoint_MQ"
                                 destination="sap-overflow-queue">
                <anypoint-mq:body>#[write(payload, 'application/json')]</anypoint-mq:body>
            </anypoint-mq:publish>

            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "QUEUED",
    message: "Request queued for processing. SAP rate limit reached.",
    estimatedProcessingTime: "60 seconds"
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 202 }]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </otherwise>
    </choice>
</flow>

<os:object-store name="Backend_Rate_Store"
                 persistent="false"
                 entryTtl="120"
                 entryTtlUnit="SECONDS" />
```

#### Rate Limit Strategy Comparison

| Strategy | Behavior | Best For |
|----------|----------|----------|
| **Fixed window** | Count resets every minute on the clock | Simple, predictable |
| **Sliding window** | Rolling 60-second window | Smoother, no burst at window boundaries |
| **Token bucket** | Tokens refill at steady rate, burst allowed | APIs that need burst tolerance |
| **Leaky bucket** | Requests processed at steady rate, excess queued | Backend protection |
| **Concurrency limit** | Max N simultaneous requests | Thread pool protection |

#### Response Headers Best Practices

```
Successful request (within limits):
  HTTP/1.1 200 OK
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 742
  X-RateLimit-Reset: 1709136060

Rate limited request:
  HTTP/1.1 429 Too Many Requests
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 0
  X-RateLimit-Reset: 1709136060
  Retry-After: 23
  Content-Type: application/json

  {
    "error": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit of 1000 requests per minute exceeded",
    "limit": 1000,
    "remaining": 0,
    "resetAt": "2026-02-28T10:01:00Z",
    "retryAfter": 23
  }
```

### How It Works

1. **Tier 1 (API Manager)** — Per-client rate limiting using SLA tiers. Configured as a policy — no code changes. Protects against individual abusive clients.
2. **Tier 2 (Application)** — Aggregate rate limiting across all clients. Protects the application itself from total overload.
3. **Tier 3 (Backend)** — Per-backend rate limiting. Prevents overwhelming databases, SaaS APIs with their own limits, and legacy systems with low throughput.

### Gotchas

- **API Manager rate limiting is per-worker in CloudHub 1.0.** If you have 2 workers with a 1000/min limit, the effective limit is 2000/min. Use the "Clusterizable" option or switch to CloudHub 2.0 where limits are shared across replicas.
- **Object Store-based counters are not atomic across workers.** Two workers can read the same count, both increment, and both write — losing one count. For precise counting, use an external Redis or database counter. For approximate rate limiting (which is usually fine), Object Store works.
- **Fixed window rate limiting allows 2x burst at window boundaries.** A client can send 1000 requests at 10:00:59 and 1000 more at 10:01:00 — 2000 requests in 2 seconds. Sliding window avoids this but is harder to implement.
- **Salesforce has its own API rate limits.** Even if your Mule app allows 1000 req/min, Salesforce may only allow 100,000 API calls per 24 hours (depending on license). Backend protection must account for external limits.
- **Rate limit headers should use standard names.** Use `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, and `Retry-After` (this one is an official HTTP header).

### Related

- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — circuit breaking when rate limits are consistently hit
- [API-Led Performance Patterns](../api-led-performance-patterns/) — caching reduces load before rate limits apply
- [Zero-Trust API Architecture](../zero-trust-api-architecture/) — rate limiting as a security control
- [API Versioning Strategy](../api-versioning-strategy/) — different rate limits per API version
