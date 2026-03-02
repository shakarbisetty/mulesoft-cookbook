## Multi-Region Active-Active Blueprint
> Load balancing, data consistency, and failover for active-active MuleSoft deployments

### When to Use
- Your SLA requires 99.99%+ uptime (< 52 minutes downtime per year)
- Users are distributed globally and need low-latency access from multiple regions
- Active-passive failover with 5-15 minute RTO is not acceptable for your business
- You need to survive an entire AWS region outage without service interruption

### The Problem

Active-passive DR gives you a cold (or warm) standby that takes minutes to activate. During failover, requests either queue up or fail. Active-active eliminates this gap by serving traffic from multiple regions simultaneously, but it introduces data consistency challenges, split-brain risks, and complex routing logic that MuleSoft does not solve out of the box.

CloudHub runs in a single AWS region per deployment. To achieve active-active, you need multiple CloudHub deployments behind a global load balancer, with a strategy for shared state.

### Configuration / Code

#### Active-Active Architecture

```
                        ┌─────────────────────┐
                        │  Global DNS / LB     │
                        │  (Route 53, Azure    │
                        │   Front Door, etc.)  │
                        └──────┬──────┬────────┘
                               │      │
             ┌─────────────────┘      └─────────────────┐
             ▼                                          ▼
  ┌──────────────────────┐                ┌──────────────────────┐
  │  Region A (US-East)  │                │  Region B (EU-West)  │
  │                      │                │                      │
  │  ┌────────────────┐  │                │  ┌────────────────┐  │
  │  │ CloudHub Workers│  │                │  │ CloudHub Workers│  │
  │  │ (2+ workers)   │  │                │  │ (2+ workers)   │  │
  │  └───────┬────────┘  │                │  └───────┬────────┘  │
  │          │            │                │          │            │
  │  ┌───────▼────────┐  │                │  ┌───────▼────────┐  │
  │  │ Object Store   │  │   ◄── sync ──► │  │ Object Store   │  │
  │  │ (regional)     │  │                │  │ (regional)     │  │
  │  └────────────────┘  │                │  └────────────────┘  │
  │                      │                │                      │
  │  ┌────────────────┐  │                │  ┌────────────────┐  │
  │  │ Anypoint MQ    │  │   ◄── sync ──► │  │ Anypoint MQ    │  │
  │  │ (regional)     │  │                │  │ (regional)     │  │
  │  └────────────────┘  │                │  └────────────────┘  │
  └──────────────────────┘                └──────────────────────┘
             │                                          │
             ▼                                          ▼
  ┌──────────────────┐                    ┌──────────────────┐
  │ Backend Systems  │   ◄── replication  │ Backend Systems  │
  │ (DB replica,     │        ──►         │ (DB primary or   │
  │  cache, etc.)    │                    │  read replica)   │
  └──────────────────┘                    └──────────────────┘
```

#### Routing Strategies

| Strategy | How It Works | Best For |
|----------|-------------|----------|
| **Geo-proximity** | Route to nearest region based on client IP | Latency-sensitive APIs |
| **Weighted round-robin** | Split traffic 50/50 (or any ratio) across regions | Even load distribution |
| **Latency-based** | Route to region with lowest measured latency | Dynamic performance optimization |
| **Failover** | Primary region handles all traffic; backup on failure | Cost optimization (one region idle) |
| **Geo-fencing** | Force traffic to specific region based on data residency | GDPR, data sovereignty |

#### Global Load Balancer Configuration (AWS Route 53)

```
Route 53 Health Check:
  ┌─────────────────────────────────────────────┐
  │ Check: HTTPS GET /api/health                │
  │ Interval: 10 seconds                        │
  │ Failure threshold: 3 consecutive failures   │
  │ Regions checked from: us-east-1, eu-west-1  │
  └─────────────────────────────────────────────┘

DNS Record (latency-based routing):
  api.company.com
    ├─ A record → us-east-1 DLB (latency policy)
    └─ A record → eu-west-1 DLB (latency policy)

  If us-east-1 health check fails:
    ALL traffic routes to eu-west-1 within 30-60 seconds
```

#### Health Check Endpoint

