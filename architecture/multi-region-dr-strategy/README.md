## Multi-Region DR Strategy
> Active-Active and Active-Passive failover patterns for MuleSoft with RTO/RPO targets

### When to Use
- Your integration platform supports business-critical workflows (payments, order processing, healthcare)
- Regulatory or contractual requirements demand specific RTO/RPO targets
- A single-region outage would cause revenue loss or SLA breach
- You are deploying to CloudHub 2.0 or Anypoint Runtime Fabric and need cross-region resilience

### Configuration / Code

#### Architecture: Active-Active vs Active-Passive

```
ACTIVE-ACTIVE (both regions serve traffic simultaneously)

  Users / Consumers
         │
    ┌────┴────┐
    │  DNS /   │   Route 53 weighted routing (50/50)
    │  Traffic │   or latency-based routing
    │  Manager │
    └──┬───┬──┘
       │   │
  ┌────┘   └────┐
  ▼              ▼
┌──────────┐  ┌──────────┐
│ Region A │  │ Region B │
│ (US-East)│  │ (US-West)│
│          │  │          │
│ API GW   │  │ API GW   │
│ Workers  │  │ Workers  │
│ MQ Node  │  │ MQ Node  │
└────┬─────┘  └────┬─────┘
     │              │
     └──────┬───────┘
            │
    ┌───────┴────────┐
    │  Shared State   │
    │  (cross-region  │
    │   DB replication│
    │   or event sync)│
    └────────────────┘

  Pros: Zero failover time, better latency (geo-routing)
  Cons: Data sync complexity, split-brain risk, 2x cost
```

```
ACTIVE-PASSIVE (standby region activates on failure)

  Users / Consumers
         │
    ┌────┴────┐
    │  DNS /   │   Route 53 failover routing
    │  Traffic │   Health check on primary
    │  Manager │
    └──┬───┬──┘
       │   │
  ┌────┘   └──── (failover only) ────┐
  ▼                                   ▼
┌──────────┐                   ┌──────────┐
│ Region A │                   │ Region B │
│ (PRIMARY)│                   │ (STANDBY)│
│          │  ──replication──► │          │
│ API GW   │                   │ API GW   │
│ Workers  │                   │ Workers  │
│ MQ Node  │                   │ (scaled  │
│          │                   │  to min) │
└──────────┘                   └──────────┘

  Pros: Simpler, lower cost (standby at minimal capacity)
  Cons: Failover takes minutes, data loss possible (RPO > 0)
```

#### RTO/RPO Targets by Tier

| Tier | Examples | RTO | RPO | Strategy | Cost Multiplier |
|------|----------|-----|-----|----------|-----------------|
| **Tier 1: Mission-Critical** | Payment processing, real-time order capture | 15 min | 0 (zero data loss) | Active-Active with synchronous replication | 2.2x |
| **Tier 2: Business-Critical** | Customer APIs, inventory sync | 1 hour | 15 min | Active-Passive with async replication | 1.4x |
| **Tier 3: Business-Important** | Reporting, batch ETL, analytics | 4 hours | 1 hour | Active-Passive with periodic snapshots | 1.2x |
| **Tier 4: Non-Critical** | Dev/test environments, internal tools | 24 hours | 24 hours | Single region, backup restore | 1.0x |

#### DNS Failover Configuration (AWS Route 53)

```
Record: api.example.com

  ┌─────────────────────────────────────────────────┐
  │ Route 53 Health Check                            │
  │                                                  │
  │ Target: https://us-east.api.example.com/health   │
  │ Interval: 10 seconds                             │
  │ Failure threshold: 3 consecutive failures         │
  │ Regions: us-east-1, eu-west-1 (checked from both)│
  └─────────────────────────────────────────────────┘

  Routing Policy: Failover
  ┌──────────────────────────────────┐
  │ Primary:  us-east.api.example.com │  ◄── Health check attached
  │ Secondary: us-west.api.example.com│  ◄── Activated when primary unhealthy
  │ TTL: 60 seconds                   │
  └──────────────────────────────────┘

  IMPORTANT: Set DNS TTL to 60s or less. A 300s TTL means clients
  may hit the dead region for up to 5 minutes after failover.
```

#### Anypoint MQ Cross-Region Setup

```
Anypoint MQ does NOT natively replicate across regions.
You must implement cross-region event sync manually:

  Region A (Primary)                    Region B (Standby)
  ┌─────────────────┐                  ┌─────────────────┐
  │ order-events     │                  │ order-events     │
  │ (MQ Queue)       │                  │ (MQ Queue)       │
  └────────┬────────┘                  └────────▲────────┘
           │                                     │
           │     ┌─────────────────────┐         │
           └────►│  MQ Bridge App      │─────────┘
                 │  (reads from A,     │
                 │   publishes to B)   │
                 │  runs in Region A   │
                 └─────────────────────┘

  Bridge App design:
  - Subscribes to source queue in Region A
  - Re-publishes to mirror queue in Region B
  - Uses manual ACK — only ACKs after successful publish to B
  - Tracks message-id to prevent duplicates on restart
  - Runs with max-concurrency=1 to preserve ordering (if needed)
```

