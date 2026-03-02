## Deployment Model Decision Matrix
> CloudHub vs RTF vs Hybrid with cost, compliance, latency, and operational factors

### When to Use
- You are planning a new MuleSoft deployment or migrating from one model to another
- Your organization needs to decide between CloudHub 1.0, CloudHub 2.0, Runtime Fabric (RTF), or hybrid
- Compliance requirements (data residency, air-gapped networks) constrain your deployment options
- You need to justify the operational and cost trade-offs of each model to stakeholders

### The Problem

MuleSoft offers multiple deployment models, each with different cost structures, operational overhead, compliance capabilities, and performance characteristics. Teams often default to CloudHub because it is the easiest to start with, then discover months later that regulatory requirements, latency constraints, or cost scaling force a migration to RTF or hybrid — a painful and expensive move.

### Configuration / Code

#### Deployment Model Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MuleSoft Deployment Models                   │
├─────────────────┬──────────────┬───────────────┬───────────────┤
│  CloudHub 1.0   │ CloudHub 2.0 │   RTF (Self-  │   Hybrid      │
│  (Shared Mule)  │ (Shared K8s) │   Managed)    │  (On-Prem RT) │
├─────────────────┼──────────────┼───────────────┼───────────────┤
│ MuleSoft-managed│ MuleSoft-    │ Customer K8s  │ Customer      │
│ AWS workers     │ managed K8s  │ cluster +     │ on-prem Mule  │
│                 │ on shared    │ MuleSoft      │ runtime       │
│                 │ infra        │ runtime agent │               │
├─────────────────┼──────────────┼───────────────┼───────────────┤
│ Simplest ops    │ Modern K8s   │ Full infra    │ Full infra    │
│ Least control   │ More control │ control       │ control       │
│                 │ Auto-scaling │ Any cloud/    │ Air-gapped OK │
│                 │              │ on-prem       │               │
└─────────────────┴──────────────┴───────────────┴───────────────┘
```

#### Decision Matrix

| Factor | CloudHub 1.0 | CloudHub 2.0 | RTF | Hybrid (On-Prem) |
|--------|-------------|-------------|-----|-------------------|
| **Setup time** | Minutes | Minutes | Days-weeks | Days-weeks |
| **Ops overhead** | None | Low | High (K8s team needed) | High (infra team needed) |
| **Auto-scaling** | No (manual worker add) | Yes (replica-based) | Yes (K8s HPA) | No (manual) |
| **Min cost/app** | 0.1 vCore (~$2,400/yr) | 0.1 replica (~$2,400/yr) | K8s cluster + license | Server + license |
| **Data residency** | AWS regions only | AWS regions only | Any cloud or on-prem | On-prem (full control) |
| **Air-gapped** | No | No | Yes (with restrictions) | Yes |
| **Latency to on-prem** | 5-50ms (VPN/VPC) | 5-50ms (VPN/VPC) | < 1ms (co-located) | < 1ms (local) |
| **Compliance (PCI/HIPAA)** | Shared responsibility | Shared responsibility | Customer-controlled | Customer-controlled |
| **Max apps** | 100s (org limit) | 100s | 1000s (cluster capacity) | Hardware-limited |
| **CI/CD integration** | API Manager + Maven | API Manager + Maven | Helm/kubectl + Maven | Maven + Mule Agent |
| **Monitoring** | Anypoint Monitoring | Anypoint Monitoring | Anypoint + K8s tools | Anypoint + custom |
| **Mule version control** | MuleSoft decides | MuleSoft decides | Customer decides | Customer decides |
| **Network control** | DLB, VPC, VPN | DLB, VPC, VPN | Full (ingress, service mesh) | Full |

#### Decision Flowchart

```
START: Choosing a deployment model
  │
  ├─ Must data stay on-premises or in an air-gapped network?
  │    YES ──► HYBRID (on-prem Mule runtime)
  │    NO  ──┐
  │          │
  │   ├─ Do you need sub-1ms latency to backend systems?
  │   │    YES ──► RTF (co-locate with backends)
  │   │    NO  ──┐
  │   │          │
  │   │   ├─ Do you need auto-scaling or K8s ecosystem integration?
  │   │   │    YES ──► CloudHub 2.0 (if AWS regions OK) or RTF (if custom cloud)
  │   │   │    NO  ──┐
  │   │   │          │
  │   │   │   ├─ Are you running < 20 applications?
  │   │   │   │    YES ──► CloudHub 1.0 (simplest, cheapest to start)
  │   │   │   │    NO  ──┐
  │   │   │   │          │
  │   │   │   │   ├─ Do you have a K8s team?
  │   │   │   │   │    YES ──► RTF (leverage existing K8s investment)
  │   │   │   │   │    NO  ──► CloudHub 2.0 (managed K8s without the ops)
  │   │   │   │   │
  │   │   │   └───┘
  │   │   └───────┘
  │   └───────────┘
  └───────────────┘
