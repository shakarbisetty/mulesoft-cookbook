# Automated Idle Worker Detection and Rightsizing Alerts

## Problem

Organizations deploy MuleSoft applications and rarely revisit their resource allocation. Over time, traffic patterns change: APIs get deprecated, batch jobs get disabled, test apps stay deployed. Studies of CloudHub deployments consistently find 15-30% of production vCores allocated to workers with sustained CPU below 5% and memory below 30%. At $150/vCore/month, a 20-vCore deployment wastes $3,600-10,800 annually on idle workers that nobody notices until contract renewal.

## Solution

Automated detection of underutilized CloudHub workers using Anypoint Monitoring metrics and the Platform API. Implements a rightsizing recommendation engine that analyzes historical usage patterns, flags idle workers, suggests downsizing options, and generates alerts for the platform team.

## Implementation

### Idle Worker Detection Criteria

```
IDLE WORKER definition (all must be true for 7+ consecutive days):
  - Average CPU utilization   < 5%
  - Peak CPU utilization      < 15%
  - Average memory utilization < 30%
  - Request count             < 10/day (for HTTP-triggered apps)
  - No batch job executions   in the past 7 days

UNDERUTILIZED WORKER definition (for 14+ consecutive days):
  - Average CPU utilization   < 15%
  - Peak CPU utilization      < 40%
  - Average memory utilization < 50%
  - vCore size could be reduced by one tier
```

### Detection Flow

```xml
<flow name="idle-worker-detection">
    <scheduler>
        <scheduling-strategy>
            <!-- Run daily at 6 AM -->
            <cron expression="0 0 6 * * ?"/>
        </scheduling-strategy>
    </scheduler>

    <!-- Get all deployed applications -->
    <http:request config-ref="anypointApiConfig"
                  method="GET"
                  path="/cloudhub/api/v2/applications">
        <http:headers>
            #[{'Authorization': 'Bearer ' ++ vars.authToken,
               'X-ANYPNT-ENV-ID': '${env.production.id}'}]
        </http:headers>
    </http:request>

    <set-variable variableName="allApps" value="#[payload]"/>

    <!-- For each app, query 7-day metrics from Anypoint Monitoring -->
    <foreach collection="#[vars.allApps]">
        <set-variable variableName="currentApp" value="#[payload]"/>

        <!-- Query CPU metrics -->
        <http:request config-ref="monitoringApiConfig"
                      method="POST"
                      path="/monitoring/query">
            <http:body><![CDATA[{
                "query": "SELECT mean(cpu_usage), max(cpu_usage), mean(memory_usage) FROM app_metrics WHERE app_name = '${vars.currentApp.domain}' AND time > now() - 7d GROUP BY time(1d)"
            }]]></http:body>
        </http:request>

        <!-- Analyze and classify -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json

var metrics = payload.results
var avgCPU = (metrics map $.meanCpu) then (avg($))
var maxCPU = max(metrics map $.maxCpu) default 0
var avgMemory = (metrics map $.meanMemory) then (avg($))
var vcoreSize = vars.currentApp.workers."type".weight default 0
var workerCount = vars.currentApp.workers.amount default 1
var monthlyCost = vcoreSize * workerCount * 150
---
{
    appName: vars.currentApp.domain,
    vcoreSize: vcoreSize,
    workerCount: workerCount,
    monthlyCost: monthlyCost,
    metrics: {
        avgCPU: avgCPU,
        maxCPU: maxCPU,
        avgMemory: avgMemory
    },
    classification: if (avgCPU < 5 and maxCPU < 15 and avgMemory < 30)
        "IDLE"
    else if (avgCPU < 15 and maxCPU < 40 and avgMemory < 50)
        "UNDERUTILIZED"
    else
        "ACTIVE",
    recommendation: if (avgCPU < 5 and maxCPU < 15 and avgMemory < 30)
        "STOP or UNDEPLOY - This app has near-zero usage. Verify it is still needed."
    else if (avgCPU < 15 and maxCPU < 40 and avgMemory < 50)
        "DOWNSIZE - Reduce vCore from $(vcoreSize) to $(vcoreSize / 2). " ++
        "Estimated savings: $$(monthlyCost / 2)/month."
    else
        "NO ACTION - Current sizing is appropriate."
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </foreach>
</flow>
```

