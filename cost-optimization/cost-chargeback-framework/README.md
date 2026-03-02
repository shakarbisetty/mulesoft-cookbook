# MuleSoft Cost Chargeback Framework

## Problem

In multi-team organizations sharing a MuleSoft platform, costs are typically absorbed by a central IT budget. This creates a tragedy of the commons: teams deploy applications without cost awareness, never decommission unused APIs, and request the largest vCore sizes "just in case." Without visibility into per-team costs, there is no incentive to optimize. Finance teams cannot attribute integration costs to business units for P&L accuracy, and platform teams cannot justify budget increases tied to specific business demand.

## Solution

A cost chargeback (or showback) framework that tags every MuleSoft resource to a business unit, calculates per-team costs including shared infrastructure allocation, and generates monthly chargeback reports. Supports both full chargeback (teams pay from their budget) and showback (teams see costs but central IT pays) models.

## Implementation

### Tagging Strategy

```
Every Mule application must have these tags in Runtime Manager:

  business-unit:    "sales" | "finance" | "operations" | "hr" | "marketing"
  cost-center:      "CC-4100" | "CC-4200" | etc.
  team:             "order-management" | "customer-360" | etc.
  project:          "PROJECT-123" | "SAP-migration" | etc.
  criticality:      "tier-1" | "tier-2" | "tier-3"

Tag implementation options:
  1. Runtime Manager application properties (recommended)
  2. API Manager custom tags
  3. Naming convention: {team}-{function}-{env} (fallback)
```

### Application Properties for Cost Tagging

```properties
# Per-application cost metadata (set in Runtime Manager)
cost.business-unit=sales
cost.cost-center=CC-4100
cost.team=order-management
cost.project=PROJECT-123
cost.criticality=tier-1
```

### Cost Allocation Model

```
┌─────────────────────────────────────────────────────────┐
│                 COST ALLOCATION MODEL                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  DIRECT COSTS (allocated 100% to owning team):           │
│  ├── vCore costs per application                         │
│  ├── Partner connector licenses (if team-specific)       │
│  └── Static IPs (if app-specific)                        │
│                                                          │
│  SHARED COSTS (allocated proportionally):                │
│  ├── Platform license fee                                │
│  │   → Allocated by: % of total vCores used by team      │
│  ├── Dedicated Load Balancer                             │
│  │   → Allocated by: % of traffic through DLB per team   │
│  ├── VPN tunnels                                         │
│  │   → Allocated by: # of apps using VPN per team        │
│  ├── Anypoint MQ                                         │
│  │   → Allocated by: message volume per team             │
│  ├── Support contract                                    │
│  │   → Allocated by: % of total vCores used by team      │
│  └── Platform team salaries                              │
│      → Allocated by: equal share or ticket volume         │
│                                                          │
│  UNALLOCATED COSTS (central IT absorbs):                 │
│  ├── Sandbox/dev environments (shared)                   │
│  ├── Monitoring and observability tooling                │
│  └── Training and certification budget                   │
└─────────────────────────────────────────────────────────┘
```

### DataWeave Chargeback Calculator

```dataweave
%dw 2.0
output application/json

// Application inventory with cost tags
var applications = [
    { app: "sales-order-api",        bu: "sales",      vcore: 1.0, workers: 2, mqMsgs: 500000 },
    { app: "sales-quote-api",        bu: "sales",      vcore: 0.5, workers: 1, mqMsgs: 50000  },
    { app: "finance-invoice-api",    bu: "finance",    vcore: 1.0, workers: 1, mqMsgs: 200000 },
    { app: "finance-payment-sync",   bu: "finance",    vcore: 0.5, workers: 1, mqMsgs: 100000 },
    { app: "ops-inventory-api",      bu: "operations", vcore: 1.0, workers: 2, mqMsgs: 800000 },
    { app: "ops-warehouse-batch",    bu: "operations", vcore: 2.0, workers: 1, mqMsgs: 0      },
    { app: "hr-employee-api",        bu: "hr",         vcore: 0.2, workers: 1, mqMsgs: 10000  },
    { app: "marketing-leads-sync",   bu: "marketing",  vcore: 0.5, workers: 1, mqMsgs: 300000 }
]

var vcoreMonthlyCost = 150

// Shared costs (monthly)
var sharedCosts = {
    platformLicense: 200000 / 12,  // $16,667/month
    dlb: 400,                       // 1 DLB
    vpn: 600,                       // 2 VPN tunnels
    support: 40000 / 12,           // $3,333/month
    platformTeam: 15000 / 12       // Partial FTE allocation
}

// Calculate direct costs per business unit
var buDirectCosts = applications
    groupBy ((app) -> app.bu)
    mapObject ((apps, bu) -> (bu): {
        apps: apps map $.app,
        totalVCores: apps reduce ((a, t = 0) -> t + (a.vcore * a.workers)),
        directVCoreCost: apps reduce ((a, t = 0) -> t + (a.vcore * a.workers * vcoreMonthlyCost)),
        totalMqMessages: apps reduce ((a, t = 0) -> t + a.mqMsgs)
    })

// Calculate shared cost allocation
var totalOrgVCores = applications reduce ((a, t = 0) -> t + (a.vcore * a.workers))
var totalOrgMqMsgs = applications reduce ((a, t = 0) -> t + a.mqMsgs)
var totalSharedCost = sharedCosts pluck ((v) -> v) reduce ((item, t = 0) -> t + item)

var buSharedCosts = buDirectCosts mapObject ((buData, bu) -> do {
    var vcoreShare = buData.totalVCores / totalOrgVCores
    var mqShare = if (totalOrgMqMsgs > 0) buData.totalMqMessages / totalOrgMqMsgs else 0
    // Weighted allocation: 60% by vCore usage, 30% by MQ volume, 10% equal share
    var allocationPct = (vcoreShare * 0.6) + (mqShare * 0.3) + (1 / sizeOf(buDirectCosts) * 0.1)
    ---
    (bu): {
        allocationPercent: allocationPct * 100,
        sharedCostAllocation: totalSharedCost * allocationPct
    }
})

// Combine direct + shared costs
var buTotalCosts = (buDirectCosts pluck ((buData, bu) -> {
    businessUnit: bu as String,
    directCost: buData.directVCoreCost,
    sharedCost: buSharedCosts[bu].sharedCostAllocation,
    totalMonthlyCost: buData.directVCoreCost + buSharedCosts[bu].sharedCostAllocation,
    appCount: sizeOf(buData.apps),
    totalVCores: buData.totalVCores,
    costPerApp: (buData.directVCoreCost + buSharedCosts[bu].sharedCostAllocation) / sizeOf(buData.apps)
})) orderBy -$.totalMonthlyCost
---
{
    reportMonth: now() as String {format: "yyyy-MM"},
    totalMonthlyCost: buTotalCosts reduce ((bu, t = 0) -> t + bu.totalMonthlyCost),
    byBusinessUnit: buTotalCosts,
    sharedCostPool: {
        total: totalSharedCost,
        breakdown: sharedCosts,
        allocationMethod: "60% vCore usage, 30% MQ volume, 10% equal share"
    },
    orgTotals: {
        totalVCores: totalOrgVCores,
        totalApps: sizeOf(applications),
        avgCostPerApp: (buTotalCosts reduce ((bu, t = 0) -> t + bu.totalMonthlyCost)) / sizeOf(applications)
    }
}
```

