## Sync-Async Decision Flowchart
> Thread pool, latency, and reliability trade-offs for choosing synchronous vs. asynchronous integration

### When to Use
- You need to decide whether a new integration should be request-reply or fire-and-forget
- Your synchronous APIs are timing out under load because of slow backends
- Thread pool exhaustion is causing cascading failures across your integration platform
- You want a repeatable framework instead of ad-hoc sync/async decisions

### The Problem

Synchronous integrations block a thread for the entire request lifecycle. A Mule application with 256 threads serving a synchronous API that averages 500ms per request can handle at most 512 requests/second. If any backend slows to 2 seconds, throughput drops to 128 req/s — a 75% reduction from a single slow dependency.

Asynchronous integrations avoid thread blocking but add complexity: message persistence, consumer lag monitoring, dead-letter queue handling, and eventual consistency. Choosing the wrong pattern leads to either thread starvation (sync when async was needed) or unnecessary complexity (async when sync was fine).

### Configuration / Code

#### Decision Flowchart

```
START: New integration requirement
  │
  ├─ Does the consumer need an immediate response with data?
  │    YES ──► Must be SYNC (at least for the consumer-facing call)
  │            │
  │            ├─ Is backend response time < 200ms at P99?
  │            │    YES ──► Pure SYNC — simple and performant
  │            │    NO  ──┐
  │            │          │
  │            │   ├─ Can you return a partial/cached response?
  │            │   │    YES ──► SYNC with CACHE + background async refresh
  │            │   │    NO  ──┐
  │            │   │          │
  │            │   │   └─ Can consumer poll or use webhooks?
  │            │   │        YES ──► SYNC ACK (202) + ASYNC processing
  │            │   │        NO  ──► SYNC with timeout + circuit breaker
  │            │   │
  │            │   └───────────────────────────────────────────────┘
  │            │
  │    NO ──► Consumer does not need immediate data
  │            │
  │            ├─ Is ordering guaranteed delivery required?
  │            │    YES ──► ASYNC with Anypoint MQ (persistent)
  │            │    NO  ──┐
  │            │          │
  │            │   ├─ Is this a notification/event (no reply expected)?
  │            │   │    YES ──► ASYNC fire-and-forget (VM queue or MQ)
  │            │   │    NO  ──► ASYNC with correlation + callback
  │            │   │
  │            └───┘
  │
  └─ RESULT: Apply the identified pattern
```

#### Thread Pool Impact Analysis

```
SYNC SCENARIO — 256 threads, 500ms avg response:
  ┌─────────────────────────────────────────┐
  │  Max throughput = 256 / 0.5 = 512 req/s │
  │                                         │
  │  If backend slows to 2s:                │
  │  Max throughput = 256 / 2.0 = 128 req/s │
  │  ▼ 75% throughput reduction             │
  │                                         │
  │  If backend slows to 10s:               │
  │  Max throughput = 256 / 10 = 25.6 req/s │
  │  ▼ 95% throughput reduction             │
  │  ▲ Thread pool exhaustion imminent      │
  └─────────────────────────────────────────┘

ASYNC SCENARIO — same load:
  ┌─────────────────────────────────────────┐
  │  Producer: publishes to queue in ~5ms   │
  │  Max throughput = 256 / 0.005 = 51,200  │
  │                                         │
  │  Consumer: processes at own pace        │
  │  Backend slowdown = consumer lag grows  │
  │  Producer is UNAFFECTED                 │
  │                                         │
  │  Trade-off: eventual consistency        │
  │  Consumer lag must be monitored         │
  └─────────────────────────────────────────┘
```

#### Trade-Off Matrix

| Factor | Synchronous | Asynchronous |
|--------|-------------|--------------|
| **Latency** | Predictable, end-to-end | Consumer fast, processing delayed |
| **Throughput** | Limited by slowest backend | Limited by queue throughput |
| **Thread usage** | 1 thread blocked per request | Thread released after publish |
| **Error handling** | Immediate error to consumer | Dead-letter queue, retry logic |
| **Data consistency** | Strong (success/fail is clear) | Eventual (must handle lag) |
| **Debugging** | Simple — one request, one trace | Complex — correlate across async hops |
| **Coupling** | Temporal — both systems must be up | Decoupled — queue buffers failures |
| **Backpressure** | Thread pool acts as natural limit | Must configure queue limits |
| **Idempotency** | Usually not needed | Required (at-least-once delivery) |
| **Cost** | Lower (no queue infrastructure) | Higher (Anypoint MQ costs, DLQ monitoring) |

#### Pattern 1: Pure Synchronous (Backend < 200ms)

```xml
<flow name="sync-customer-lookup">
    <http:listener config-ref="HTTPS_Listener" path="/api/customers/{id}" />

    <http:request config-ref="CRM_System" path="/customers/#[attributes.uriParams.id]"
                 method="GET">
        <http:response-validator>
            <http:success-status-code-validator values="200" />
        </http:response-validator>
    </http:request>

    <!-- Response time budget: 15ms (Mule overhead) + 80ms (CRM) = ~95ms -->
</flow>
```

