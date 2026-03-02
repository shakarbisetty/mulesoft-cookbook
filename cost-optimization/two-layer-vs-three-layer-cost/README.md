# Two-Layer vs Three-Layer Architecture Cost Analysis

## Problem

MuleSoft's API-led connectivity recommends three layers: Experience, Process, and System APIs. Each layer typically runs on its own worker(s), meaning a single integration path requires a minimum of 3 vCores (one per layer). For many use cases, the Process layer adds latency, cost, and complexity without providing meaningful orchestration value. Teams follow the three-layer pattern dogmatically, spending 33-50% more on vCores than necessary while adding 15-30ms of inter-layer latency per hop.

## Solution

A decision framework for when to collapse the three-layer architecture to two layers (Experience + System) by eliminating the Process layer. Includes criteria for when the Process layer provides genuine value, vCore savings calculations, and patterns for merging layers without losing maintainability or reusability.

## Implementation

### When the Process Layer Is Unnecessary

```
Process API is NOT needed when:

  ✓ Experience API calls exactly ONE System API
    (No orchestration = no Process layer value)

  ✓ Transformation is simple field mapping
    (DataWeave in Experience API handles this fine)

  ✓ No cross-system data aggregation
    (Single data source = nothing to compose)

  ✓ No business rules beyond validation
    (Validation belongs in Experience or System, not between them)

  ✓ <50 TPS sustained
    (Extra hop latency hurts more than reuse helps at low volume)
```

```
Process API IS needed when:

  ✗ Orchestrating 2+ System APIs in a single flow
  ✗ Implementing saga/compensation patterns
  ✗ Business logic shared across 3+ Experience APIs
  ✗ Data enrichment from multiple sources
  ✗ Caching strategy that serves multiple consumers
  ✗ Complex error handling / retry orchestration across backends
```

### Architecture Comparison

```
THREE-LAYER (Traditional):

  Mobile App ──→ Experience API ──→ Process API ──→ System API ──→ Database
                  (0.5 vCore)       (0.5 vCore)     (0.5 vCore)
                  +15ms hop          +15ms hop        +5ms DB
                  Total: 1.5 vCores, +30ms overhead

TWO-LAYER (Optimized):

  Mobile App ──→ Experience API ──────────────────→ System API ──→ Database
                  (0.5 vCore)                        (0.5 vCore)
                  DW transform inline                +5ms DB
                  Total: 1.0 vCores, +15ms overhead

SAVINGS: 0.5 vCores per integration path = $900/year at $150/vCore/month
```

### vCore Savings Calculator

```dataweave
%dw 2.0
output application/json

var integrationPaths = [
    // Each path: name, current layers, process layer needed?
    { name: "Mobile → Customer",    layers: 3, processNeeded: false },
    { name: "Mobile → Orders",      layers: 3, processNeeded: false },
    { name: "Mobile → Products",    layers: 3, processNeeded: false },
    { name: "Web → Customer 360",   layers: 3, processNeeded: true  },  // Aggregates 3 backends
    { name: "Web → Order + Ship",   layers: 3, processNeeded: true  },  // Orchestrates order + shipment
    { name: "Partner → Inventory",  layers: 3, processNeeded: false },
    { name: "Partner → Invoice",    layers: 3, processNeeded: false },
    { name: "Internal → Reports",   layers: 3, processNeeded: false },
    { name: "Batch → Sync",         layers: 3, processNeeded: true  },  // Multi-system sync
    { name: "Event → Notify",       layers: 3, processNeeded: false }
]

var vcorePerLayer = 0.5
var vcoreMonthlyCost = 150

var collapsible = integrationPaths filter ((p) -> p.processNeeded == false)
var mustKeep = integrationPaths filter ((p) -> p.processNeeded == true)

// Each collapsible path saves 1 Process API vCore allocation
// But Process APIs may be shared; calculate unique Process APIs eliminated
var uniqueProcessAPIsRemoved = sizeOf(collapsible)  // Worst case: 1 Process API per path
// Realistic: some Process APIs are shared. Assume 70% are unique.
var realisticProcessAPIsRemoved = ceil(sizeOf(collapsible) * 0.7)
var vcoresSaved = realisticProcessAPIsRemoved * vcorePerLayer
var annualSavings = vcoresSaved * vcoreMonthlyCost * 12
---
{
    totalIntegrationPaths: sizeOf(integrationPaths),
    collapsibleToTwoLayer: sizeOf(collapsible),
    mustKeepThreeLayer: sizeOf(mustKeep),
    processAPIsEliminated: realisticProcessAPIsRemoved,
    vcoresSaved: vcoresSaved,
    annualSavings: annualSavings,
    currentVCoreCost: sizeOf(integrationPaths) * 3 * vcorePerLayer * vcoreMonthlyCost * 12,
    optimizedVCoreCost: (sizeOf(integrationPaths) * 3 * vcorePerLayer - vcoresSaved) * vcoreMonthlyCost * 12,
    savingsPercent: (vcoresSaved / (sizeOf(integrationPaths) * 3 * vcorePerLayer) * 100)
        as String {format: "#.1"} ++ "%",
    collapsiblePaths: collapsible map ((p) -> p.name),
    keepPaths: mustKeep map ((p) -> p.name)
}
```

