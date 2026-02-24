## CloudHub vs RTF vs On-Prem Cost Comparison
> Total cost of ownership comparison across MuleSoft deployment targets with real numbers for infrastructure, licensing, and operations labor.

### When to Use
- Evaluating where to deploy a new set of APIs (greenfield decision)
- Considering migrating from CloudHub to Runtime Fabric (RTF) or vice versa
- Building a business case for or against self-hosted MuleSoft infrastructure
- Preparing for license renewal and want to evaluate alternative deployment models
- Running a hybrid strategy and need to decide which APIs go where

### Configuration / Code

#### 3-Year TCO Comparison — 20 APIs Scenario

Assumptions: 20 production APIs, average 0.5 vCore each (10 vCores total), 2 non-prod environments, US region, mid-market enterprise.

| Cost Category | CloudHub | RTF (AWS EKS) | On-Prem (VMware) |
|---------------|----------|---------------|-------------------|
| **MuleSoft License (annual)** | $180,000 | $150,000 | $150,000 |
| **Infrastructure (annual)** | Included | $48,000 | $35,000 |
| **Kubernetes ops labor (annual)** | $0 | $40,000 | $0 |
| **VM/server ops labor (annual)** | $0 | $0 | $30,000 |
| **Networking (annual)** | Included | $12,000 | $8,000 |
| **Monitoring/APM (annual)** | Included (basic) | $15,000 | $15,000 |
| **Security/patching (annual)** | Included | $10,000 | $15,000 |
| **DR/backup (annual)** | Included | $8,000 | $12,000 |
| **Annual Total** | **$180,000** | **$283,000** | **$265,000** |
| **3-Year Total** | **$540,000** | **$849,000** | **$795,000** |

#### Cost Breakdown Details

**CloudHub Infrastructure (included in license):**
- Managed runtime, load balancers, DDoS protection
- Anypoint Monitoring (basic tier)
- 99.99% SLA with automatic failover
- Zero ops team required for infrastructure

**RTF on AWS EKS:**
```
EKS Cluster:
  Control plane:          $73/mo × 12 = $876/yr
  Worker nodes (3× m5.xlarge): $462/mo × 12 = $5,544/yr × 3 = $16,632/yr
  EBS storage (500GB):    $50/mo × 12 = $600/yr

Networking:
  ALB:                    $22/mo × 12 = $264/yr
  NAT Gateway:            $32/mo + data = $5,000/yr
  Data transfer (egress): ~$6,000/yr

Monitoring:
  Datadog/Splunk:         $15,000/yr (or self-hosted ELK)

Total Infrastructure:     ~$48,000/yr
```

**On-Prem (VMware):**
```
Hardware (amortized 5yr):
  3 servers (Dell R750):  $45,000 / 5 = $9,000/yr
  Storage (SAN):          $20,000 / 5 = $4,000/yr
  Network switches:       $10,000 / 5 = $2,000/yr

VMware licensing:         $8,000/yr
Power/cooling:            $4,000/yr
Data center space:        $8,000/yr

Total Infrastructure:     ~$35,000/yr
```

#### Decision Matrix

| Factor | CloudHub Wins | RTF Wins | On-Prem Wins |
|--------|--------------|----------|--------------|
| **Time to market** | Yes — deploy in minutes | — | — |
| **Ops team size** | Yes — zero infra ops | — | — |
| **Total cost (<30 APIs)** | Yes — no infra overhead | — | — |
| **Total cost (>100 APIs)** | — | Yes — economies of scale | Maybe — if hardware exists |
| **Data residency** | — | Yes — choose region/zone | Yes — full control |
| **Regulatory compliance** | — | — | Yes — air-gapped possible |
| **Existing K8s investment** | — | Yes — leverage existing cluster | — |
| **Existing data center** | — | — | Yes — sunk cost on hardware |
| **Custom runtime config** | — | Yes — JVM flags, OS tuning | Yes — full control |
| **Network latency to backends** | — | Yes — co-locate with backends | Yes — same network |
| **Burst scaling** | Yes — auto-scales (CH2) | Yes — HPA on K8s | No — fixed capacity |

#### When Each Option Wins

