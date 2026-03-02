## API-Led Layer Decision Framework
> When to use 1, 2, or 3 layers based on traffic, team size, and integration complexity

### When to Use
- You are starting a new MuleSoft integration and need to decide how many API-led tiers to build
- Your team debates whether the full 3-tier pattern (Experience / Process / System) is necessary
- You want a repeatable decision framework instead of defaulting to 3 tiers every time
- Stakeholders question the added latency and maintenance of extra layers

### The Problem

MuleSoft's API-led connectivity model prescribes three tiers, but applying all three to every integration wastes developer time, adds latency, and inflates API sprawl. Teams either over-architect simple integrations or under-architect complex ones because there is no objective decision framework.

A single database lookup wrapped in three API layers adds ~40ms per hop, triples the deployment surface, and creates three separate CI/CD pipelines for what is fundamentally one operation.

### Configuration / Code

#### Layer Decision Flowchart

```
START: New Integration Requirement
  │
  ├─ How many distinct consumers exist?
  │    1 consumer ──────────────────────────┐
  │    2-3 consumers ───────────────────────┤
  │    4+ consumers with different needs ───┼──► Check Experience Layer Need
  │                                         │
  │   ┌─────────────────────────────────────┘
  │   │
  │   ├─ Do consumers need different data shapes, auth, or SLAs?
  │   │    YES ──► Experience Layer JUSTIFIED
  │   │    NO  ──► Use API Manager policies instead (SLA tiers, response transform)
  │   │
  │   ├─ Is there orchestration, enrichment, or business logic?
  │   │    YES ──► Process Layer JUSTIFIED
  │   │    NO  ──► Skip process layer
  │   │
  │   └─ Does the backend need protocol translation or error normalization?
  │        YES ──► System Layer JUSTIFIED
  │        NO  ──► Direct connector call from the layer above
  │
  └─ RESULT: Build only the justified layers
```

#### Layer Count Decision Matrix

| Factor | 1 Layer | 2 Layers | 3 Layers |
|--------|---------|----------|----------|
| **Consumer count** | 1 internal consumer | 2-3 consumers, similar needs | 4+ consumers, different needs |
| **Team size** | 1-3 developers | 4-8 developers | 8+ developers, multiple squads |
| **Business logic** | None or trivial | Moderate orchestration | Complex multi-system orchestration |
| **Backend complexity** | Single system, modern API | 2-3 systems, mixed protocols | 5+ systems, legacy + modern mix |
| **Reuse requirement** | No reuse needed | Some APIs shared across projects | Enterprise-wide reuse mandate |
| **Latency budget** | < 200ms (tight) | 200-500ms (moderate) | > 500ms (relaxed, batch OK) |
| **Compliance** | None | Basic audit logging | Regulatory (PCI, HIPAA, SOX) |

#### 1-Layer Pattern: Direct Integration

Best for internal tools, single-consumer integrations, and simple CRUD.

```xml
<!-- Single Mule application — no tiers -->
<flow name="orders-api-flow">
    <http:listener config-ref="HTTPS_Listener" path="/api/orders/*" />

    <apikit:router config-ref="orders-api-config" />
</flow>

<flow name="get:\orders:orders-api-config">
    <!-- Directly call backend — no system API indirection -->
    <db:select config-ref="OrdersDB">
        <db:sql>SELECT * FROM orders WHERE status = :status</db:sql>
        <db:input-parameters>#[{ status: attributes.queryParams.status }]</db:input-parameters>
    </db:select>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map {
    orderId: $.order_id,
    customer: $.customer_name,
    total: $.total_amount
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### 2-Layer Pattern: Process + System

Best when you have orchestration logic but consumers are internal or similar.

```
  Consumer ──► Process API ──┬──► System API (SAP)
                             └──► System API (Salesforce)

  Skip experience layer. Apply API Manager policies for
  consumer differentiation (client-id, SLA tiers).
```

```xml
<!-- Process layer: orchestration logic -->
<flow name="prc-order-fulfillment">
    <http:listener config-ref="HTTPS_Listener" path="/api/fulfill" />

    <!-- Enrich order with customer data -->
    <http:request config-ref="sys-salesforce" path="/customers/{custId}" method="GET" />
    <set-variable variableName="customerData" value="#[payload]" />

    <!-- Send to ERP -->
    <http:request config-ref="sys-sap" path="/orders" method="POST">
        <http:body><![CDATA[#[%dw 2.0
output application/json
---
{
    orderRef: vars.orderId,
    customer: vars.customerData.name,
    shipTo: vars.customerData.address
}]]]></http:body>
    </http:request>
