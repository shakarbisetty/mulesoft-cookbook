# CloudHub 1.0 to 2.0 Cost-Benefit Analysis

## Problem

CloudHub 2.0 introduces a fundamentally different architecture (Kubernetes-based, Anypoint Runtime Fabric on AWS) with a different pricing model. Organizations running on CloudHub 1.0 face uncertainty about whether migrating saves money or increases costs. The migration itself has a non-trivial effort cost. Without a structured analysis framework, teams either migrate too early (paying migration cost for minimal benefit) or too late (missing cost savings and feature improvements).

## Solution

A cost-benefit analysis framework that compares CloudHub 1.0 and 2.0 across pricing, infrastructure features, migration effort, and total cost. Includes a decision matrix for timing the migration and a DataWeave-based comparison calculator.

## Implementation

### Feature and Pricing Comparison

| Dimension | CloudHub 1.0 | CloudHub 2.0 | Cost Impact |
|-----------|-------------|-------------|-------------|
| **Worker Model** | Fixed vCore sizes (0.1-4.0) | Replica-based sizing (0.1-4.0 vCores per replica) | Neutral; same vCore tiers |
| **Scaling** | Manual or API-triggered worker count | Horizontal scaling with replicas, auto-restart | Potential savings: auto-recovery reduces over-provisioning |
| **Load Balancer** | Shared LB (free) or Dedicated LB ($4,800/yr) | Built-in ingress (shared space) or Private Space LB | Savings: DLB cost eliminated in shared space |
| **Networking** | VPN ($3,600/yr per tunnel) | Private Space with Transit Gateway or VPN | Comparable; private space adds cost |
| **Monitoring** | Anypoint Monitoring (Titanium or add-on) | Anypoint Monitoring included | Savings if previously paying for monitoring add-on |
| **Deployment** | Single runtime per worker | Container-based, multiple replicas | Better density possible |
| **Persistent Storage** | Object Store v2 | Object Store v2 (same) | Neutral |
| **Static IPs** | $1,200/yr per IP | Managed via Private Space networking | Savings: no per-IP charge in Private Space |
| **Uptime SLA** | 99.99% (Platinum) | 99.99% (Private Space) | Neutral |

### Migration Effort Cost Model

```dataweave
%dw 2.0
output application/json

var migrationProfile = {
    totalApps: 30,
    appComplexity: {
        simple: 15,      // API proxies, passthrough
        moderate: 10,     // DataWeave transforms, some connectors
        complex: 5        // Batch, custom connectors, VPN-dependent
    },
    currentInfra: {
        dlbs: 2,
        vpns: 2,
        staticIPs: 8,
        objectStoreApps: 5,
        customProperties: true,
        cicdPipelines: true
    },
    teamSize: 3,          // Developers available for migration
    developerDayRate: 800  // Fully loaded daily cost
}

// Effort estimates (developer-days per app)
var effortPerApp = {
    simple: 2,    // Re-deploy, test connectivity, validate
    moderate: 4,  // Update configs, test DW, validate integrations
    complex: 8    // Rework networking, batch configs, custom connector compat
}

// Infrastructure migration effort (one-time)
var infraEffort = {
    dlbMigration: migrationProfile.currentInfra.dlbs * 3,    // Days per DLB
    vpnMigration: migrationProfile.currentInfra.vpns * 5,    // Days per VPN
    cicdUpdate: if (migrationProfile.currentInfra.cicdPipelines) 10 else 0,
    propertyMigration: if (migrationProfile.currentInfra.customProperties) 5 else 0,
    testingOverhead: 15   // Regression testing across all apps
}

var appEffortDays = (
    migrationProfile.appComplexity.simple * effortPerApp.simple +
    migrationProfile.appComplexity.moderate * effortPerApp.moderate +
    migrationProfile.appComplexity.complex * effortPerApp.complex
)

var infraEffortDays = infraEffort pluck ((v) -> v) reduce ((item, total = 0) -> total + item)
var totalEffortDays = appEffortDays + infraEffortDays
var migrationCost = totalEffortDays * migrationProfile.developerDayRate
var migrationDurationWeeks = ceil(totalEffortDays / (migrationProfile.teamSize * 5))
---
{
    effortBreakdown: {
        appMigrationDays: appEffortDays,
        infrastructureDays: infraEffortDays,
        totalDeveloperDays: totalEffortDays,
        estimatedDurationWeeks: migrationDurationWeeks
    },
    migrationCost: migrationCost,
    perAppAverageCost: migrationCost / migrationProfile.totalApps,
    costNote: "One-time migration cost of $$(migrationCost). " ++
              "Break-even requires $$(ceil(migrationCost / 12))/month in CH2 savings."
}
```

### Annual Cost Comparison Calculator

