# MuleSoft Cost Monitoring Dashboard

## Problem

MuleSoft costs are spread across multiple billing dimensions: vCore allocations per app, API call volumes against tier limits, Anypoint MQ message counts, Object Store usage, DLB and VPN fees. Without a unified cost view, organizations only discover overspend at contract renewal. By then, months of waste have accumulated. There is no built-in MuleSoft "cost dashboard" — you must build one from platform APIs and monitoring data.

## Solution

Build a cost monitoring dashboard that collects usage metrics from Anypoint Platform APIs, calculates dollar costs per dimension, generates alerts when spend thresholds are reached, and produces monthly cost reports. Uses Anypoint Monitoring for runtime metrics and the Anypoint Platform REST API for deployment and entitlement data.

## Implementation

### Architecture

```
┌──────────────────────┐     ┌──────────────────────┐
│ Anypoint Platform    │     │ Anypoint Monitoring   │
│ REST API             │     │ (Grafana/Titanium)    │
│  - /applications     │     │  - CPU metrics        │
│  - /environments     │     │  - Memory metrics     │
│  - /mqStats          │     │  - Request counts     │
│  - /objectStore      │     │  - Response times     │
└──────────┬───────────┘     └──────────┬───────────┘
           │                            │
           ▼                            ▼
┌──────────────────────────────────────────────────┐
│ Cost Aggregation App (Mule or Scheduled Script)  │
│  - Polls APIs daily/hourly                        │
│  - Maps usage → dollar costs                      │
│  - Stores in database/Object Store                │
│  - Sends alerts when thresholds breached          │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────┐
│ Dashboard (Anypoint Custom Dashboard / Grafana)  │
│  - Total monthly spend                            │
│  - Cost by application                            │
│  - Cost by environment                            │
│  - Trend charts (month-over-month)                │
│  - Alert history                                  │
└──────────────────────────────────────────────────┘
```

### Step 1: Collect vCore Usage per Application

```xml
<!-- Mule flow to collect deployment data from Anypoint Platform API -->
<flow name="collect-vcore-usage">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="1" timeUnit="HOURS"/>
        </scheduling-strategy>
    </scheduler>

    <!-- Authenticate with Anypoint Platform -->
    <http:request config-ref="anypointApiConfig"
                  method="POST"
                  path="/accounts/login">
        <http:body><![CDATA[{
            "username": "${anypoint.username}",
            "password": "${anypoint.password}"
        }]]></http:body>
    </http:request>

    <set-variable variableName="authToken"
                  value="#[payload.access_token]"/>

    <!-- Get all environments -->
    <http:request config-ref="anypointApiConfig"
                  method="GET"
                  path="/accounts/api/organizations/${anypoint.orgId}/environments">
        <http:headers>
            #[{'Authorization': 'Bearer ' ++ vars.authToken}]
        </http:headers>
    </http:request>

    <set-variable variableName="environments" value="#[payload.data]"/>

    <!-- For each environment, get deployed applications -->
    <foreach collection="#[vars.environments]">
        <http:request config-ref="anypointApiConfig"
                      method="GET"
                      path="/cloudhub/api/v2/applications">
            <http:headers>
                #[{
                    'Authorization': 'Bearer ' ++ vars.authToken,
                    'X-ANYPNT-ENV-ID': payload.id
                }]
            </http:headers>
        </http:request>

        <!-- Transform to cost records -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
var vcoreMonthlyCost = 150
---
payload map ((app) -> {
    appName: app.domain,
    environment: vars.currentEnv,
    vcoreSize: app.workers."type".weight default 0,
    workerCount: app.workers.amount default 0,
    totalVCores: (app.workers."type".weight default 0) * (app.workers.amount default 0),
    status: app.status,
    monthlyCost: (app.workers."type".weight default 0) *
                 (app.workers.amount default 0) *
                 vcoreMonthlyCost,
    lastUpdated: app.lastUpdateTime,
    collectedAt: now()
})]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Store in database or Object Store -->
        <db:insert config-ref="costDbConfig">
            <db:sql>
                INSERT INTO vcore_usage (app_name, environment, vcore_size,
                    worker_count, total_vcores, monthly_cost, collected_at)
                VALUES (:appName, :environment, :vcoreSize,
                    :workerCount, :totalVCores, :monthlyCost, :collectedAt)
            </db:sql>
            <db:input-parameters>#[payload]</db:input-parameters>
        </db:insert>
    </foreach>
</flow>
```

### Step 2: Collect API Call Volumes

```dataweave
%dw 2.0
output application/json

// API Analytics data from Anypoint Analytics API
// Endpoint: GET /analytics/1.0/{orgId}/dashboard

var apiCallData = payload  // Raw analytics response

var costPerApiCall = 0     // Usually included in tier, but track for overage
var tierLimit = 50         // API instances in current tier
---
{
    totalAPICalls: apiCallData.totalCalls,
    apiInstances: apiCallData.totalAPIs,
    tierUtilization: (apiCallData.totalAPIs / tierLimit * 100)
        as String {format: "#.1"} ++ "%",
    tierOverageRisk: if (apiCallData.totalAPIs > tierLimit * 0.8)
        "WARNING: At $(apiCallData.totalAPIs)/$(tierLimit) API instances. " ++
        "Tier upgrade needed at $(tierLimit)."
    else
        "OK: API instance count within tier limits.",
    topAPIsByVolume: (apiCallData.apis orderBy -$.callCount)[0 to 9]
        map ((api) -> {
            name: api.name,
            calls: api.callCount,
            avgResponseTime: api.avgResponseTimeMs
        })
}
```

