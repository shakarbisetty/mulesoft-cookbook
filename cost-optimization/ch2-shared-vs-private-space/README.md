# CloudHub 2.0 Shared Space vs Private Space Decision Matrix

## Problem

CloudHub 2.0 introduces two deployment models: Shared Space (multi-tenant, simpler, cheaper) and Private Space (single-tenant, full network control, more expensive). Organizations migrating from CloudHub 1.0 default to Private Space because it resembles the familiar VPC model, but for many workloads Shared Space provides equivalent functionality at 50-60% lower cost. Without a clear decision framework, teams over-provision Private Spaces for applications that do not need network isolation or advanced configuration.

## Solution

A detailed comparison of Shared Space and Private Space across pricing, networking, compliance, performance, and deployment capabilities. Includes specific scenarios with cost calculations showing when Shared Space saves 60%+ and when Private Space is justified.

## Implementation

### Feature Comparison

| Capability | Shared Space | Private Space | Impact |
|-----------|-------------|--------------|--------|
| **Pricing** | vCore cost only | vCore + space infrastructure fee | Shared saves $15-25K/year |
| **Network isolation** | Shared networking | Dedicated VPC | Private required for compliance |
| **Custom ingress** | Shared domain (*.cloudhub.io) | Custom domains, TLS certs | Private for branded APIs |
| **Egress to on-prem** | No direct connectivity | VPN, Transit Gateway, PrivateLink | Private for on-prem backends |
| **DLB equivalent** | Built-in ingress (shared) | Dedicated ingress controller | Private for custom routing |
| **Firewall rules** | Platform-managed | Custom security groups | Private for strict egress control |
| **IP whitelisting** | Dynamic IPs | Static egress IPs | Private for IP-restricted backends |
| **Performance** | Shared infrastructure | Dedicated nodes possible | Private for latency-sensitive |
| **Compliance** | SOC2 (platform-level) | SOC2 + custom compliance controls | Private for PCI, HIPAA |
| **Deployment** | Simple: deploy to region | Configure space, then deploy | Shared is simpler |
| **Min commitment** | Per-app vCore | Space fee + per-app vCore | Shared has lower floor |

### Cost Comparison Scenarios

#### Scenario 1: 10 API Proxies, No On-Prem Connectivity

```
SHARED SPACE:
  10 apps × 0.2 vCore × $150/month = $300/month
  Ingress: included
  Total: $300/month ($3,600/year)

PRIVATE SPACE:
  10 apps × 0.2 vCore × $150/month = $300/month
  Private Space fee: ~$1,500/month (estimated)
  Total: $1,800/month ($21,600/year)

SAVINGS WITH SHARED: $18,000/year (83% cheaper)
VERDICT: Use Shared Space — no on-prem connectivity needed
```

#### Scenario 2: 5 APIs with VPN to On-Prem SAP

```
SHARED SPACE:
  Cannot connect to on-prem systems
  NOT VIABLE for this scenario

PRIVATE SPACE:
  5 apps × 1.0 vCore × $150/month = $750/month
  Private Space fee: ~$1,500/month
  VPN/Transit Gateway: included in space fee
  Total: $2,250/month ($27,000/year)

VERDICT: Private Space required — on-prem connectivity is mandatory
```

#### Scenario 3: 20 APIs, Mixed Requirements

```
OPTIMAL: Split deployment across both spaces

SHARED SPACE (12 external-facing APIs, no on-prem):
  12 apps × 0.5 vCore × $150/month = $900/month
  Total: $900/month ($10,800/year)

PRIVATE SPACE (8 APIs needing on-prem or compliance):
  8 apps × 0.5 vCore × $150/month = $600/month
  Private Space fee: ~$1,500/month
  Total: $2,100/month ($25,200/year)

COMBINED: $3,000/month ($36,000/year)

VS ALL PRIVATE SPACE:
  20 apps × 0.5 vCore × $150/month = $1,500/month
  Private Space fee: ~$1,500/month
  Total: $3,000/month ($36,000/year)

SAVINGS WITH SPLIT: $0/year in this case (break-even at this scale)
But with more shared-eligible apps, savings grow.
```

### Decision Matrix

