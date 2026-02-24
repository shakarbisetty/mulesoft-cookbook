## License Audit & Renewal Checklist
> Systematic pre-renewal audit with CLI commands to identify unused entitlements, idle workers, and negotiation leverage points.

### When to Use
- MuleSoft license renewal is within 90 days
- Preparing a cost optimization business case for leadership
- Suspecting significant entitlement waste (vCores allocated but unused)
- Negotiating with MuleSoft sales and need data-backed leverage
- Post-acquisition integration where multiple MuleSoft contracts need consolidation

### Configuration / Code

#### Pre-Renewal Audit Checklist

```yaml
90_days_before_renewal:
  entitlement_audit:
    - [ ] Export current contract entitlements (vCores, environments, add-ons)
    - [ ] List all deployed applications across all environments
    - [ ] Identify allocated but unused vCores (provisioned - deployed)
    - [ ] Flag workers with < 10% avg CPU over 30 days
    - [ ] Flag workers with < 30% avg memory over 30 days
    - [ ] Calculate total vCore utilization ratio (used / entitled)

  environment_audit:
    - [ ] List all environments (production, sandbox, design)
    - [ ] Identify environments with zero deployments
    - [ ] Check for abandoned sandbox environments from former employees
    - [ ] Review Design Center project count vs active developers

  feature_audit:
    - [ ] Check API Manager tier usage (basic vs advanced policies)
    - [ ] Verify Anypoint MQ usage vs entitlement
    - [ ] Review DataGraph, Visualizer, Monitoring tier utilization
    - [ ] Identify entitled features never activated

  usage_metrics:
    - [ ] Pull 12-month API call volume trends
    - [ ] Identify APIs with declining traffic (candidates for retirement)
    - [ ] Calculate cost per API call across the portfolio
    - [ ] Document peak vs average utilization ratios

60_days_before_renewal:
  negotiation_prep:
    - [ ] Calculate total waste (unused vCores × remaining months × rate)
    - [ ] Prepare right-sizing proposal (target allocation vs current)
    - [ ] Research competitive alternatives (AWS API Gateway, Kong, Apigee)
    - [ ] Draft multi-year discount request (3-year commit for lower rate)
    - [ ] Identify expansion areas to trade for better pricing

30_days_before_renewal:
    - [ ] Present findings to procurement/finance
    - [ ] Schedule negotiation call with MuleSoft account team
    - [ ] Set hard deadline for counter-offer (2 weeks before auto-renewal)
    - [ ] Review auto-renewal clause and opt-out window
```

#### CLI Commands: Full Entitlement Audit

```bash
#!/bin/bash
# license-audit.sh — Comprehensive entitlement audit
# Requires: anypoint-cli (v4+), jq

echo "=========================================="
echo "  MuleSoft License Audit Report"
echo "  Generated: $(date)"
echo "=========================================="

# --- 1. List all environments ---
echo -e "\n--- ENVIRONMENTS ---"
anypoint-cli account environment list --output json | jq -r '.[] | "\(.name)\t\(.type)\t\(.id)"'

# --- 2. List all applications per environment ---
echo -e "\n--- DEPLOYED APPLICATIONS ---"
for ENV in Production Sandbox Design; do
  echo -e "\n  Environment: $ENV"
  anypoint-cli runtime-mgr cloudhub-application list \
    --environment "$ENV" --output json 2>/dev/null | \
    jq -r '.[] | "    \(.domain)\tvCores: \(.workers.type.weight)\tWorkers: \(.workers.amount)\tStatus: \(.status)"'
done

# --- 3. Calculate total vCore allocation ---
echo -e "\n--- VCORE ALLOCATION SUMMARY ---"
for ENV in Production Sandbox Design; do
  VCORES=$(anypoint-cli runtime-mgr cloudhub-application list \
    --environment "$ENV" --output json 2>/dev/null | \
    jq '[.[] | .workers.type.weight * .workers.amount] | add // 0')
  echo "  $ENV: $VCORES vCores"
done

# --- 4. Find idle workers (STARTED but no traffic) ---
echo -e "\n--- POTENTIALLY IDLE WORKERS ---"
anypoint-cli runtime-mgr cloudhub-application list \
  --environment Production --output json | \
  jq -r '.[] | select(.status == "STARTED") | .domain' | while read APP; do

  # Check last 7 days of request count
  REQUESTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://anypoint.mulesoft.com/analytics/1.0/$ORG_ID/environments/$ENV_ID/events?apiName=$APP&duration=7d" | \
    jq 'length')

  if [ "$REQUESTS" -lt 100 ]; then
    echo "  IDLE: $APP ($REQUESTS requests in 7 days)"
  fi
done

# --- 5. Find stopped workers still consuming entitlement ---
echo -e "\n--- STOPPED BUT ALLOCATED WORKERS ---"
for ENV in Production Sandbox Design; do
  anypoint-cli runtime-mgr cloudhub-application list \
    --environment "$ENV" --output json 2>/dev/null | \
    jq -r '.[] | select(.status != "STARTED") | "  [\(.status)] \(.domain) in '$ENV' — \(.workers.type.weight) vCores allocated"'
done

# --- 6. API Manager — unused API instances ---
echo -e "\n--- API MANAGER INSTANCES ---"
anypoint-cli api-mgr api list \
  --environment Production --output json | \
  jq -r '.[] | "\(.assetId)\tv\(.assetVersion)\tStatus: \(.status)\tEndpoint: \(.endpointUri // "none")"'
```