### Rightsizing Recommendation Engine

```dataweave
%dw 2.0
output application/json

var appMetrics = [
    { app: "customer-api-prod",     vcore: 1.0, workers: 2, avgCPU: 3,  maxCPU: 8,   avgMem: 25 },
    { app: "order-process-api",     vcore: 0.5, workers: 1, avgCPU: 12, maxCPU: 35,  avgMem: 45 },
    { app: "legacy-batch-sync",     vcore: 2.0, workers: 1, avgCPU: 1,  maxCPU: 5,   avgMem: 18 },
    { app: "notification-service",  vcore: 0.2, workers: 1, avgCPU: 2,  maxCPU: 10,  avgMem: 22 },
    { app: "partner-gateway",       vcore: 1.0, workers: 1, avgCPU: 45, maxCPU: 78,  avgMem: 65 },
    { app: "reporting-api",         vcore: 0.5, workers: 1, avgCPU: 8,  maxCPU: 22,  avgMem: 38 },
    { app: "test-api-leftover",     vcore: 0.5, workers: 1, avgCPU: 0,  maxCPU: 0,   avgMem: 20 },
    { app: "event-processor",       vcore: 1.0, workers: 2, avgCPU: 30, maxCPU: 65,  avgMem: 55 }
]

var vcoreTiers = [0.1, 0.2, 0.5, 1.0, 2.0, 4.0]
var vcoreMonthlyCost = 150

fun findOptimalVCore(maxCPU, avgMem) =
    if (maxCPU < 15 and avgMem < 30) 0.1
    else if (maxCPU < 40 and avgMem < 50) 0.2
    else if (maxCPU < 60 and avgMem < 65) 0.5
    else if (maxCPU < 80 and avgMem < 75) 1.0
    else if (maxCPU < 90 and avgMem < 85) 2.0
    else 4.0

var recommendations = appMetrics map ((app) -> do {
    var currentCost = app.vcore * app.workers * vcoreMonthlyCost
    var optimalVCore = findOptimalVCore(app.maxCPU, app.avgMem)
    var optimalWorkers = if (app.avgCPU < 5 and app.maxCPU < 15) 0
                         else if (app.workers > 1 and app.avgCPU < 30) 1
                         else app.workers
    var optimalCost = optimalVCore * max([optimalWorkers, if (optimalWorkers == 0) 0 else 1]) * vcoreMonthlyCost
    ---
    {
        app: app.app,
        current: { vcore: app.vcore, workers: app.workers, monthlyCost: currentCost },
        recommended: { vcore: optimalVCore, workers: optimalWorkers, monthlyCost: optimalCost },
        action: if (optimalWorkers == 0) "UNDEPLOY"
                else if (optimalVCore < app.vcore or optimalWorkers < app.workers) "DOWNSIZE"
                else "KEEP",
        monthlySavings: currentCost - optimalCost
    }
})

var totalCurrentCost = recommendations reduce ((r, t = 0) -> t + r.current.monthlyCost)
var totalOptimalCost = recommendations reduce ((r, t = 0) -> t + r.recommended.monthlyCost)
---
{
    recommendations: recommendations filter ((r) -> r.action != "KEEP"),
    summary: {
        totalAppsAnalyzed: sizeOf(appMetrics),
        idleApps: sizeOf(recommendations filter ((r) -> r.action == "UNDEPLOY")),
        underutilizedApps: sizeOf(recommendations filter ((r) -> r.action == "DOWNSIZE")),
        currentMonthlyCost: totalCurrentCost,
        optimizedMonthlyCost: totalOptimalCost,
        monthlySavings: totalCurrentCost - totalOptimalCost,
        annualSavings: (totalCurrentCost - totalOptimalCost) * 12,
        savingsPercent: ((totalCurrentCost - totalOptimalCost) / totalCurrentCost * 100)
            as String {format: "#.1"} ++ "%"
    }
}
```