### Safe Merge Pattern: Experience + Process Combined

When eliminating the Process layer, merge its logic into the Experience API using sub-flows for organization:

```xml
<!-- BEFORE: Three separate Mule apps -->
<!-- experience-api.xml → calls process-api via HTTP -->
<!-- process-api.xml → calls system-api via HTTP -->
<!-- system-api.xml → calls database -->

<!-- AFTER: Two Mule apps, Process logic merged into Experience -->
<!-- experience-api.xml (with process logic as sub-flows) -->

<flow name="get-customer">
    <!-- Experience layer: validation, auth, rate limiting -->
    <http:listener config-ref="httpConfig" path="/api/customers/{id}"/>
    <apikit:router config-ref="apiConfig"/>

    <!-- Former Process layer logic: now a sub-flow -->
    <flow-ref name="process:enrich-customer"/>

    <!-- Direct call to System API (skipping HTTP hop) -->
    <http:request config-ref="systemApiConfig"
                  path="/api/v1/customers/{id}"
                  method="GET"/>

    <!-- Experience layer: response shaping -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
// Transform system response to experience contract
---
{
    customerId: payload.id,
    fullName: payload.firstName ++ " " ++ payload.lastName,
    email: payload.contactEmail,
    tier: payload.loyaltyTier
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>

<!-- Sub-flow keeps process logic organized but avoids HTTP hop -->
<sub-flow name="process:enrich-customer">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
// Business logic that was in Process API
// Kept as sub-flow for readability
---
payload]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>
```

### Maintainability Checklist for Merged Layers

```
After merging, verify:

  [ ] Sub-flows clearly prefixed (process:, transform:, validate:)
  [ ] API contract (RAML/OAS) unchanged for consumers
  [ ] System API contract unchanged (still independently deployable)
  [ ] Error handling consolidated (no duplicate try/catch)
  [ ] Logging includes both experience and process context
  [ ] MUnit tests cover the merged logic paths
  [ ] API documentation updated to reflect simplified architecture
```

### Latency Impact

```
Per-hop latency (HTTP call between Mule apps on CloudHub):
  - Same region, same VPC:     8-15ms per hop
  - With DLB:                  12-20ms per hop
  - With VPN:                  15-30ms per hop

Three-layer path latency overhead:  2 hops × 15ms = 30ms added
Two-layer path latency overhead:    1 hop  × 15ms = 15ms added

For a 200ms total response time budget:
  - Three-layer: 30ms is 15% of budget consumed by architecture
  - Two-layer:   15ms is 7.5% of budget consumed by architecture
```

## How It Works

1. **Inventory all integration paths** and identify which ones pass through a Process API.
2. **For each Process API**, evaluate whether it performs genuine orchestration (calling 2+ backends) or just passes data through with minor transformation.
3. **Mark collapsible paths** where the Process API is a passthrough or does simple mapping that can be inlined.
4. **Merge using sub-flows** to keep the process logic organized within the Experience API without losing readability.
5. **Calculate savings** by counting the Process API workers eliminated. Each 0.5 vCore saved is $900/year.
6. **Do not collapse paths** where the Process API orchestrates multiple backends, implements saga patterns, or caches data for multiple consumers.

## Key Takeaways

- In a typical MuleSoft deployment, 50-70% of Process APIs are unnecessary passthroughs.
- Eliminating one Process API saves 0.5 vCores ($900/year) and removes 15ms of latency.
- Use sub-flows with `process:` prefixes to maintain organizational clarity after merging.
- Keep the three-layer pattern only when there is genuine multi-backend orchestration.
- System APIs should remain independent regardless of how many layers sit above them.

## Related Recipes

- [api-consolidation-patterns](../api-consolidation-patterns/) — Consolidate multiple APIs onto shared workers
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Right-size after reducing layer count
- [mulesoft-tco-calculator](../mulesoft-tco-calculator/) — Include architecture optimization in TCO model
- [when-not-to-use-mulesoft](../when-not-to-use-mulesoft/) — When even two layers are too many
