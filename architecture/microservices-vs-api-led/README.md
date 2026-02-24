## Microservices vs API-Led
> When to use each pattern, when to combine them, and the hidden costs of both

### When to Use
- Your organization is debating whether to adopt microservices, API-led, or both
- Development teams want full autonomy but the platform team wants governance
- You are migrating from a monolith and need to choose a decomposition strategy
- Existing API-led architecture feels too rigid, or microservices feel too chaotic

### Configuration / Code

#### Side-by-Side Comparison

| Dimension | Microservices | API-Led Connectivity | Winner |
|-----------|--------------|---------------------|--------|
| **Primary goal** | Team autonomy, independent deployment | Reuse, composability, governed catalog | Depends on org priority |
| **Team structure** | Each team owns 1-3 services end-to-end | Shared platform team + domain teams | Microservices for large orgs |
| **Data ownership** | Each service owns its data store | Shared databases common (via system APIs) | Microservices (cleaner) |
| **Deployment independence** | Full — each service deploys alone | Partial — tier dependencies exist | Microservices |
| **API catalog / discovery** | Fragmented unless enforced | Exchange is the catalog by default | API-Led |
| **Governance** | Lightweight (service mesh, contracts) | Centralized (API Manager, C4E) | API-Led for regulated industries |
| **Communication** | Events + lightweight HTTP/gRPC | HTTP (tier-to-tier), some MQ | Microservices (more flexible) |
| **Complexity floor** | High — need CI/CD, observability, mesh | Medium — Anypoint Platform handles infra | API-Led for smaller teams |
| **Reuse model** | Libraries, shared events, SDKs | Exchange assets, API fragments, policies | API-Led (built-in reuse catalog) |
| **Operational cost** | Service mesh, distributed tracing, many repos | Anypoint Platform licensing | Comparable at scale |

#### Decision Matrix

```
                          ┌─────────────────────────┐
                          │ How many integration     │
                          │ developers do you have?  │
                          └──────────┬──────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                 │
                  < 10            10-50              50+
                    │                │                 │
                    ▼                ▼                 ▼
              ┌──────────┐    ┌──────────┐      ┌──────────┐
              │ API-Led   │    │ How often │      │ Hybrid   │
              │ (simpler  │    │ do teams  │      │ pattern  │
              │  ops)     │    │ need to   │      │ is likely│
              └──────────┘    │ deploy    │      │ the best │
                              │ independently?│  │ fit      │
                              └─────┬─────┘      └──────────┘
                                    │
                           ┌────────┼────────┐
                           │                 │
                      Daily/weekly      Monthly/quarterly
                           │                 │
                           ▼                 ▼
                    ┌──────────┐       ┌──────────┐
                    │Microsvcs │       │ API-Led   │
                    │(autonomy │       │ (shared   │
                    │ matters) │       │  cadence  │
                    └──────────┘       │  is fine) │
                                       └──────────┘
```

#### Detailed Decision Factors

| Factor | Favors Microservices | Favors API-Led | Favors Hybrid |
|--------|---------------------|---------------|---------------|
| Org size | > 50 developers | < 30 developers | 30-100 developers |
| Team autonomy need | High — teams own domains | Low — shared platform OK | Mixed across domains |
| Deployment frequency | Multiple times/day | Weekly or less | Varies by team |
| Data isolation | Strict — no shared DB | Relaxed — shared DB OK | Domain-dependent |
| Regulatory governance | Light-touch | Strict audit trails | Domain-dependent |
| Existing investment | Kubernetes, service mesh | Anypoint Platform | Both present |
| Change frequency | Backend schemas change often | Backend schemas stable | Mixed |

#### The Hybrid Pattern

Most real-world MuleSoft organizations end up here: microservices thinking with API-led governance.

```
HYBRID: Microservices with API-Led Governance Layer

  ┌─────────────────────────────────────────────────────┐
  │              API-Led Governance Layer                 │
  │                                                      │
  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐│
  │  │ API Manager   │  │ Exchange     │  │ C4E Review ││
  │  │ (policies,    │  │ (catalog,    │  │ (standards,││
  │  │  SLAs, auth)  │  │  discovery)  │  │  reuse)    ││
  │  └──────────────┘  └──────────────┘  └────────────┘│
  └──────────────────────────┬──────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                   │
  ┌───────┴────────┐ ┌──────┴───────┐  ┌───────┴────────┐
  │ Order Domain    │ │ Customer     │  │ Payment Domain  │
  │ (microservice)  │ │ Domain       │  │ (microservice)  │
  │                 │ │(microservice)│  │                 │
  │ ┌─────────────┐│ │┌────────────┐│  │┌──────────────┐│
  │ │order-api    ││ ││customer-api││  ││payment-api   ││
  │ │(registered  ││ ││(registered ││  ││(registered   ││
  │ │ in Exchange)││ ││ in Exchange)││  ││ in Exchange) ││
  │ └─────────────┘│ │└────────────┘│  │└──────────────┘│
  │ ┌─────────────┐│ │┌────────────┐│  │┌──────────────┐│
  │ │order-db     ││ ││customer-db ││  ││payment-db    ││
  │ │(owned)      ││ ││(owned)     ││  ││(owned)       ││
  │ └─────────────┘│ │└────────────┘│  │└──────────────┘│
  │ ┌─────────────┐│ │              │  │                │
  │ │event pub    ││ │              │  │                │
  │ │(Anypoint MQ)││ │              │  │                │
  │ └─────────────┘│ │              │  │                │
  └────────────────┘ └──────────────┘  └────────────────┘

  Rules of the hybrid:
  1. Each domain team owns their service, database, and API
  2. All APIs must be registered in Exchange (governance)
  3. All APIs must pass through API Manager (security, SLAs)
  4. Cross-domain communication uses events (Anypoint MQ)
  5. No direct database access across domains
  6. C4E reviews API designs, not implementations
```