### Alert Configuration

```yaml
# idle-worker-alerts.yaml

alerts:
  idle_worker:
    criteria:
      avg_cpu_7d: "< 5%"
      max_cpu_7d: "< 15%"
      avg_memory_7d: "< 30%"
    severity: warning
    action: "Review and undeploy if no longer needed"
    notification:
      - slack: "#platform-costs"
      - email: "platform-admin@company.com"

  underutilized_worker:
    criteria:
      avg_cpu_14d: "< 15%"
      max_cpu_14d: "< 40%"
    severity: info
    action: "Review for downsizing"
    notification:
      - slack: "#platform-costs"

  zero_traffic:
    criteria:
      request_count_7d: 0
      status: "STARTED"
    severity: critical
    action: "Immediate review — app is running but receiving zero traffic"
    notification:
      - slack: "#platform-costs"
      - pagerduty: "platform-team"

  cost_anomaly:
    criteria:
      monthly_cost_increase: "> 20% vs previous month"
    severity: warning
    action: "Investigate unexpected cost increase"
```

### Scheduled Report Template

```
═══════════════════════════════════════════════
  WEEKLY IDLE WORKER REPORT — 2026-02-24
═══════════════════════════════════════════════

IDLE WORKERS (Undeploy Candidates):
  1. test-api-leftover      0.5 vCore  $75/mo   0% CPU, 0 requests
  2. legacy-batch-sync      2.0 vCore  $300/mo  1% CPU, no batch runs

UNDERUTILIZED WORKERS (Downsize Candidates):
  1. customer-api-prod      1.0×2 → 0.1×1  Saves $285/mo
  2. notification-service   0.2×1 → 0.1×1  Saves $15/mo
  3. reporting-api          0.5×1 → 0.2×1  Saves $45/mo

SUMMARY:
  Current monthly spend:    $1,320
  Optimized monthly spend:  $630
  Potential savings:        $690/mo ($8,280/year)
  Savings percentage:       52.3%

═══════════════════════════════════════════════
```

## How It Works

1. **Deploy the detection flow** on a 0.1 vCore worker. It runs daily, querying the Anypoint Monitoring API for 7-day rolling metrics on every deployed app.
2. **Each app is classified** as IDLE (near-zero usage), UNDERUTILIZED (can be downsized), or ACTIVE (correctly sized).
3. **The rightsizing engine** recommends the optimal vCore tier based on actual peak CPU and average memory usage patterns.
4. **Alerts fire** when idle or underutilized workers are detected, notifying the platform team via Slack and email.
5. **Weekly reports** summarize all findings with specific dollar savings per recommendation.
6. **The platform team reviews and acts** — undeploying idle apps and downsizing underutilized workers.

## Key Takeaways

- Expect 15-30% of production vCores to be allocated to idle or severely underutilized workers in any deployment over 12 months old.
- Zero-traffic apps that are still running are the easiest wins — they should be undeployed immediately.
- Use 7-day rolling metrics (not point-in-time snapshots) to avoid false positives from weekend low traffic.
- The detection app itself costs $150/month on a 0.1 vCore worker but typically saves 10-50x that amount.
- Run detection against sandbox/dev environments too — they often have more waste than production.

## Related Recipes

- [cost-monitoring-dashboard](../cost-monitoring-dashboard/) — Idle detection feeds into the cost dashboard
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Use recommendations to right-size
- [dev-sandbox-cost-reduction](../dev-sandbox-cost-reduction/) — Apply idle detection to non-prod environments
- [cost-chargeback-framework](../cost-chargeback-framework/) — Charge idle worker costs back to owning teams