```

#### Cost Comparison (Approximate Annual)

| Scale | CloudHub 1.0 | CloudHub 2.0 | RTF | Hybrid |
|-------|-------------|-------------|-----|--------|
| **5 apps, low traffic** | $12,000 | $12,000 | $50,000+ (cluster overhead) | $30,000+ (servers) |
| **20 apps, medium traffic** | $72,000 | $60,000 | $80,000 | $60,000 |
| **50 apps, high traffic** | $240,000 | $180,000 | $150,000 | $120,000 |
| **100+ apps, enterprise** | $600,000+ | $400,000+ | $250,000+ | $200,000+ |

*Costs are illustrative. Actual pricing depends on MuleSoft contract, vCore tier, and infrastructure costs.*

The crossover point where RTF becomes cheaper than CloudHub is typically around 30-50 applications, depending on traffic patterns and vCore sizing.

#### CloudHub 2.0 Deployment Configuration

```xml
<!-- pom.xml — CloudHub 2.0 deployment plugin -->
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.1.1</version>
    <configuration>
        <cloudhub2Deployment>
            <uri>https://anypoint.mulesoft.com</uri>
            <provider>MC</provider>
            <environment>Production</environment>
            <target>us-east-1</target>
            <muleVersion>4.6.0</muleVersion>
            <replicas>2</replicas>
            <vCores>0.5</vCores>
            <applicationName>${project.artifactId}</applicationName>
            <properties>
                <env>prod</env>
                <region>us-east-1</region>
            </properties>
        </cloudhub2Deployment>
    </configuration>
</plugin>
```

#### RTF Deployment Configuration

```yaml
# rtf-deployment.yaml — Runtime Fabric deployment spec
apiVersion: rtf.mulesoft.com/v1
kind: MuleApplication
metadata:
  name: order-api
  namespace: mulesoft-apps
spec:
  replicas: 3
  resources:
    cpu:
      reserved: 500m
      limit: 1000m
    memory:
      reserved: 1Gi
      limit: 2Gi
  muleVersion: "4.6.0"
  properties:
    env: production
    db.host: db-primary.internal
    db.port: "5432"
  ingress:
    enabled: true
    path: /api/orders
```

#### Migration Path

```
CloudHub 1.0 ──► CloudHub 2.0
  Effort: LOW
  - Same Anypoint Platform, same CI/CD pipeline
  - Update Maven plugin configuration
  - Test auto-scaling behavior

CloudHub (any) ──► RTF
  Effort: MEDIUM-HIGH
  - Provision K8s cluster (EKS, AKS, GKE, or on-prem)
  - Install RTF agent
  - Migrate networking (ingress, service mesh, DNS)
  - Reconfigure monitoring and logging
  - Test under production load

CloudHub (any) ──► Hybrid
  Effort: HIGH
  - Provision servers, install Mule runtime
  - Configure Mule Agent for Anypoint connectivity
  - Set up load balancing, SSL termination
  - Full networking and security review
```

### How It Works

1. **Inventory your requirements** — data residency, latency, compliance, team skills, budget
2. **Score each factor** against the decision matrix
3. **Validate with the flowchart** — follow the path to confirm your matrix score
4. **Calculate TCO** — include not just MuleSoft licensing but also infrastructure, ops team, and migration costs
5. **Plan for growth** — choose the model that fits your 2-year projection, not just today

### Gotchas

- **CloudHub 1.0 persistent Object Store has a 10 GB limit per application.** If you use OS heavily for caching or circuit breakers, you can hit this silently. CloudHub 2.0 uses a different OS implementation with higher limits.
- **RTF requires a dedicated K8s cluster.** MuleSoft does not support running RTF on a shared cluster with non-MuleSoft workloads. Budget for dedicated nodes.
- **CloudHub 2.0 auto-scaling is replica-based, not vCore-based.** You scale by adding replicas (pods), not by increasing vCore allocation. This means your application must be stateless and horizontally scalable.
- **Hybrid mode still needs internet access to Anypoint Platform** for API Manager policies, Analytics, and monitoring — unless you configure a proxy. True air-gapped requires Runtime Fabric with edge mode.
- **VPN latency between CloudHub and on-prem varies wildly.** We have seen 5ms in best cases and 80ms in worst cases. Always measure before committing to a CloudHub deployment that calls on-prem backends.
- **CloudHub DLB costs extra.** Each DLB is an additional line item. If you have 5 environments, that is 5 DLBs.

### Related

- [Multi-Region Active-Active Blueprint](../multi-region-active-active-blueprint/) — deploying across regions
- [Multi-Region DR Strategy](../multi-region-dr-strategy/) — active-passive failover
- [API-Led Layer Decision Framework](../api-led-layer-decision-framework/) — how many layers affects deployment cost
- [Zero-Trust API Architecture](../zero-trust-api-architecture/) — security considerations per deployment model
