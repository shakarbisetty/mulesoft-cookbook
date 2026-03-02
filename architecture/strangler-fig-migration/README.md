## Strangler Fig Migration
> Incremental legacy replacement with MuleSoft as the routing fabric

### When to Use
- You need to replace a legacy system but cannot do a big-bang cutover
- The legacy system is too large or risky to replace in one release
- You want to migrate functionality incrementally while keeping the system running
- Multiple teams need to work on migration in parallel without conflicts

### The Problem

Big-bang migrations fail. A system that took 10 years to build cannot be reliably replaced in a single release. The risk of regression, data loss, and extended downtime is too high. But running two systems permanently — old and new — doubles the maintenance burden and creates data consistency nightmares.

The strangler fig pattern solves this by incrementally routing traffic from the legacy system to the new system, one capability at a time. MuleSoft acts as the routing facade, directing each request to either the legacy or modern system based on migration progress.

### Configuration / Code

#### Strangler Fig Architecture

```
Phase 1: All traffic to legacy
  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ Consumer │────►│ MuleSoft     │────►│ Legacy   │
  │          │     │ Facade       │     │ System   │
  └──────────┘     └──────────────┘     └──────────┘
                   (transparent proxy)

Phase 2: Some capabilities migrated
  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ Consumer │────►│ MuleSoft     │──┬─►│ Legacy   │  (orders, billing)
  │          │     │ Facade       │  │  │ System   │
  └──────────┘     └──────────────┘  │  └──────────┘
                                     │
                                     └─►┌──────────┐
                                        │ New      │  (customers, products)
                                        │ System   │
                                        └──────────┘

Phase 3: Most capabilities migrated
  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ Consumer │────►│ MuleSoft     │──┬─►│ Legacy   │  (billing only)
  │          │     │ Facade       │  │  │ System   │
  └──────────┘     └──────────────┘  │  └──────────┘
                                     │
                                     └─►┌──────────┐
                                        │ New      │  (everything else)
                                        │ System   │
                                        └──────────┘

Phase 4: Migration complete
  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ Consumer │────►│ MuleSoft     │────►│ New      │
  │          │     │ Facade       │     │ System   │
  └──────────┘     └──────────────┘     └──────────┘
                   (can be removed or
                    kept as API layer)
```

#### Migration Router Configuration

```yaml
# migration-routing.yaml — externalized routing configuration
migration:
  routes:
    # Fully migrated — route to new system
    - path: "/customers/**"
      target: "NEW"
      status: "MIGRATED"
      migratedDate: "2026-01-15"

    - path: "/products/**"
      target: "NEW"
      status: "MIGRATED"
      migratedDate: "2026-02-01"

    # In progress — canary/shadow mode
    - path: "/orders/**"
      target: "CANARY"
      canaryPercent: 10
      status: "CANARY"
      startDate: "2026-02-20"

    # Not started — route to legacy
    - path: "/billing/**"
      target: "LEGACY"
      status: "NOT_STARTED"
      plannedDate: "2026-04-01"

    - path: "/inventory/**"
      target: "LEGACY"
      status: "NOT_STARTED"
      plannedDate: "2026-05-01"
```

#### Facade Router Implementation

```xml
<flow name="strangler-facade-router">
    <http:listener config-ref="HTTPS_Listener" path="/api/*" />

    <!-- Determine routing target based on path -->
    <ee:transform>
        <ee:message>
            <ee:set-variable variableName="routingConfig"><![CDATA[%dw 2.0
output application/java
var path = attributes.requestPath
var routes = p("migration.routes") // loaded from config
var matchedRoute = routes filter (route) ->
    path matches (route.path replace "**" with ".*")
---
if (isEmpty(matchedRoute)) { target: "LEGACY" }
else matchedRoute[0]]]></ee:set-variable>
        </ee:message>
    </ee:transform>

    <choice>
        <!-- Fully migrated: route to new system -->
        <when expression="#[vars.routingConfig.target == 'NEW']">
            <flow-ref name="route-to-new-system" />
        </when>

        <!-- Canary: percentage-based split -->
        <when expression="#[vars.routingConfig.target == 'CANARY']">
            <flow-ref name="route-canary" />
        </when>

        <!-- Shadow: call both, return legacy response, compare -->
        <when expression="#[vars.routingConfig.target == 'SHADOW']">
            <flow-ref name="route-shadow" />
        </when>

        <!-- Default: legacy system -->
        <otherwise>
            <flow-ref name="route-to-legacy-system" />
        </otherwise>
    </choice>
</flow>
```

#### Canary Routing (Percentage-Based Split)

```xml
<sub-flow name="route-canary">
    <!-- Generate random number for percentage split -->
    <set-variable variableName="routeRandom"
                  value="#[randomInt(100)]" />

    <choice>
        <when expression="#[vars.routeRandom &lt; vars.routingConfig.canaryPercent]">
            <!-- Canary traffic goes to new system -->
            <logger level="INFO"
                    message="#['CANARY: Routing to NEW system. Path: ' ++
                    attributes.requestPath]" />
            <flow-ref name="route-to-new-system" />
        </when>
        <otherwise>
            <!-- Remaining traffic stays on legacy -->
            <flow-ref name="route-to-legacy-system" />
        </otherwise>
    </choice>
</sub-flow>
```

#### Shadow Mode (Compare Responses)

