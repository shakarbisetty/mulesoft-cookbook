## Usage-Based Pricing Migration
> Evaluate switching from capacity-based to usage-based MuleSoft licensing to align costs with actual API consumption.

### When to Use
- Current vCore entitlements are significantly under-utilized (<40% average across the org)
- API traffic is highly seasonal or variable (e.g., retail with holiday peaks, batch-heavy workloads)
- Expanding API program rapidly and want costs to scale linearly with adoption
- Approaching license renewal and want leverage to negotiate better terms
- Running many low-traffic internal APIs that inflate capacity requirements disproportionately

### Configuration / Code

#### Pricing Model Comparison

| Dimension | Capacity-Based | Usage-Based (Flex Gateway) |
|-----------|---------------|---------------------------|
| **Unit** | vCores (fixed allocation) | API calls / messages (metered) |
| **Billing** | Fixed annual commitment | Pay-per-use with floor commitment |
| **Scaling cost** | Step function (add vCores in chunks) | Linear (cost grows with traffic) |
| **Idle cost** | Full price even at 0 TPS | Minimal floor charge |
| **Burst handling** | Must pre-provision headroom | Scales automatically, billed per call |
| **Best for** | Stable, high-traffic APIs | Variable traffic, many low-use APIs |
| **Risk** | Over-provisioning waste | Unexpected traffic spikes = bill shock |
| **Typical savings** | — | 30-50% for orgs with <40% avg utilization |

#### Step 1: Audit Current Usage

```bash
# Export all applications and their vCore allocation
anypoint-cli runtime-mgr cloudhub-application list \
  --environment Production \
  --output json > current_apps.json

# Calculate total allocated vCores
cat current_apps.json | jq '[.[].workers.type.weight * .[].workers.amount] | add'

# Export API analytics for the last 90 days
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://anypoint.mulesoft.com/analytics/1.0/$ORG_ID/environments/$ENV_ID/events?duration=90d&fields=api_name,status_code,request_size,response_size" \
  --output analytics_90d.json
```

#### Step 2: Calculate Actual Consumption

```bash
# Monthly API call volume per API
cat analytics_90d.json | jq '
  group_by(.api_name) |
  map({
    api: .[0].api_name,
    total_calls: length,
    monthly_avg: (length / 3),
    avg_payload_kb: ([.[].request_size + .[].response_size] | add / length / 1024)
  }) |
  sort_by(-.total_calls)'
```

#### Step 3: Break-Even Analysis

```
Break-Even Point:
  Capacity cost per month = (Total vCores × Monthly vCore price)
  Usage cost per month = (Total API calls × Per-call rate) + Floor commitment

  Break-even calls/month = (Capacity cost - Floor commitment) / Per-call rate
```

**Example calculation:**

| Parameter | Value |
|-----------|-------|
| Current allocation | 10 vCores |
| Capacity cost | $6,000/mo ($600/vCore/mo list price) |
| Actual monthly calls | 8 million |
| Usage rate | $0.0004 per call |
| Usage floor commitment | $1,500/mo |
| **Usage cost** | **(8M × $0.0004) + $1,500 = $4,700/mo** |
| **Monthly savings** | **$1,300/mo (21.7%)** |
| **Annual savings** | **$15,600/yr** |
| **Break-even** | **11.25M calls/mo — above this, capacity is cheaper** |

#### Step 4: Traffic Variability Assessment

```bash
# Calculate coefficient of variation (CV) for monthly traffic
# CV > 0.3 = high variability = usage-based likely wins
cat analytics_90d.json | jq '
  group_by(.month) |
  map(length) as $monthly |
  ($monthly | add / length) as $mean |
  ($monthly | map(. - $mean | . * .) | add / length | sqrt) as $stddev |
  {
    monthly_volumes: $monthly,
    mean: $mean,
    stddev: $stddev,
    cv: ($stddev / $mean),
    recommendation: (if ($stddev / $mean) > 0.3 then "USAGE-BASED" else "CAPACITY-BASED" end)
  }'
```

#### Migration Checklist

```yaml
pre-migration:
  - Export 90-day API analytics from Anypoint Platform
  - Document current vCore allocation per environment (prod, sandbox, design)
  - Identify APIs with < 1000 calls/day (strong consolidation/usage candidates)
  - Calculate break-even call volume for your negotiated rates
  - Model 3 scenarios: current traffic, 2x growth, 0.5x reduction

negotiation:
  - Request usage-based pricing quote from MuleSoft account team
  - Negotiate per-call rate tiers (volume discounts at 10M, 50M, 100M calls/mo)
  - Negotiate floor commitment (aim for 60-70% of projected minimum monthly usage)
  - Ensure burst protection clause (cap on per-call rate during spikes)
  - Request 90-day trial/parallel-run period to validate projections

migration:
  - Deploy Anypoint Flex Gateway for usage metering (replaces Mule Gateway for edge APIs)
  - Configure API Manager policies on Flex Gateway instances
  - Set up billing alerts at 80% and 100% of projected monthly budget
  - Monitor daily call volumes for first 30 days vs projections
  - Adjust floor commitment at first renewal based on actuals

post-migration:
  - Compare actual monthly cost vs capacity-based projection for 6 months
  - Review per-API cost attribution for chargeback to business units
  - Evaluate Flex Gateway performance vs CloudHub-hosted gateway
  - Document lessons learned for next renewal cycle
```

### How It Works
1. Export 90 days of API analytics to establish a traffic baseline — daily and monthly call volumes, payload sizes, and error rates
2. Calculate total monthly API calls and compare against the break-even point where usage-based becomes cheaper than capacity-based
3. Assess traffic variability using coefficient of variation — high variability (CV > 0.3) strongly favors usage-based pricing
4. Model three scenarios (current, 2x growth, contraction) to ensure usage-based wins across likely futures
5. Negotiate usage-based terms with MuleSoft — volume tier discounts, floor commitment, and burst protection are the key levers
6. Run a parallel period (if possible) where you meter usage on Flex Gateway while still running capacity workers
7. Cut over to usage-based billing and set up daily cost monitoring alerts

### Gotchas
- **Burst traffic = bill shock** — a DDoS attack, partner integration gone wrong, or retry storm can generate millions of unexpected calls; negotiate a burst cap or circuit-breaker clause
- **Minimum floor commitment** — usage-based still has a monthly minimum; if your traffic drops below that, you pay the floor regardless; negotiate the floor to 60-70% of your projected minimum
- **Per-call vs per-message** — MQ messages, event-driven flows, and webhook callbacks may be billed differently from synchronous API calls; clarify what counts as a "billable event"
- **Flex Gateway requirement** — usage metering may require deploying Anypoint Flex Gateway; factor in the migration effort from CloudHub-hosted API gateway
- **Chargeback complexity** — capacity-based is simple (team X owns Y vCores); usage-based requires per-API cost attribution which needs tagging and reporting infrastructure
- **Auto-renewal trap** — if you don't explicitly switch pricing models before the renewal date, many contracts auto-renew on the existing capacity-based terms

### Related
- [License Audit & Renewal Checklist](../license-audit-renewal-checklist/) — pre-renewal audit to maximize negotiation leverage
- [vCore Right-Sizing Calculator](../vcore-right-sizing-calculator/) — if staying capacity-based, at least right-size
- [API Consolidation Patterns](../api-consolidation-patterns/) — reduce vCore count as a stopgap before switching models
- [CloudHub vs RTF vs On-Prem Cost](../cloudhub-vs-rtf-vs-onprem-cost/) — infrastructure model affects licensing options
