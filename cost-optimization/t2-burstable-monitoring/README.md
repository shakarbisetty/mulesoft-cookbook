# T2 Burstable Instance Monitoring for CloudHub 0.1/0.2 vCores

## Problem

CloudHub 0.1 and 0.2 vCore workers run on AWS T2 burstable instances. These instances earn CPU credits when idle and spend them during bursts. When credits exhaust, performance drops to baseline (5-10% CPU), causing sudden latency spikes and timeouts that appear random. Teams misdiagnose this as application bugs or backend slowness, often upgrading to larger workers unnecessarily when the fix is understanding and monitoring burst credit dynamics.

## Solution

Implement monitoring for CPU credit accumulation and consumption on T2-backed CloudHub workers. Detect credit exhaustion before it impacts users, establish baseline vs burst usage patterns, and create data-driven criteria for when the burstable model is appropriate vs when to upgrade to a dedicated-CPU tier.

## Implementation

### T2 Credit Mechanics for CloudHub Workers

```
┌─────────────────────────────────────────────────────────────┐
│ CloudHub 0.1 vCore (T2.micro equivalent)                    │
│                                                             │
│ Baseline CPU:    10% of one core                            │
│ Credit earn rate: 6 credits/hour                            │
│ Max credit bank:  144 credits (24 hours of earning)         │
│ 1 credit = 1 vCPU at 100% for 1 minute                     │
│                                                             │
│ Burst capacity:  100% CPU for ~14.4 minutes (from full)     │
│ Sustained above  10%: credits drain                         │
│ Sustained below  10%: credits accumulate                    │
│                                                             │
│ At zero credits: HARD THROTTLE to 10% baseline              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CloudHub 0.2 vCore (T2.small equivalent)                    │
│                                                             │
│ Baseline CPU:    20% of one core                            │
│ Credit earn rate: 12 credits/hour                           │
│ Max credit bank:  288 credits                               │
│ Burst capacity:  100% CPU for ~28.8 minutes (from full)     │
│ At zero credits: HARD THROTTLE to 20% baseline              │
└─────────────────────────────────────────────────────────────┘
```

### Detecting Credit Exhaustion via Anypoint Monitoring

CloudHub does not expose T2 credit balance directly. Detect exhaustion through its symptoms:

#### Custom Dashboard Query — CPU Throttle Detection

```
// Anypoint Monitoring — Custom Dashboard
// Query: Detect sudden CPU ceiling (credit exhaustion signature)

// Panel 1: CPU Usage with Baseline Overlay
SELECT mean("cpu.usage") FROM "app_metrics"
WHERE "app_name" = 'your-app-name'
AND time > now() - 6h
GROUP BY time(1m) fill(previous)

// Add threshold line at 10% (0.1 vCore baseline) or 20% (0.2 vCore baseline)

// Panel 2: Latency Spike Correlation
SELECT percentile("response_time", 95) FROM "app_metrics"
WHERE "app_name" = 'your-app-name'
AND time > now() - 6h
GROUP BY time(1m)

// Panel 3: Throughput Drop (inverse correlation with CPU throttle)
SELECT count("request_count") FROM "app_metrics"
WHERE "app_name" = 'your-app-name'
AND time > now() - 6h
GROUP BY time(5m)
```

#### Credit Exhaustion Signature Pattern

```
Normal operation:        CPU oscillates between 5-80%
Credit earning:          CPU consistently below baseline (10% or 20%)
Credit spending:         CPU consistently above baseline
CREDIT EXHAUSTED:        CPU drops to exactly baseline and stays flat
                         Latency spikes 5-10x simultaneously
                         Throughput drops to 20-30% of normal

Timeline example (0.1 vCore):
  00:00-06:00  Low traffic, CPU at 5%     → Credits accumulating (144 max)
  06:00-08:00  Morning spike, CPU at 60%  → Burning ~50 credits/hour
  08:15        Credits hit zero           → CPU hard-capped at 10%
  08:15-08:45  All requests slow          → p95 latency: 200ms → 2000ms
  08:45+       Traffic drops, credits     → Gradual recovery over 30-60 min
               slowly recover
```

### Monitoring Implementation with DataWeave

#### Burst Budget Calculator