#### Pattern 2: Sync Acknowledgment + Async Processing

```xml
<!-- Consumer-facing: fast acknowledgment -->
<flow name="order-intake-sync">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders" method="POST" />

    <!-- Validate only — no backend calls -->
    <validation:is-not-null value="#[payload.customerId]"
                           message="customerId is required" />

    <!-- Publish to queue — ~5ms -->
    <anypoint-mq:publish config-ref="Anypoint_MQ"
                         destination="order-processing">
        <anypoint-mq:body>#[write(payload, "application/json")]</anypoint-mq:body>
    </anypoint-mq:publish>

    <!-- Return 202 immediately -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    accepted: true,
    trackingId: correlationId,
    statusEndpoint: "/api/orders/status/" ++ correlationId
}]]></ee:set-payload>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 202 }]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</flow>

<!-- Background processor: takes as long as it needs -->
<flow name="order-processor-async">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ"
                            destination="order-processing"
                            acknowledgementMode="MANUAL" />

    <try>
        <!-- Slow operations happen here, no consumer waiting -->
        <http:request config-ref="sys-inventory" path="/reserve" method="POST"
                     responseTimeout="30000" />
        <http:request config-ref="sys-billing" path="/charge" method="POST"
                     responseTimeout="30000" />
        <http:request config-ref="sys-shipping" path="/create" method="POST"
                     responseTimeout="30000" />

        <anypoint-mq:ack />
    <error-handler>
        <on-error-continue>
            <!-- NACK — message goes to DLQ after max redeliveries -->
            <anypoint-mq:nack />
            <logger level="ERROR"
                    message="Order processing failed: #[error.description]" />
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

#### Pattern 3: Async with Callback (Webhook)

```xml
<!-- Async processor notifies consumer when done -->
<flow name="async-report-generator">
    <anypoint-mq:subscriber config-ref="Anypoint_MQ"
                            destination="report-requests" />

    <!-- Generate report (could take minutes) -->
    <flow-ref name="generate-complex-report" />

    <!-- Store result -->
    <os:store key="#['report-' ++ payload.requestId]"
              objectStore="Report_Store">
        <os:value>#[payload]</os:value>
    </os:store>

    <!-- Notify consumer via webhook -->
    <http:request method="POST" url="#[payload.callbackUrl]">
        <http:body>#[%dw 2.0
output application/json
---
{
    requestId: payload.requestId,
    status: "completed",
    downloadUrl: "/api/reports/" ++ payload.requestId
}]</http:body>
    </http:request>
</flow>
```

#### When Sync is Mandatory

Some integration patterns require synchronous communication regardless of latency:

| Scenario | Why Sync is Required |
|----------|---------------------|
| Authentication / token exchange | Consumer cannot proceed without the token |
| Real-time price check | Stale prices cause revenue loss |
| Credit check before order | Business rule requires synchronous approval |
| API Gateway policy enforcement | Must block/allow before proxying |
| Health check / readiness probe | Caller needs immediate status |

### How It Works

1. **Classify the consumer expectation** — does the consumer need data back immediately or just acknowledgment?
2. **Profile the backend** — measure P50, P95, and P99 latency; check for variance under load
3. **Calculate thread impact** — use the formula: `max_throughput = thread_count / avg_response_seconds`
4. **Apply the flowchart** — follow the decision tree to the recommended pattern
5. **Implement monitoring** — for async, monitor consumer lag and DLQ depth; for sync, monitor thread utilization and P99 latency

### Gotchas

- **Anypoint MQ subscriber uses its own thread pool.** The default `maxConcurrency` for a subscriber is 4. If your consumer is slow, messages queue up even with threads available. Tune `maxConcurrency` to match your processing capacity.
- **VM queues are in-memory and per-worker.** Messages are lost on restart. Use VM queues only for transient, non-critical async within a single application. For cross-application or durable async, use Anypoint MQ.
- **The 202 pattern requires a status endpoint.** If you return 202 Accepted, you must provide a way for consumers to check progress. Build a status endpoint backed by Object Store or a database.
- **Async retry without idempotency causes duplicates.** Anypoint MQ delivers at-least-once. If your processor creates a record on each attempt, you get duplicates on retry. Use a unique constraint (order ID, correlation ID) as a dedup key.
- **Thread pool defaults differ by deployment model.** CloudHub workers have 256 threads by default. On-prem Mule runtimes default to `max(cores * 2, 128)`. RTF pods inherit container resource limits.

### Related

- [Orchestration vs Choreography](../orchestration-vs-choreography/) — centralized vs. decentralized control
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — protecting sync calls from slow backends
- [API-Led Performance Patterns](../api-led-performance-patterns/) — reducing latency in sync chains
- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — full async event patterns