```xml
<flow name="health-check">
    <http:listener config-ref="HTTPS_Listener" path="/api/health" method="GET" />

    <set-variable variableName="healthy" value="#[true]" />
    <set-variable variableName="checks" value="#[{}]" />

    <!-- Check database connectivity -->
    <try>
        <db:select config-ref="Primary_DB">
            <db:sql>SELECT 1</db:sql>
        </db:select>
        <set-variable variableName="checks"
                      value="#[vars.checks ++ { database: 'UP' }]" />
    <error-handler>
        <on-error-continue>
            <set-variable variableName="healthy" value="#[false]" />
            <set-variable variableName="checks"
                          value="#[vars.checks ++ { database: 'DOWN' }]" />
        </on-error-continue>
    </error-handler>
    </try>

    <!-- Check Anypoint MQ -->
    <try>
        <anypoint-mq:publish config-ref="Anypoint_MQ"
                             destination="health-check-queue">
            <anypoint-mq:body>#[uuid()]</anypoint-mq:body>
        </anypoint-mq:publish>
        <set-variable variableName="checks"
                      value="#[vars.checks ++ { messaging: 'UP' }]" />
    <error-handler>
        <on-error-continue>
            <set-variable variableName="healthy" value="#[false]" />
            <set-variable variableName="checks"
                          value="#[vars.checks ++ { messaging: 'DOWN' }]" />
        </on-error-continue>
    </error-handler>
    </try>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: if (vars.healthy) "UP" else "DOWN",
    region: p("region.name"),
    timestamp: now(),
    checks: vars.checks
}]]></ee:set-payload>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: if (vars.healthy) 200 else 503 }]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</flow>
```

#### Data Consistency Patterns

| Pattern | Consistency | Latency | Complexity | Use Case |
|---------|-------------|---------|------------|----------|
| **Single-writer** | Strong | Higher (cross-region writes) | Low | Financial transactions |
| **Multi-writer with CRDTs** | Eventual | Low | High | Counters, sets, flags |
| **Read-local, write-primary** | Eventual (reads) | Low reads, higher writes | Medium | Read-heavy APIs (catalogs) |
| **Event sourcing** | Eventual | Low | High | Audit-critical systems |

#### Single-Writer Pattern (Recommended Starting Point)

```
Write requests:
  Any Region ──► Route to Primary Region ──► Write to DB
                                              │
                                     async replication
                                              │
                                              ▼
                                    Secondary Region DB (read replica)

Read requests:
  Region A ──► Read from Region A local DB replica
  Region B ──► Read from Region B local DB replica

  Replication lag: typically 50-200ms for managed DB services
  Acceptable for: product catalogs, user profiles, reference data
  NOT acceptable for: inventory counts, account balances, reservations
```

#### Failover Decision Matrix

| Scenario | Detection Time | Failover Action | Data Risk |
|----------|---------------|-----------------|-----------|
| Single worker crash | 0-30s (worker restart) | Automatic — remaining workers handle traffic | None (stateless workers) |
| All workers in region | 30-60s (health check fails) | DNS failover to other region | Inflight requests lost |
| Anypoint MQ regional outage | 30-60s | Switch MQ config to other region | Messages in regional queue delayed |
| Database regional failure | 30-60s | Promote read replica to primary | Up to replication lag of data loss |
| Full AWS region outage | 30-90s | All traffic to surviving region | Combined data + inflight loss |

### How It Works

1. **Deploy identical applications** to both CloudHub regions using the same API definition and configuration (use environment-specific properties for region-aware settings)
2. **Configure a global load balancer** (CloudHub DLB per region + Route 53 or equivalent for global routing)
3. **Implement health checks** that validate all critical dependencies, not just HTTP listener availability
4. **Choose a data consistency pattern** based on your tolerance for eventual consistency
5. **Test failover regularly** — simulate region failures and measure actual RTO/RPO

### Gotchas

- **CloudHub Object Store is regional.** Data stored in Object Store in US-East is NOT available in EU-West. If you need shared state, use an external database with cross-region replication.
- **Anypoint MQ queues are regional.** A message published to a queue in US-East cannot be consumed from EU-West. You need separate queues per region and a cross-region forwarding mechanism for critical messages.
- **DLB certificates must be configured per region.** Each CloudHub region has its own DLB. Certificates, DNS mappings, and URL mappings must be configured independently.
- **API Manager policies are organization-scoped, not region-scoped.** This works in your favor — policies apply regardless of which region serves the request.
- **Cost doubles.** Active-active means you pay for full capacity in both regions. Budget for 2x vCores, 2x Anypoint MQ, and 2x any external services.
- **Split-brain is real.** If the connection between regions fails but both regions stay up, you can have conflicting writes. The single-writer pattern avoids this. Multi-writer requires conflict resolution (last-writer-wins, merge, or manual).

### Related

- [Multi-Region DR Strategy](../multi-region-dr-strategy/) — active-passive failover (simpler, cheaper)
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — trip circuits when a region degrades
- [Deployment Model Decision Matrix](../deployment-model-decision-matrix/) — CloudHub vs RTF for multi-region
- [Zero-Trust API Architecture](../zero-trust-api-architecture/) — securing cross-region communication