```yaml
choose_cloudhub_when:
  - team_size: "< 50 developers"
  - api_count: "< 30 production APIs"
  - ops_capability: "No dedicated infrastructure team"
  - priority: "Speed to market over cost optimization"
  - data_residency: "US or EU standard regions are acceptable"
  - compliance: "SOC2/ISO27001 sufficient (no FedRAMP/air-gap)"

choose_rtf_when:
  - team_size: "> 50 developers"
  - api_count: "> 50 production APIs"
  - ops_capability: "Existing Kubernetes team with EKS/AKS/GKE experience"
  - priority: "Cost optimization at scale + data residency control"
  - existing_infra: "Already running Kubernetes clusters with spare capacity"
  - compliance: "Need specific cloud region or VPC-level isolation"

choose_onprem_when:
  - compliance: "FedRAMP, ITAR, air-gapped network required"
  - existing_infra: "Data center with available capacity and ops team"
  - network: "Backend systems are exclusively on-prem with no cloud connectivity"
  - priority: "Maximum control over infrastructure and data"
  - budget: "Capital expenditure preferred over operational expenditure"
```

#### Scale-Based Cost Crossover

| API Count | CloudHub (annual) | RTF (annual) | Break-Even |
|-----------|-------------------|--------------|------------|
| 10 | $90,000 | $193,000 | CloudHub wins by $103K |
| 20 | $180,000 | $283,000 | CloudHub wins by $103K |
| 50 | $450,000 | $370,000 | **RTF wins by $80K** |
| 100 | $900,000 | $520,000 | **RTF wins by $380K** |
| 200 | $1,800,000 | $750,000 | **RTF wins by $1.05M** |

*RTF break-even: ~35-40 APIs, where shared infrastructure costs are amortized across enough workloads.*

### How It Works
1. Inventory all APIs by deployment target, vCore allocation, and environment (production, sandbox, design)
2. Calculate CloudHub cost as the simpler baseline — license includes infrastructure, monitoring, and ops
3. For RTF, itemize: MuleSoft license (typically 15-20% cheaper), Kubernetes cluster, worker nodes, networking, storage, monitoring tooling, and ops labor (at least 0.5 FTE for K8s management)
4. For on-prem, itemize: MuleSoft license, hardware amortized over 5 years, VMware/hypervisor licensing, data center costs, network equipment, and ops labor (at least 0.5 FTE for server management)
5. Add hidden costs: data egress fees (RTF), security patching cadence (RTF + on-prem), disaster recovery infrastructure (all self-hosted)
6. Project costs at current scale and at 2x/5x growth to find crossover points
7. Factor in non-financial considerations: time to market, compliance requirements, existing team skills

### Gotchas
- **Underestimating ops cost is the #1 mistake** — RTF and on-prem require Kubernetes/infrastructure expertise; hiring or training this capability costs $150K-$200K/yr for a senior engineer
- **Data egress fees are hidden killers** — AWS charges $0.09/GB for data leaving the VPC; a chatty API doing 100GB/month of egress = $9/month, but 10TB/month = $900/month
- **CloudHub 2.0 changes the math** — CH2 runs on customer-managed infrastructure (like RTF) but with MuleSoft-managed control plane; pricing model differs from CH1
- **License negotiation matters more than infrastructure** — the MuleSoft license is 60-70% of TCO for CloudHub; a 10% license discount saves more than any infrastructure optimization
- **RTF requires minimum cluster size** — even for 5 APIs, you need at least 3 worker nodes for HA; the fixed cluster cost makes RTF uneconomical below ~35 APIs
- **On-prem hardware refresh cycle** — servers depreciate over 5 years; factor in the next hardware refresh when comparing 3-year TCO
- **Hybrid is often the real answer** — production on CloudHub for reliability, dev/test on RTF for cost, regulated workloads on-prem; the cheapest option is rarely one-size-fits-all

### Related
- [vCore Right-Sizing Calculator](../vcore-right-sizing-calculator/) — right-size before comparing platforms
- [CloudHub vCore Sizing Matrix](../../performance/cloudhub/vcore-sizing-matrix/) — CloudHub performance baselines
- [CloudHub 2.0 HPA Autoscaling](../../performance/cloudhub/ch2-hpa-autoscaling/) — CH2 auto-scaling reduces over-provisioning
- [Usage-Based Pricing Migration](../usage-based-pricing-migration/) — pricing model is orthogonal to deployment target
- [License Audit & Renewal Checklist](../license-audit-renewal-checklist/) — audit before committing to a platform