#### The Microservices Tax

Before adopting microservices, budget for the operational overhead:

```
MICROSERVICES TAX — Things you need before going micro:

  ┌────────────────────────────────────────────────┐
  │ Capability          │ Tool/Approach    │ Cost  │
  ├─────────────────────┼──────────────────┼───────┤
  │ Distributed tracing │ OpenTelemetry,   │ $$    │
  │                     │ Jaeger, Zipkin   │       │
  ├─────────────────────┼──────────────────┼───────┤
  │ Service discovery   │ K8s DNS, Consul  │ $     │
  ├─────────────────────┼──────────────────┼───────┤
  │ Circuit breakers    │ Resilience4j,    │ $     │
  │                     │ Istio            │       │
  ├─────────────────────┼──────────────────┼───────┤
  │ Centralized logging │ ELK, Splunk,     │ $$$   │
  │                     │ Datadog          │       │
  ├─────────────────────┼──────────────────┼───────┤
  │ CI/CD per service   │ GitHub Actions,  │ $$    │
  │                     │ Jenkins          │       │
  ├─────────────────────┼──────────────────┼───────┤
  │ Contract testing    │ Pact, Spring     │ $     │
  │                     │ Cloud Contract   │       │
  ├─────────────────────┼──────────────────┼───────┤
  │ Secret management   │ Vault, AWS SM    │ $     │
  ├─────────────────────┼──────────────────┼───────┤
  │ Service mesh        │ Istio, Linkerd   │ $$$   │
  │ (optional but       │                  │       │
  │  recommended)       │                  │       │
  └─────────────────────┴──────────────────┴───────┘

  If you cannot invest in at least 5 of these 8, do not adopt
  microservices. You will get the complexity without the benefits.
```

#### API-Led Coupling

API-led is not free from trade-offs either:

```
API-LED COUPLING — Hidden rigidity in the 3-tier model:

  1. Deployment coupling
     exp-orders ──► prc-orders ──► sys-orders
     If sys-orders changes its contract, prc-orders must update,
     then exp-orders must update. Three coordinated deployments.

  2. Shared runtime coupling
     All APIs on the same CloudHub region, same Anypoint org.
     Platform outage = everything is down.

  3. Governance coupling
     C4E review required before any API change.
     If C4E is slow, all teams are slow.

  Fix: Apply API-led selectively. Not every integration needs
  3 tiers. Use the collapse scoring from the anti-patterns recipe.
```

### How It Works
1. **Assess your current state** — how many teams, how often they deploy, what infrastructure exists
2. **Score against the decision matrix** — team size, autonomy needs, deployment frequency, governance requirements
3. **If hybrid, define the boundaries** — which concerns are "microservice" (data ownership, independent deploy) and which are "API-led" (catalog, policy enforcement, C4E review)
4. **Implement incrementally** — do not rewrite everything. Start with one domain as a microservice with API-led governance. Prove the pattern. Expand
5. **Budget for the tax** — whichever pattern you choose, account for the operational overhead before starting

### Gotchas
- **Microservices without observability is distributed debugging hell.** If you cannot trace a request across 5 services, you cannot diagnose production issues. Invest in distributed tracing before decomposing
- **API-led without domain thinking creates anemic tiers.** If your process API is just forwarding requests between experience and system APIs, you have the cost of three deployments with the benefit of zero
- **"We do microservices" often means "we have many small APIs with a shared database."** That is a distributed monolith — the worst of both worlds. If services share a database, they are not microservices
- **Team size is the strongest signal.** If you have fewer than 10 integration developers, microservices overhead will slow you down. API-led with MuleSoft gives you governance without the operational tax
- **Hybrid sounds great but requires discipline.** Without clear rules about which concerns live where, hybrid becomes "we do whatever we want and call it hybrid." Document the rules and enforce them through the C4E

### Related
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — When API-led tiers add cost without value
- [Domain-Driven API Design](../domain-driven-api-design/) — Domain boundaries inform both microservice and API-led decomposition
- [C4E Setup Playbook](../c4e-setup-playbook/) — The governance layer that makes hybrid patterns work
- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — Events are the preferred cross-domain communication for microservices