#### Waste Calculation Template

```
Annual Waste Estimate:

  Entitled vCores:                    ___
  Deployed vCores (running):          ___
  Deployed vCores (stopped):          ___
  Unused vCores:                      ___ (entitled - deployed running)

  Idle Workers (< 100 req/week):      ___
  Idle Worker vCores:                 ___

  Total Waste vCores:                 ___ (unused + idle)
  Monthly vCore Rate:                 $___

  Annual Waste = Total Waste vCores × Monthly Rate × 12
               = ___ × $___ × 12
               = $___/year

  Recommended Right-Size:
    Production:  ___ vCores (down from ___)
    Sandbox:     ___ vCores (down from ___)
    Design:      ___ vCores (down from ___)
    Total:       ___ vCores (saving ___%)
```

#### Negotiation Leverage Points

| Leverage | How to Use It | Typical Impact |
|----------|---------------|----------------|
| **Documented waste** | Show exact unused vCores with CLI output | 10-20% reduction |
| **Competitive quotes** | Get written quotes from AWS API GW, Kong, Apigee | 5-15% discount |
| **Multi-year commit** | Offer 3-year lock-in for better annual rate | 15-25% discount |
| **Expansion trade** | Add new use cases (MQ, RTF) in exchange for lower per-vCore rate | 10-15% discount |
| **Usage-based switch** | Threaten to switch pricing models (if usage-based is cheaper) | 10-20% reduction |
| **Timing** | Negotiate at MuleSoft's fiscal quarter/year end (Jan 31) | 5-10% extra |
| **Executive escalation** | Engage MuleSoft VP of Sales if rep won't budge | Unlocks deeper discounts |

### How It Works
1. Run the license audit script 90 days before renewal to get a complete picture of entitlement utilization
2. Calculate total waste in dollar terms — unused vCores, idle workers, empty environments
3. Build a right-sizing proposal showing current vs recommended allocation with specific apps to downsize or retire
4. Research competitive alternatives and get written quotes — even if you plan to stay on MuleSoft, competitive pressure drives discounts
5. Present findings to procurement/finance with a clear "current spend vs optimized spend" comparison
6. Schedule negotiation 30-60 days before renewal — too early and the rep has no urgency, too late and auto-renewal kicks in
7. Lead with data — show the audit report, waste calculation, and competitive quotes; request specific vCore reduction and rate discount

### Gotchas
- **Auto-renewal clauses** — most MuleSoft contracts auto-renew 30-60 days before expiration at existing terms plus annual escalation (typically 3-7%); know your opt-out window
- **Use-it-or-lose-it entitlements** — some contracts have provisions where unused entitlements from the current term cannot be reduced at renewal; push back on this during negotiation
- **Stopped workers may still count** — some contracts count allocated (not running) vCores against entitlements; delete stopped applications, don't just stop them
- **Sandbox vCores are cheaper but still cost money** — non-production entitlements are typically 50-60% of production rates, but they still add up; audit sandboxes aggressively
- **Feature bundling obscures costs** — MuleSoft bundles features (API Manager, MQ, Monitoring) into tiers; you may be paying for Titanium tier when Gold tier covers your actual usage
- **Procurement timelines** — large enterprises need 4-6 weeks for legal review of contract changes; start early to avoid being forced into auto-renewal
- **MuleSoft fiscal year ends January 31** — reps are most flexible on pricing in December-January; align your renewal timing if possible

### Related
- [vCore Right-Sizing Calculator](../vcore-right-sizing-calculator/) — detailed sizing to support right-size proposal
- [API Consolidation Patterns](../api-consolidation-patterns/) — consolidate before renewal to reduce required vCores
- [Usage-Based Pricing Migration](../usage-based-pricing-migration/) — evaluate alternative pricing model before renewing
- [Dev Sandbox Cost Reduction](../dev-sandbox-cost-reduction/) — reduce sandbox costs as part of renewal optimization
- [CloudHub vs RTF vs On-Prem Cost](../cloudhub-vs-rtf-vs-onprem-cost/) — evaluate platform alternatives before committing