```dataweave
%dw 2.0
output application/json

var appPortfolio = {
    totalApps: 30,
    totalVCoresUsed: 18,
    vcoreMonthlyCost: 150
}

var ch1Costs = {
    vcores: appPortfolio.totalVCoresUsed * appPortfolio.vcoreMonthlyCost * 12,
    dlbs: 2 * 4800,
    vpns: 2 * 3600,
    staticIPs: 8 * 1200,
    monitoringAddon: 12000  // If not on Titanium
}

var ch2Costs = {
    // Same vCore pricing (approximately)
    vcores: appPortfolio.totalVCoresUsed * appPortfolio.vcoreMonthlyCost * 12,
    // Shared space: no DLB cost. Private space: included in space cost.
    privateSpace: 1 * 18000,  // ~$18K/year per private space (estimate)
    // VPN via Transit Gateway (included in Private Space)
    vpns: 0,
    // Static IPs managed differently
    staticIPs: 0,
    // Monitoring included
    monitoringAddon: 0
}

var ch1Total = ch1Costs pluck ((v) -> v) reduce ((item, t = 0) -> t + item)
var ch2Total = ch2Costs pluck ((v) -> v) reduce ((item, t = 0) -> t + item)
---
{
    cloudHub1: {
        annualCost: ch1Total,
        breakdown: ch1Costs
    },
    cloudHub2: {
        annualCost: ch2Total,
        breakdown: ch2Costs
    },
    annualSavings: ch1Total - ch2Total,
    savingsPercent: ((ch1Total - ch2Total) / ch1Total * 100) as String {format: "#.1"} ++ "%",
    recommendation: if ((ch1Total - ch2Total) > 0)
        "CH2 saves $$(ch1Total - ch2Total)/year. Migrate when workload permits."
    else
        "CH1 is currently cheaper by $$(ch2Total - ch1Total)/year. Defer migration."
}
```

### Decision Matrix: When to Migrate

| Factor | Migrate Now | Migrate Later | Stay on CH1 |
|--------|------------|--------------|-------------|
| DLB count | 2+ DLBs ($9,600+/yr) | 1 DLB ($4,800/yr) | No DLB needed |
| VPN tunnels | 2+ tunnels | 1 tunnel | No VPN |
| Static IPs | 5+ IPs ($6,000+/yr) | 1-4 IPs | No static IPs |
| Monitoring | Paying for add-on | Using basic | Already on Titanium |
| App count | 30+ apps (amortize migration) | 10-29 apps | <10 apps |
| CH1 EOL pressure | Announced EOL date | None yet | None yet |
| Team capacity | Dedicated migration sprint | Can do incrementally | No bandwidth |
| Custom connectors | All CH2-compatible | Some need updates | Major incompatibilities |

### Risk Assessment

```
HIGH RISK items during migration:
  [ ] Mule 3 apps (must upgrade to Mule 4 first — separate effort)
  [ ] Custom Java components using CloudHub-specific APIs
  [ ] Batch jobs relying on persistent queues (different in CH2)
  [ ] Properties using CloudHub 1.0 system properties (e.g., ${mule.env})
  [ ] Anypoint MQ subscriber configurations (polling model changes)
  [ ] Load balancer mapping rules (DLB → CH2 ingress)

LOW RISK items:
  [ ] Standard API proxies
  [ ] DataWeave-only transformations
  [ ] HTTP-based integrations
  [ ] Database connectors
  [ ] File/FTP connectors
```

## How It Works

1. **Inventory your current CloudHub 1.0 costs** including vCores, DLBs, VPNs, static IPs, and monitoring add-ons.
2. **Estimate equivalent CloudHub 2.0 costs** using the comparison table. The biggest savings come from DLB elimination and included monitoring.
3. **Calculate migration effort** using the effort model. Complex apps with VPN dependencies and custom connectors take 4-5x longer than simple proxies.
4. **Compute break-even point**: divide the one-time migration cost by the monthly savings. If break-even is under 12 months, migrate. If over 24 months, defer.
5. **Check the decision matrix** to confirm timing makes sense given team capacity and risk factors.

## Key Takeaways

- The largest CloudHub 2.0 savings come from eliminating DLBs ($4,800/yr each) and static IPs ($1,200/yr each), not from vCore pricing changes.
- Migration effort is 2-8 developer-days per application depending on complexity. Budget 30% contingency.
- Organizations with 2+ DLBs, 5+ static IPs, and 30+ apps see the fastest ROI from migration.
- Do not migrate Mule 3 apps directly; upgrade to Mule 4 first as a separate project.
- CloudHub 2.0 Private Space costs can offset savings if you only need basic shared-space features.

## Related Recipes

- [ch2-shared-vs-private-space](../ch2-shared-vs-private-space/) — Choosing the right CH2 deployment model
- [cloudhub-vs-rtf-vs-onprem-cost](../cloudhub-vs-rtf-vs-onprem-cost/) — Broader deployment option comparison
- [mulesoft-tco-calculator](../mulesoft-tco-calculator/) — Include migration costs in TCO model
- [cost-monitoring-dashboard](../cost-monitoring-dashboard/) — Track costs before and after migration