```xml
<sub-flow name="route-shadow">
    <!-- Call both systems in parallel -->
    <scatter-gather>
        <route>
            <!-- Legacy — this response is returned to consumer -->
            <flow-ref name="route-to-legacy-system" />
            <set-variable variableName="legacyResponse"
                          value="#[payload]" />
        </route>
        <route>
            <!-- New system — response is compared but NOT returned -->
            <try>
                <flow-ref name="route-to-new-system" />
                <set-variable variableName="newResponse"
                              value="#[payload]" />
            <error-handler>
                <on-error-continue>
                    <set-variable variableName="newResponse"
                                  value="#[{ error: error.description }]" />
                </on-error-continue>
            </error-handler>
            </try>
        </route>
    </scatter-gather>

    <!-- Compare responses asynchronously (don't block the consumer) -->
    <async>
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    path: attributes.requestPath,
    method: attributes.method,
    timestamp: now(),
    legacyStatus: vars.legacyResponse.httpStatus default 200,
    newStatus: vars.newResponse.httpStatus default 200,
    responsesMatch: vars.legacyResponse == vars.newResponse,
    differences: if (vars.legacyResponse != vars.newResponse)
        "MISMATCH_DETECTED" else "MATCH"
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Log comparison for analysis -->
        <anypoint-mq:publish config-ref="Anypoint_MQ"
                             destination="shadow-comparison-log">
            <anypoint-mq:body>#[payload]</anypoint-mq:body>
        </anypoint-mq:publish>
    </async>

    <!-- Return ONLY the legacy response to the consumer -->
    <set-payload value="#[vars.legacyResponse]" />
</sub-flow>
```

#### Backend Routing Flows

```xml
<sub-flow name="route-to-legacy-system">
    <!-- ACL translates to/from legacy format -->
    <http:request config-ref="Legacy_System"
                 path="#[attributes.requestPath]"
                 method="#[attributes.method]">
        <http:body>#[payload]</http:body>
        <http:headers>#[attributes.headers]</http:headers>
    </http:request>
</sub-flow>

<sub-flow name="route-to-new-system">
    <http:request config-ref="New_System"
                 path="#[attributes.requestPath]"
                 method="#[attributes.method]">
        <http:body>#[payload]</http:body>
        <http:headers>#[attributes.headers]</http:headers>
    </http:request>
</sub-flow>
```

#### Migration Progress Dashboard

```
Migration Status Dashboard:
┌─────────────────────────────────────────────────────────────────┐
│ Capability        Target     Traffic %    Status       Date     │
│ ──────────────── ────────── ─────────── ──────────── ──────── │
│ /customers       NEW        100%         MIGRATED     Jan 15   │
│ /products        NEW        100%         MIGRATED     Feb 01   │
│ /orders          CANARY     10% new      IN_PROGRESS  Feb 20   │
│ /billing         LEGACY     0% new       NOT_STARTED  Apr 01   │
│ /inventory       LEGACY     0% new       NOT_STARTED  May 01   │
│                                                                 │
│ Overall: 40% migrated | 10% in canary | 50% on legacy         │
└─────────────────────────────────────────────────────────────────┘
```

#### Migration Phases per Capability

| Phase | Traffic Split | Duration | Exit Criteria |
|-------|--------------|----------|---------------|
| **Shadow** | 100% legacy (new called but ignored) | 2-4 weeks | < 1% response mismatch |
| **Canary** | 5-10% to new system | 1-2 weeks | No errors, latency within 10% |
| **Ramp** | 10% -> 25% -> 50% -> 75% -> 100% | 2-4 weeks | Each step stable for 48 hours |
| **Migrated** | 100% to new system | Permanent | Legacy endpoint decommissioned |

### How It Works

1. **Deploy MuleSoft as a facade** in front of the legacy system — all consumers call the facade
2. **Build the new system** for one capability at a time (start with the least risky)
3. **Enable shadow mode** — call both systems, compare responses, fix mismatches
4. **Switch to canary** — send a small percentage of real traffic to the new system
5. **Ramp up gradually** — increase traffic to the new system as confidence grows
6. **Complete migration** — route 100% to the new system, decommission the legacy capability

### Gotchas

- **Data synchronization is the hardest part.** During migration, both systems may need access to the same data. You need either a shared database, event-driven sync, or a dual-write pattern (with all its consistency risks).
- **Shadow mode doubles your backend load.** Every request calls both legacy and new systems. Ensure both can handle the load. Use shadow mode during off-peak hours if capacity is tight.
- **The facade must be stateless.** If the facade stores routing state, a restart could cause traffic disruption. Use externalized configuration (properties, Object Store, or config server) for routing decisions.
- **Consumer contracts must not change during migration.** The entire point is that consumers are unaware of the migration. If the facade changes the API contract, you have two migrations happening at once.
- **Plan for rollback at every phase.** If the new system fails at 50% canary, you must be able to route 100% back to legacy instantly. Test rollback before you start ramping.
- **Legacy system decommissioning takes longer than expected.** Even after 100% migration, keep the legacy system running (read-only) for 3-6 months for data verification and audit purposes.

### Related

- [Anti-Corruption Layer](../anti-corruption-layer/) — the ACL enables clean routing between legacy and new
- [API Versioning Strategy](../api-versioning-strategy/) — versioning the facade API during migration
- [Hexagonal Architecture](../hexagonal-architecture-mulesoft/) — adapters enable backend swapping
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — circuit break the new system during canary if it fails