```dataweave
%dw 2.0
output application/json

var appRequirements = {
    appName: "customer-api",
    needsOnPremConnectivity: false,
    needsCustomDomain: false,
    needsStaticIP: false,
    needsComplianceIsolation: false,   // PCI, HIPAA, etc.
    needsCustomFirewallRules: false,
    needsPerformanceIsolation: false,
    needsVPN: false,
    needsPrivateLink: false,
    tpsRequirement: 50,
    dataClassification: "internal"      // public | internal | confidential | restricted
}

var requiresPrivateSpace = [
    appRequirements.needsOnPremConnectivity,
    appRequirements.needsVPN,
    appRequirements.needsPrivateLink,
    appRequirements.needsComplianceIsolation,
    appRequirements.needsStaticIP,
    appRequirements.needsCustomFirewallRules,
    appRequirements.dataClassification == "restricted"
]

var privateSpaceRequired = (requiresPrivateSpace filter ((r) -> r == true)) then sizeOf($) > 0
var privateSpaceNiceToHave = appRequirements.needsCustomDomain or appRequirements.needsPerformanceIsolation
---
{
    app: appRequirements.appName,
    recommendation: if (privateSpaceRequired)
        "PRIVATE SPACE - Hard requirements mandate dedicated infrastructure"
    else if (privateSpaceNiceToHave)
        "EVALUATE - Nice-to-have features available in Private Space; check cost delta"
    else
        "SHARED SPACE - No requirements mandate Private Space; save 50-80% on infrastructure",
    privateSpaceTriggers: {
        hardRequirements: requiresPrivateSpace
            filter ((r) -> r == true)
            then sizeOf($),
        niceToHaveRequirements: [appRequirements.needsCustomDomain, appRequirements.needsPerformanceIsolation]
            filter ((r) -> r == true)
            then sizeOf($)
    },
    costImpact: if (privateSpaceRequired)
        "Private Space adds ~$1,500/month base fee. Amortize across all apps in the space."
    else
        "Shared Space: zero infrastructure overhead beyond vCore costs."
}
```

### Migration Strategy: CH1 to CH2 Space Selection

```
Step 1: Inventory all CH1 applications
Step 2: For each app, evaluate the decision matrix above
Step 3: Group apps into Shared Space and Private Space buckets

Typical distribution:
  ┌─────────────────────────────────┐
  │ CH1 Applications (30 total)     │
  ├─────────────────────────────────┤
  │ → Shared Space eligible:  18    │  (60%)
  │   - External APIs              │
  │   - Cloud-to-cloud integrations│
  │   - Public-facing proxies       │
  │                                 │
  │ → Private Space required:  12   │  (40%)
  │   - On-prem connected           │
  │   - PCI/HIPAA scoped           │
  │   - IP-whitelisted backends    │
  │   - Custom domain required      │
  └─────────────────────────────────┘

Step 4: Migrate Shared Space apps first (lower risk, faster)
Step 5: Set up Private Space infrastructure
Step 6: Migrate Private Space apps
Step 7: Validate and decommission CH1 workers
```

### Private Space Sizing Considerations

```
Private Space infrastructure fee covers:
  - Dedicated Kubernetes nodes (managed by MuleSoft)
  - Ingress controller
  - VPN/Transit Gateway termination
  - Network isolation

The fee is FIXED regardless of how many apps you deploy.
Therefore: maximize the number of apps per Private Space.

Cost optimization:
  - 1 Private Space with 20 apps: $1,500 + vCores = $75/app overhead
  - 2 Private Spaces with 10 apps each: $3,000 + vCores = $300/app overhead
  - Use 1 space unless compliance requires environment separation
```

### When Shared Space Saves 60%+

```
Shared Space saves the most when:
  1. You have 5-15 small apps (0.1-0.5 vCore each)
     → Avoiding $18K/year Private Space fee on low-volume apps

  2. All backends are cloud-based (no VPN needed)
     → Shared Space handles cloud-to-cloud natively

  3. Default *.cloudhub.io domain is acceptable
     → No need for custom ingress configuration

  4. No compliance mandates for network isolation
     → Standard SOC2 platform compliance is sufficient

  5. IP whitelisting is not required by backends
     → Shared Space uses dynamic egress IPs

Example calculation (10 small apps):
  Shared: 10 × 0.2 × $150 = $300/mo = $3,600/yr
  Private: $300/mo + $1,500/mo = $1,800/mo = $21,600/yr
  Savings: $18,000/yr (83%)
```

## How It Works

1. **For each application**, run through the decision matrix requirements checklist.
2. **If any hard requirement** (on-prem connectivity, VPN, compliance isolation, static IP) is present, the app must go to Private Space.
3. **If only nice-to-have requirements** (custom domain, performance isolation) are present, calculate whether the Private Space cost is justified.
4. **If no requirements** mandate Private Space, deploy to Shared Space and save the infrastructure fee.
5. **For mixed portfolios**, split apps between Shared and Private Spaces. Maximize the number of apps per Private Space to amortize the fixed fee.
6. **Review quarterly** as requirements evolve; apps may become Shared Space eligible if backend systems move to cloud.

## Key Takeaways

- Shared Space eliminates the $15-25K/year Private Space infrastructure fee for apps that do not need network isolation.
- The primary drivers for Private Space are: on-prem connectivity, compliance isolation, and IP whitelisting — not performance.
- Most organizations have a 60/40 split (Shared/Private) that saves $10-20K annually compared to all-Private deployment.
- Maximize apps per Private Space to amortize the fixed fee; avoid creating separate spaces per environment unless compliance requires it.
- Start migration with Shared Space candidates — they are lower risk and deliver immediate cost savings.

## Related Recipes

- [cloudhub-1-to-2-cost-analysis](../cloudhub-1-to-2-cost-analysis/) — Full CH1 to CH2 migration cost analysis
- [cloudhub-vs-rtf-vs-onprem-cost](../cloudhub-vs-rtf-vs-onprem-cost/) — Compare CH2 Private Space vs RTF
- [cost-monitoring-dashboard](../cost-monitoring-dashboard/) — Track per-space costs after deployment
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Right-size apps within each space