### Sample Chargeback Report

```
═══════════════════════════════════════════════════════════
  MONTHLY COST CHARGEBACK REPORT — February 2026
═══════════════════════════════════════════════════════════

  BUSINESS UNIT          DIRECT    SHARED    TOTAL     APPS  vCORES
  ─────────────────────  ────────  ────────  ────────  ────  ──────
  Operations             $600.00   $8,412    $9,012    2     4.0
  Sales                  $450.00   $6,234    $6,684    2     2.5
  Finance                $225.00   $3,890    $4,115    2     1.5
  Marketing              $75.00    $2,456    $2,531    1     0.5
  HR                     $30.00    $1,008    $1,038    1     0.2
  ─────────────────────  ────────  ────────  ────────  ────  ──────
  TOTAL                  $1,380    $22,000   $23,380   8     8.7

  SHARED COST ALLOCATION METHOD:
  60% by vCore consumption + 30% by MQ message volume + 10% equal share

  TOP COST DRIVERS:
  1. ops-warehouse-batch (2.0 vCore) — $300/mo direct + shared allocation
  2. sales-order-api (1.0 × 2 workers) — $300/mo direct
  3. ops-inventory-api (1.0 × 2 workers) — $300/mo direct

═══════════════════════════════════════════════════════════
```

### Showback vs Chargeback Decision

| Model | How It Works | Best For | Risk |
|-------|-------------|----------|------|
| **Showback** | Teams see costs but central IT pays | First 6 months of cost visibility program | No financial pressure to optimize |
| **Chargeback** | Costs deducted from team budgets | Mature organizations with cost discipline | Teams may resist or game the system |
| **Hybrid** | Direct costs charged back, shared costs shown | Most organizations | Balances accountability and simplicity |

**Recommended approach**: Start with showback for 2 quarters, then move to hybrid chargeback. Full chargeback is rarely necessary and creates friction.

## How It Works

1. **Establish the tagging standard** and require all new deployments to include business-unit and cost-center tags.
2. **Backfill existing applications** with tags based on naming conventions or team ownership records.
3. **Deploy the cost calculator** (runs monthly) to collect vCore usage, MQ volumes, and tag data.
4. **Choose the allocation method** for shared costs. The 60/30/10 split (vCores/MQ/equal) works for most organizations; adjust weights based on what drives your costs.
5. **Distribute reports** to business unit leads and finance. Start with showback; transition to chargeback after 2 quarters of data.
6. **Review quarterly** with each business unit to identify optimization opportunities.

## Key Takeaways

- Direct vCore costs are straightforward to allocate; shared platform costs (license, DLB, VPN) require a fair allocation formula.
- Start with showback (visibility only) before implementing chargeback (financial accountability).
- The tagging strategy must be enforced at deployment time; retroactive tagging is painful and inaccurate.
- The 60/30/10 allocation method (vCores/MQ/equal) prevents any single team from bearing disproportionate shared costs.
- Monthly chargeback reports create natural incentives for teams to decommission idle APIs and right-size workers.

## Related Recipes

- [cost-monitoring-dashboard](../cost-monitoring-dashboard/) — Provides the raw data for chargeback calculations
- [idle-worker-detection](../idle-worker-detection/) — Identifies idle resources to charge back to owning teams
- [mulesoft-tco-calculator](../mulesoft-tco-calculator/) — Total cost model that feeds the chargeback framework
- [license-audit-renewal-checklist](../license-audit-renewal-checklist/) — Use chargeback data to justify renewal negotiations