### Step 3: Collect Anypoint MQ Usage

```dataweave
%dw 2.0
output application/json

var mqRegions = ["us-east-1", "eu-west-1"]
var mqCostPerMillion = 600  // Approximate

// Aggregate MQ stats across all queues
var mqUsage = payload  // From MQ Stats API

var totalMessages = mqUsage.queues reduce ((q, total = 0) ->
    total + q.messagesReceived + q.messagesSent
)

var monthlyMQCost = (totalMessages / 1000000) * mqCostPerMillion
---
{
    totalQueues: sizeOf(mqUsage.queues),
    totalMessagesThisMonth: totalMessages,
    estimatedMonthlyCost: monthlyMQCost,
    topQueuesByVolume: (mqUsage.queues orderBy -$.messagesReceived)[0 to 4]
        map ((q) -> {
            name: q.queueId,
            received: q.messagesReceived,
            sent: q.messagesSent,
            inflight: q.messagesInflight
        }),
    costAlert: if (monthlyMQCost > 500)
        "MQ spend exceeds $500/month. Review queue consolidation."
    else
        "MQ costs within normal range."
}
```

### Step 4: Monthly Cost Report Generator

```dataweave
%dw 2.0
output application/json

var month = "2026-02"
var vcoreData = vars.vcoreUsage       // From Step 1
var apiData = vars.apiCallVolumes     // From Step 2
var mqData = vars.mqUsage             // From Step 3

// Fixed infrastructure costs
var fixedCosts = {
    dlb: 2 * 400,        // 2 DLBs × $400/month
    vpn: 2 * 300,        // 2 VPNs × $300/month
    staticIPs: 4 * 100,  // 4 IPs × $100/month
    platformLicense: 200000 / 12  // Annual license / 12
}

var vcoreTotalMonthly = vcoreData reduce ((app, total = 0) -> total + app.monthlyCost)
var mqMonthly = mqData.estimatedMonthlyCost
var fixedTotal = fixedCosts pluck ((v) -> v) reduce ((item, t = 0) -> t + item)
---
{
    reportMonth: month,
    generatedAt: now(),
    summary: {
        totalMonthlySpend: vcoreTotalMonthly + mqMonthly + fixedTotal,
        vcoreCost: vcoreTotalMonthly,
        mqCost: mqMonthly,
        fixedInfrastructure: fixedTotal,
        platformLicenseAllocation: fixedCosts.platformLicense
    },
    byEnvironment: vcoreData groupBy ((app) -> app.environment)
        mapObject ((apps, env) -> (env): {
            appCount: sizeOf(apps),
            totalVCores: apps reduce ((a, t = 0) -> t + a.totalVCores),
            monthlyCost: apps reduce ((a, t = 0) -> t + a.monthlyCost)
        }),
    topCostApps: (vcoreData orderBy -$.monthlyCost)[0 to 4],
    alerts: [
        if (vcoreTotalMonthly > 5000)
            "vCore spend exceeds $5,000/month"
        else null,
        if (mqMonthly > 500)
            "MQ spend exceeds $500/month"
        else null
    ] filter ((a) -> a != null)
}
```

### Step 5: Alert Thresholds Configuration

```yaml
# cost-alerts.yaml

thresholds:
  vcore_monthly_total:
    warning: 4000
    critical: 6000
    unit: USD

  mq_monthly_messages:
    warning: 5000000
    critical: 10000000
    unit: messages

  api_instance_count:
    warning_pct: 80    # Percent of tier limit
    critical_pct: 95

  single_app_vcore:
    warning: 2.0       # Any single app using 2+ vCores
    critical: 4.0

  idle_app_threshold:
    cpu_below: 5        # Percent
    for_hours: 168      # 1 week
    action: "Flag for rightsizing review"

notification:
  channels:
    - email: "platform-team@company.com"
    - slack: "#mulesoft-costs"
  frequency: "daily for critical, weekly for warning"
```

## How It Works

1. **Deploy the cost collection app** on a 0.1 vCore worker (it runs hourly/daily, does not need much compute).
2. **Configure Anypoint Platform API credentials** with read-only access to organizations, environments, and applications.
3. **Set up the database** or Object Store to persist cost data over time for trend analysis.
4. **Build the dashboard** in Anypoint Monitoring Custom Dashboards (if Titanium) or export data to Grafana/Datadog.
5. **Configure alert thresholds** based on your budget and contract limits.
6. **Generate monthly reports** automatically and distribute to finance and engineering leads.

## Key Takeaways

- There is no built-in MuleSoft cost dashboard; you must build it from Platform APIs and Monitoring data.
- vCore cost per application is the largest variable cost and the easiest to optimize.
- API instance count approaching tier limits is the most expensive surprise (forces tier upgrade).
- Monthly cost reports should break down spend by environment (production vs sandbox waste is common).
- The cost monitoring app itself costs ~$150/month on a 0.1 vCore worker but saves thousands by catching waste early.

## Related Recipes

- [idle-worker-detection](../idle-worker-detection/) — Feeds into the cost dashboard as a data source
- [cost-chargeback-framework](../cost-chargeback-framework/) — Uses dashboard data for team-level billing
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Act on dashboard insights
- [dev-sandbox-cost-reduction](../dev-sandbox-cost-reduction/) — Reduce sandbox costs identified by dashboard
