# Architecture Recipes

Strategic architecture patterns, governance playbooks, and decision frameworks for MuleSoft integration platforms. These recipes go beyond "how to configure" into "when, why, and what trade-offs."

## Recipes

| # | Recipe | Summary |
|---|--------|---------|
| 1 | [API-Led Anti-Patterns](api-led-anti-patterns/) | When 3-tier API-led is overkill and how to simplify |
| 2 | [C4E Setup Playbook](c4e-setup-playbook/) | Center for Enablement team structure, KPIs, and governance |
| 3 | [Event-Driven Architecture](event-driven-architecture-mulesoft/) | Anypoint MQ, VM queues, CDC, and when events beat request-reply |
| 4 | [Domain-Driven API Design](domain-driven-api-design/) | Map bounded contexts to API boundaries |
| 5 | [Multi-Region DR Strategy](multi-region-dr-strategy/) | Active-Active vs Active-Passive failover with RTO/RPO targets |
| 6 | [Application Network Topology](application-network-topology/) | Map your API catalog as a network graph, find bottlenecks |
| 7 | [Microservices vs API-Led](microservices-vs-api-led/) | When to use each, hybrid patterns, and the microservices tax |
| 8 | [Integration Maturity Model](integration-maturity-model/) | Level 1 (point-to-point) through Level 5 (composable enterprise) |
| 9 | [API-Led Layer Decision Framework](api-led-layer-decision-framework/) | When to use 1, 2, or 3 layers based on traffic, team size, complexity |
| 10 | [API-Led Performance Patterns](api-led-performance-patterns/) | Eliminating unnecessary hops, direct-to-system, async experience layer |
| 11 | [Orchestration vs Choreography](orchestration-vs-choreography/) | Decision framework with trade-off matrix for integration patterns |
| 12 | [Sync-Async Decision Flowchart](sync-async-decision-flowchart/) | Thread pool, latency, and reliability trade-offs |
| 13 | [Circuit Breaker in MuleSoft](circuit-breaker-mulesoft/) | Object Store state machine with trip, reset, and half-open |
| 14 | [Multi-Region Active-Active Blueprint](multi-region-active-active-blueprint/) | Load balancing, data consistency, and failover |
| 15 | [Deployment Model Decision Matrix](deployment-model-decision-matrix/) | CloudHub vs RTF vs Hybrid with cost, compliance, latency factors |
| 16 | [Hexagonal Architecture for MuleSoft](hexagonal-architecture-mulesoft/) | Ports and adapters for decoupling business logic from connectors |
| 17 | [CQRS Implementation](cqrs-implementation/) | Command/query separation with event sourcing bridge |
| 18 | [API Versioning Strategy](api-versioning-strategy/) | URI vs header vs media-type, migration patterns |
| 19 | [Anti-Corruption Layer](anti-corruption-layer/) | Legacy system isolation with data translation boundaries |
| 20 | [Strangler Fig Migration](strangler-fig-migration/) | Incremental legacy replacement with MuleSoft routing |
| 21 | [Rate Limiting Architecture](rate-limiting-architecture/) | Multi-tier rate limiting across gateway, app, and backend |
| 22 | [Data Mesh Integration](data-mesh-integration/) | MuleSoft as data product APIs with domain-owned data |
| 23 | [Zero-Trust API Architecture](zero-trust-api-architecture/) | mTLS everywhere, token validation chain, least privilege |

## How to Use These Recipes

Each recipe follows a consistent structure:

- **When to Use** — situational triggers and preconditions
- **Configuration / Code** — diagrams, decision trees, XML, real guidance
- **How It Works** — step-by-step walkthrough
- **Gotchas** — common mistakes and misunderstandings
- **Related** — cross-references to other recipes