```xml
<!-- mq-bridge-flow.xml -->
<flow name="mq-cross-region-bridge" maxConcurrency="1">
    <anypoint-mq:subscriber
        config-ref="mqConfigRegionA"
        destination="order-events"
        acknowledgementMode="MANUAL"
        acknowledgementTimeout="120000"/>

    <try>
        <!-- Publish to Region B -->
        <anypoint-mq:publish
            config-ref="mqConfigRegionB"
            destination="order-events"
            messageId="#[attributes.messageId]">
            <anypoint-mq:body>#[payload]</anypoint-mq:body>
        </anypoint-mq:publish>

        <!-- ACK source only after successful publish to target -->
        <anypoint-mq:ack config-ref="mqConfigRegionA"/>

    <error-handler>
        <on-error-continue type="ANY">
            <anypoint-mq:nack config-ref="mqConfigRegionA"/>
            <logger message="Bridge failed for message: #[attributes.messageId]" level="ERROR"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

#### Health Check Endpoint

```xml
<!-- Every API should expose a /health endpoint for DR monitoring -->
<flow name="health-check">
    <http:listener path="/health" method="GET" config-ref="httpConfig"/>

    <set-variable variableName="checks" value="#[{}]"/>

    <!-- Check database connectivity -->
    <try>
        <db:select config-ref="appDb">
            <db:sql>SELECT 1</db:sql>
        </db:select>
        <set-variable variableName="dbStatus" value="UP"/>
    <error-handler>
        <on-error-continue>
            <set-variable variableName="dbStatus" value="DOWN"/>
        </on-error-continue>
    </error-handler>
    </try>

    <!-- Check Anypoint MQ connectivity -->
    <try>
        <anypoint-mq:publish config-ref="anypointMqConfig"
            destination="health-check-queue">
            <anypoint-mq:body>#["ping"]</anypoint-mq:body>
        </anypoint-mq:publish>
        <set-variable variableName="mqStatus" value="UP"/>
    <error-handler>
        <on-error-continue>
            <set-variable variableName="mqStatus" value="DOWN"/>
        </on-error-continue>
    </error-handler>
    </try>

    <set-payload value='#[output application/json --- {
        status: if (vars.dbStatus == "UP" and vars.mqStatus == "UP") "UP" else "DEGRADED",
        region: p("mule.env.region"),
        timestamp: now() as String,
        checks: {
            database: vars.dbStatus,
            messaging: vars.mqStatus
        }
    }]'/>
</flow>
```

#### Failover Runbook (Condensed)

```
AUTOMATED FAILOVER (DNS-based, Active-Passive):

  1. Health check fails 3 consecutive times (30 seconds)
  2. Route 53 updates DNS to point to standby region
  3. DNS propagation: 60-120 seconds (depends on client TTL caching)
  4. Standby workers auto-scale from minimum to full capacity (2-5 min)
  5. Total failover time: ~3-7 minutes

MANUAL FAILOVER (when automated is too risky):

  1. Ops team receives alert: primary region degraded
  2. Verify: is this a transient issue or region-wide failure?
  3. Decision: initiate failover (requires 2-person approval)
  4. Execute: update DNS, scale standby workers, verify MQ bridge
  5. Validate: smoke tests against standby region
  6. Communicate: notify consumers of region switch
  7. Post-incident: analyze, update runbook, test failback
```

### How It Works
1. **Classify APIs by tier** — not everything needs Active-Active. Over-engineering DR is as harmful as under-engineering it
2. **Deploy to two regions** — primary and secondary, with appropriate replication strategy per tier
3. **Configure DNS failover** — Route 53, Azure Traffic Manager, or Cloudflare with health checks against `/health` endpoints
4. **Bridge Anypoint MQ** — if using events, deploy a cross-region bridge app that mirrors messages
5. **Test regularly** — run game-day exercises quarterly. A DR plan that has never been tested is not a plan
6. **Document the runbook** — who decides to failover, what steps to execute, how to fail back

### Gotchas
- **Split-brain is the worst failure mode.** In Active-Active, if regions lose connectivity to each other but both keep serving traffic, you get conflicting writes. Use conflict resolution strategies: last-write-wins (simple but lossy), CRDTs (complex but correct), or single-writer-per-entity (partition by customer ID)
- **Data sync lag means RPO > 0 for async replication.** If you replicate every 15 seconds and failover happens at second 14, you lose 14 seconds of data. For RPO=0, you need synchronous replication, which adds latency to every write
- **CloudHub region limitations.** CloudHub 1.0 supports limited regions (US, EU, APAC). CloudHub 2.0 on Kubernetes gives more flexibility but requires you to manage the infrastructure. Check current region availability before committing to a DR strategy
- **Do not forget about state.** Stateless APIs failover easily. Stateful components (Object Store, caches, in-flight batch jobs) need explicit handling. Object Store V2 is region-scoped — it does not replicate cross-region
- **Client-side caching defeats fast DNS failover.** If clients cache DNS records beyond the TTL (Java's default is 30s with security manager, forever without), they will keep hitting the dead region. Document client-side TTL requirements
- **Failback is harder than failover.** After the primary region recovers, you need to resync data from the standby region back. Plan for this from day one

### Related
- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — Anypoint MQ patterns that underpin cross-region event sync
- [Application Network Topology](../application-network-topology/) — Identify critical-path APIs that need multi-region DR
- [Integration Maturity Model](../integration-maturity-model/) — Multi-region DR is a Level 4-5 capability