</flow>
```

#### 3-Layer Pattern: Full API-Led

Justified only when all three tiers add distinct value.

```
  Mobile App ──► exp-mobile    ──┐
  Web Portal ──► exp-web       ──┼──► prc-order-mgmt ──┬──► sys-sap
  Partner    ──► exp-partner   ──┘                      ├──► sys-salesforce
                                                        └──► sys-inventory-db
  Each experience API has genuinely different:
  - Data shapes (mobile = minimal, web = full, partner = EDI)
  - Auth mechanisms (OAuth, API key, mTLS)
  - Rate limits and SLA tiers
```

#### Traffic-Based Scaling Considerations

| Traffic Pattern | Recommended Approach |
|-----------------|---------------------|
| < 100 req/min | 1 layer — keep it simple |
| 100-1000 req/min | 2 layers — separate concerns for independent scaling |
| > 1000 req/min | 2-3 layers — scale experience layer independently from process |
| Burst traffic (10x spikes) | Add async process layer with Anypoint MQ to absorb bursts |
| Mixed sync + async | 2 layers minimum — sync experience, async process |

#### Team Ownership Model

```
1 Layer:    Team A owns everything
            Simple. Fast. No coordination overhead.

2 Layers:   Team A (consumers) ──► Team B (backends)
            Clear boundary. Team B publishes system API contract.

3 Layers:   Team A (experience) ──► Team B (process) ──► Team C (systems)
            Requires mature API governance. C4E coordinates contracts.
            Only justified with 8+ developers across multiple squads.
```

#### Real-World Examples

| Scenario | Layers | Justification |
|----------|--------|---------------|
| Internal dashboard reads from one DB | 1 | No orchestration, no reuse, single consumer |
| Mobile + web calling the same order service | 2 | Shared process API, API Manager handles consumer differences |
| 50 partners, each with custom EDI formats, calling 5 backend systems | 3 | Genuine per-partner experience APIs, complex orchestration, protocol translation |
| Real-time price lookup (< 100ms SLA) | 1 | Latency budget does not allow multiple hops |
| SAP + Salesforce order orchestration for 3 internal apps | 2 | Process layer justified for orchestration; skip experience (internal consumers) |
| External API monetization platform | 3 | Experience layer handles billing, metering, and per-customer rate plans |

#### Cost Impact Analysis

```
Cost per layer (CloudHub, 0.2 vCore, production):
  1 layer:  $4,800/year  (1 app)
  2 layers: $9,600/year  (2 apps)
  3 layers: $14,400/year (3 apps)

  With HA (2 workers each):
  1 layer:  $9,600/year
  2 layers: $19,200/year
  3 layers: $28,800/year

  Per-project savings by eliminating unnecessary layers:
  Drop 1 layer = $4,800-$9,600/year saved
  Across 10 projects = $48,000-$96,000/year
```

### How It Works

1. **Assess the integration** using the decision matrix — score each factor
2. **Count justified layers** using the flowchart — each layer must add distinct value
3. **Validate with the latency budget** — each hop adds 15-40ms in CloudHub
4. **Check team capacity** — more layers means more repos, CI/CD pipelines, and coordination
5. **Document the decision** — record why you chose N layers for future teams
6. **Review annually** — integrations evolve; a 1-layer design may need a second layer as consumers grow

### Gotchas

- **"We might need it later" is not justification.** Adding a layer takes hours; removing one nobody uses takes weeks of coordination. Start lean.
- **API Manager policies replace most experience layer logic.** Response transformation, rate limiting, SLA tiers, and client-id enforcement are all configurable without code.
- **CloudHub vCores are per-application.** Three layers = 3x the vCore cost minimum. A 0.1 vCore app costs ~$2,400/year.
- **Each layer is a failure point.** Two layers have one network hop that can fail. Three layers have two. Build circuit breakers accordingly.
- **Latency is additive.** Measure actual round-trip latency per hop in your environment. In CloudHub US-East to US-East, expect 10-25ms per internal HTTP call.

### Related

- [API-Led Anti-Patterns](../api-led-anti-patterns/) — what happens when 3 tiers are applied blindly
- [API-Led Performance Patterns](../api-led-performance-patterns/) — eliminating unnecessary hops
- [Orchestration vs Choreography](../orchestration-vs-choreography/) — when the process layer should be an event bus instead
- [Deployment Model Decision Matrix](../deployment-model-decision-matrix/) — where each layer runs
