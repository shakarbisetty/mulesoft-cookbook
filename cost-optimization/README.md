# Cost Optimization

Recipes for reducing MuleSoft platform spend without sacrificing reliability or performance. Covers vCore sizing, API consolidation, licensing strategy, infrastructure cost comparisons, TCO analysis, chargeback frameworks, and decision tools for when MuleSoft is (and is not) the right choice.

## Recipes

| Recipe | Description |
|--------|-------------|
| [vcore-right-sizing-calculator](./vcore-right-sizing-calculator/) | Workload profiling and vCore selection with TPS-based formulas and real cost math |
| [vcore-benchmark-by-workload](./vcore-benchmark-by-workload/) | Performance benchmarks by worker size and workload type (proxy, transform, batch, messaging) |
| [scale-up-vs-scale-out-decision](./scale-up-vs-scale-out-decision/) | Decision framework for vertical vs horizontal scaling with cost comparison and anti-patterns |
| [t2-burstable-monitoring](./t2-burstable-monitoring/) | Monitoring CloudHub 0.1/0.2 vCore T2 burstable instance CPU credits and throttling detection |
| [connection-pool-tuning-by-vcore](./connection-pool-tuning-by-vcore/) | HikariCP and HTTP pool tuning optimized by vCore size to prevent OOM on small workers |
| [api-consolidation-patterns](./api-consolidation-patterns/) | Bundle low-traffic APIs into shared workers using domain multiplexer pattern to save 40-60% vCores |
| [two-layer-vs-three-layer-cost](./two-layer-vs-three-layer-cost/) | When two-layer architecture beats three-layer for cost by eliminating unnecessary Process APIs |
| [idle-worker-detection](./idle-worker-detection/) | Automated detection of underutilized workers with rightsizing recommendations and alerts |
| [dev-sandbox-cost-reduction](./dev-sandbox-cost-reduction/) | Scheduled shutdowns, shared sandboxes, and mocking strategies to cut dev environment costs by 60-70% |
| [cost-monitoring-dashboard](./cost-monitoring-dashboard/) | Build a unified cost dashboard from Anypoint Platform APIs with alerts and monthly reports |
| [cost-chargeback-framework](./cost-chargeback-framework/) | Per-team cost allocation with tagging, shared cost distribution, and showback/chargeback models |
| [mulesoft-tco-calculator](./mulesoft-tco-calculator/) | Realistic Total Cost of Ownership calculator covering license, infra, people, training, and hidden costs |
| [mulesoft-hidden-costs-checklist](./mulesoft-hidden-costs-checklist/) | Systematic checklist for identifying overlooked costs before procurement and renewal |
| [realistic-tco-comparison](./realistic-tco-comparison/) | 3-year TCO comparison: MuleSoft vs Boomi vs Workato vs custom code vs serverless at three scales |
| [roia-calculator](./roia-calculator/) | Return on Integration Assets calculator measuring time saved, error reduction, reuse, and agility |
| [when-not-to-use-mulesoft](./when-not-to-use-mulesoft/) | Honest decision framework for when MuleSoft is the wrong tool with cheaper alternative comparisons |
| [cloudhub-vs-rtf-vs-onprem-cost](./cloudhub-vs-rtf-vs-onprem-cost/) | 3-year TCO comparison across CloudHub, Runtime Fabric, and on-prem for real deployment scenarios |
| [cloudhub-1-to-2-cost-analysis](./cloudhub-1-to-2-cost-analysis/) | Cost-benefit analysis framework for CloudHub 1.0 to 2.0 migration with effort model and decision matrix |
| [ch2-shared-vs-private-space](./ch2-shared-vs-private-space/) | CloudHub 2.0 shared vs private space cost decision matrix with scenarios saving 60%+ |
| [usage-based-pricing-migration](./usage-based-pricing-migration/) | Evaluate and migrate from capacity-based to usage-based licensing with break-even analysis |
| [license-audit-renewal-checklist](./license-audit-renewal-checklist/) | Pre-renewal audit checklist with CLI commands to find unused entitlements and negotiation leverage |
| [anypoint-mq-cost-optimization](./anypoint-mq-cost-optimization/) | Message batching, payload compression, and queue consolidation to reduce Anypoint MQ costs |

## Cost Optimization Strategy

Start with the highest-impact items:

1. **Right-size vCores** — most orgs over-provision by 2-3x ([benchmarks](./vcore-benchmark-by-workload/), [calculator](./vcore-right-sizing-calculator/))
2. **Detect idle workers** — 15-30% of vCores are typically wasted on idle apps ([detection](./idle-worker-detection/))
3. **Consolidate low-traffic APIs** — 5 idle APIs on separate workers is pure waste ([patterns](./api-consolidation-patterns/))
4. **Simplify architecture** — eliminate unnecessary Process layer APIs ([two vs three layer](./two-layer-vs-three-layer-cost/))
5. **Tune connection pools** — prevent OOM crashes that cause unnecessary vCore upgrades ([tuning guide](./connection-pool-tuning-by-vcore/))
6. **Shut down dev/sandbox** — non-production environments run 24/7 but are used 8 hours/day ([reduction](./dev-sandbox-cost-reduction/))
7. **Build cost visibility** — track spend by app, team, and environment ([dashboard](./cost-monitoring-dashboard/), [chargeback](./cost-chargeback-framework/))
8. **Audit before renewal** — know exactly what you use before negotiating ([checklist](./license-audit-renewal-checklist/))
9. **Evaluate pricing model** — usage-based can save 30-50% for variable workloads ([migration](./usage-based-pricing-migration/))
10. **Measure ROI** — prove platform value to protect budget ([ROIA calculator](./roia-calculator/))