```dataweave
%dw 2.0
output application/json

var vcoreSize = 0.1
var creditConfig = {
    "0.1": { earnRate: 6, maxBank: 144, baselinePct: 10 },
    "0.2": { earnRate: 12, maxBank: 288, baselinePct: 20 }
}

var config = creditConfig[vcoreSize as String]

// Simulate a workday usage pattern
var hourlyUsageProfile = [
    // hour, avgCpuPercent
    { hour: 0,  cpu: 3 },  { hour: 1,  cpu: 3 },
    { hour: 2,  cpu: 3 },  { hour: 3,  cpu: 3 },
    { hour: 4,  cpu: 5 },  { hour: 5,  cpu: 8 },
    { hour: 6,  cpu: 25 }, { hour: 7,  cpu: 45 },
    { hour: 8,  cpu: 60 }, { hour: 9,  cpu: 55 },
    { hour: 10, cpu: 50 }, { hour: 11, cpu: 40 },
    { hour: 12, cpu: 30 }, { hour: 13, cpu: 50 },
    { hour: 14, cpu: 55 }, { hour: 15, cpu: 45 },
    { hour: 16, cpu: 35 }, { hour: 17, cpu: 20 },
    { hour: 18, cpu: 10 }, { hour: 19, cpu: 8 },
    { hour: 20, cpu: 5 },  { hour: 21, cpu: 4 },
    { hour: 22, cpu: 3 },  { hour: 23, cpu: 3 }
]

// Calculate credit balance hour by hour
var creditSimulation = hourlyUsageProfile reduce ((hour, acc = {
    balance: config.maxBank,
    history: [],
    exhaustedAt: null
}) -> do {
    var consumed = if (hour.cpu > config.baselinePct)
        ((hour.cpu - config.baselinePct) / 100) * 60  // minutes of burst
    else 0
    var earned = if (hour.cpu < config.baselinePct)
        config.earnRate
    else
        config.earnRate * (1 - (hour.cpu - config.baselinePct) / (100 - config.baselinePct))
    var newBalance = max([0, min([config.maxBank, acc.balance - consumed + earned])])
    ---
    {
        balance: newBalance,
        history: acc.history + [{
            hour: hour.hour,
            cpu: hour.cpu,
            creditsConsumed: consumed,
            creditsEarned: earned,
            creditBalance: newBalance,
            throttled: newBalance == 0
        }],
        exhaustedAt: if (acc.exhaustedAt == null and newBalance == 0) hour.hour
                     else acc.exhaustedAt
    }
})
---
{
    vcoreSize: vcoreSize,
    maxCredits: config.maxBank,
    baselineCpu: config.baselinePct,
    simulation: creditSimulation.history,
    creditExhaustedAtHour: creditSimulation.exhaustedAt,
    recommendation: if (creditSimulation.exhaustedAt != null)
        "UPGRADE NEEDED - Credits exhaust at hour $(creditSimulation.exhaustedAt). Consider 0.5 vCore (dedicated CPU)."
    else
        "BURSTABLE OK - Credits never exhaust under this usage pattern."
}
```

### Alert Configuration

```yaml
# Anypoint Monitoring Alert Rules for T2 Burstable Workers

alerts:
  - name: "CPU Credit Exhaustion Warning"
    condition: "cpu_usage == baseline_pct for > 5 minutes AND response_time_p95 > 2x normal"
    severity: warning
    message: "Worker may be CPU-throttled due to T2 credit exhaustion"
    action: "Check if off-peak recovery is sufficient; consider upgrading to 0.5 vCore"

  - name: "Sustained Above Baseline"
    condition: "avg(cpu_usage, 1h) > baseline_pct"
    severity: info
    message: "CPU usage sustained above T2 baseline — credits are draining"
    action: "Monitor credit balance; will exhaust in approximately X hours"

  - name: "Burst Pattern Incompatible"
    condition: "avg(cpu_usage, 8h) > baseline_pct for 3 consecutive days"
    severity: critical
    message: "Workload is not burst-compatible; sustained usage exceeds T2 baseline"
    action: "Upgrade to 0.5 vCore or higher (dedicated CPU, no throttling)"
```

### Upgrade Decision Criteria

| Signal | Threshold | Action |
|--------|-----------|--------|
| Daily credit exhaustion | Exhausts before noon | Upgrade to 0.5 vCore |
| Weekly credit exhaustion | Exhausts 2+ days/week | Upgrade to 0.5 vCore |
| Average CPU > baseline | 8-hour avg above 10%/20% | Burstable model is wrong fit |
| Peak CPU always below baseline | Never exceeds 10%/20% | Correct fit; stay on burstable |
| Short spikes, quick recovery | Exhausts but recovers in <1h | Acceptable; monitor |

## How It Works

1. **Understand the credit model.** T2 instances earn credits when idle and spend them when busy. CloudHub 0.1 and 0.2 vCores use this model. Larger sizes (0.5+) use dedicated CPU with no throttling.
2. **Set up monitoring panels** in Anypoint Monitoring that overlay CPU usage with the baseline threshold (10% for 0.1, 20% for 0.2). When CPU drops to exactly the baseline and latency spikes simultaneously, that is credit exhaustion.
3. **Run the burst budget calculator** with your actual hourly CPU profile to simulate credit dynamics over a 24-hour period. If credits exhaust during business hours, the burstable model is wrong for this workload.
4. **Configure alerts** for the exhaustion signature pattern (CPU at baseline + latency spike) so the team is notified proactively.
5. **Upgrade to 0.5 vCore** when the workload consistently needs CPU above the burstable baseline. The 0.5 vCore costs more but provides dedicated, non-throttled CPU.

## Key Takeaways

- CloudHub 0.1/0.2 vCores run on T2 burstable instances; CPU is not guaranteed above 10%/20%.
- Credit exhaustion looks like a random performance collapse and is frequently misdiagnosed.
- If average CPU exceeds the baseline for more than a few hours daily, burstable is the wrong choice.
- The jump from 0.2 to 0.5 vCore eliminates throttling entirely; it is the most impactful upgrade path.
- Night and weekend idle time is essential for credit recovery; 24/7 workloads above baseline will always throttle.

## Related Recipes

- [vcore-benchmark-by-workload](../vcore-benchmark-by-workload/) — Performance benchmarks include burstable caveats
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Sizing that accounts for T2 limitations
- [idle-worker-detection](../idle-worker-detection/) — Complementary: detect workers that never need burst capacity
- [cost-monitoring-dashboard](../cost-monitoring-dashboard/) — Include T2 alerts in the cost dashboard
