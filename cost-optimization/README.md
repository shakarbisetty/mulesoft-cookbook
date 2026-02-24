# Cost Optimization

Recipes for reducing MuleSoft platform spend without sacrificing reliability or performance. Covers vCore sizing, API consolidation, licensing strategy, and infrastructure cost comparisons.

## Recipes

| Recipe | Description |
|--------|-------------|
| [vcore-right-sizing-calculator](./vcore-right-sizing-calculator/) | Workload profiling and vCore selection with TPS-based formulas and real cost math |
| [api-consolidation-patterns](./api-consolidation-patterns/) | Bundle low-traffic APIs into shared workers using domain multiplexer pattern to save 40-60% vCores |
| [usage-based-pricing-migration](./usage-based-pricing-migration/) | Evaluate and migrate from capacity-based to usage-based licensing with break-even analysis |
| [dev-sandbox-cost-reduction](./dev-sandbox-cost-reduction/) | Scheduled shutdowns, shared sandboxes, and mocking strategies to cut dev environment costs by 60-70% |
| [cloudhub-vs-rtf-vs-onprem-cost](./cloudhub-vs-rtf-vs-onprem-cost/) | 3-year TCO comparison across CloudHub, Runtime Fabric, and on-prem for real deployment scenarios |
| [license-audit-renewal-checklist](./license-audit-renewal-checklist/) | Pre-renewal audit checklist with CLI commands to find unused entitlements and negotiation leverage |
| [anypoint-mq-cost-optimization](./anypoint-mq-cost-optimization/) | Message batching, payload compression, and queue consolidation to reduce Anypoint MQ costs |

## Cost Optimization Strategy

Start with the highest-impact items:

1. **Right-size vCores** — most orgs over-provision by 2-3x
2. **Consolidate low-traffic APIs** — 5 idle APIs on separate workers is pure waste
3. **Shut down dev/sandbox** — non-production environments run 24/7 but are used 8 hours/day
4. **Audit before renewal** — know exactly what you use before negotiating
5. **Evaluate pricing model** — usage-based can save 30-50% for variable workloads
