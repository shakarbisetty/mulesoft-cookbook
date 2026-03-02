# Real-Time Salesforce API Quota Monitoring

## Problem

Salesforce enforces rolling 24-hour API call limits that vary by edition and license count. When an integration exhausts its API quota, every subsequent call fails with `REQUEST_LIMIT_EXCEEDED`, causing cascading failures across all connected systems. Most teams only discover they have hit the limit after production breaks, because they never inspect the `/limits` endpoint proactively.

## Solution

Build a quota-aware integration layer in MuleSoft that checks remaining API calls before every batch operation, enforces tiered thresholds (80% / 90% / 95%), and automatically switches from REST to Bulk API when quota runs low. A circuit-breaker pattern prevents the integration from making any calls once the critical threshold is crossed.

## Implementation

**Quota Monitor Flow**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:doc="http://www.mulesoft.org/schema/mule/documentation"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Global properties for threshold configuration -->
    <global-property name="quota.threshold.warning" value="0.80"/>
    <global-property name="quota.threshold.high" value="0.90"/>
    <global-property name="quota.threshold.critical" value="0.95"/>

    <!-- Object Store for circuit breaker state -->
    <os:object-store name="quotaStateStore"
                     persistent="true"
                     entryTtl="1"
                     entryTtlUnit="HOURS"/>

    <!-- Sub-flow: Check Salesforce API Limits -->
    <sub-flow name="check-sf-api-limits">
        <http:request method="GET"
                      config-ref="Salesforce_REST_Config"
                      path="/services/data/v59.0/limits">
            <http:headers>
                #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
            </http:headers>
        </http:request>

        <!-- Parse the /limits response and calculate usage -->
        <ee:transform doc:name="Parse Quota Status">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var limits = payload.DailyApiRequests
var used = limits.Max - limits.Remaining
var usageRatio = if (limits.Max > 0) used / limits.Max else 1

var thresholdWarning = Mule::p('quota.threshold.warning') as Number
var thresholdHigh = Mule::p('quota.threshold.high') as Number
var thresholdCritical = Mule::p('quota.threshold.critical') as Number

var level = if (usageRatio >= thresholdCritical) "CRITICAL"
            else if (usageRatio >= thresholdHigh) "HIGH"
            else if (usageRatio >= thresholdWarning) "WARNING"
            else "NORMAL"
---
{
    dailyApiRequests: {
        max: limits.Max,
        remaining: limits.Remaining,
        used: used,
        usagePercent: (usageRatio * 100) as String {format: "#.##"} ++ "%",
        usageRatio: usageRatio
    },
    dailyBulkV2QueryJobs: {
        max: payload.DailyBulkV2QueryJobs.Max,
        remaining: payload.DailyBulkV2QueryJobs.Remaining
    },
    dailyBulkV2QueryFileStorageMB: {
        max: payload.DailyBulkV2QueryFileStorageMB.Max,
        remaining: payload.DailyBulkV2QueryFileStorageMB.Remaining
    },
    thresholdLevel: level,
    recommendedStrategy: level match {
        case "CRITICAL" -> "HALT_ALL_CALLS"
        case "HIGH"     -> "BULK_API_ONLY"
        case "WARNING"  -> "BATCH_AND_THROTTLE"
        else            -> "NORMAL_OPERATION"
    },
    checkedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Store current quota state for circuit breaker -->
        <os:store key="currentQuotaLevel"
                  objectStore="quotaStateStore">
            <os:value>#[payload.thresholdLevel]</os:value>
        </os:store>
    </sub-flow>

    <!-- Main flow: Quota-Aware Operation Router -->
    <flow name="quota-aware-sf-operation">
        <!-- Check circuit breaker state before any SF call -->
        <os:retrieve key="currentQuotaLevel"
                     objectStore="quotaStateStore"
                     target="quotaLevel">
            <os:default-value>NORMAL</os:default-value>
        </os:retrieve>

        <choice doc:name="Route by Quota Level">
            <!-- CRITICAL: Block all REST calls -->
            <when expression="#[vars.quotaLevel == 'CRITICAL']">
                <logger level="ERROR"
                        message="API quota CRITICAL. Blocking operation."/>
                <raise-error type="APP:QUOTA_EXCEEDED"
                             description="Salesforce API quota at critical level. All REST calls halted."/>
            </when>

            <!-- HIGH: Force Bulk API path -->
            <when expression="#[vars.quotaLevel == 'HIGH']">
                <logger level="WARN"
                        message="API quota HIGH. Routing to Bulk API path."/>
                <flow-ref name="execute-via-bulk-api"/>
            </when>

            <!-- WARNING: Throttle and batch -->
            <when expression="#[vars.quotaLevel == 'WARNING']">
                <logger level="WARN"
                        message="API quota WARNING. Throttling requests."/>
                <!-- Reduce batch frequency, increase batch size -->
                <set-variable variableName="batchSize" value="#[2000]"/>
                <flow-ref name="execute-via-rest-batched"/>
            </when>

            <!-- NORMAL: Standard REST operation -->
            <otherwise>
                <set-variable variableName="batchSize" value="#[200]"/>
                <flow-ref name="execute-via-rest-batched"/>
            </otherwise>
        </choice>
    </flow>

    <!-- Scheduled quota check every 15 minutes -->
    <flow name="quota-monitor-scheduler">
        <scheduler>
            <scheduling-strategy>
                <fixed-frequency frequency="15" timeUnit="MINUTES"/>
            </scheduling-strategy>
        </scheduler>

        <flow-ref name="check-sf-api-limits"/>

        <choice>
            <when expression="#[payload.thresholdLevel != 'NORMAL']">
                <logger level="WARN"
                        message='Quota alert: #[payload.thresholdLevel] - #[payload.dailyApiRequests.usagePercent] used (#[payload.dailyApiRequests.remaining] remaining)'/>
                <!-- Send alert notification -->
                <http:request method="POST"
                              config-ref="Alerts_HTTP_Config"
                              path="/api/alerts">
                    <http:body>#[output application/json --- {
                        severity: payload.thresholdLevel,
                        message: "SF API quota at " ++ payload.dailyApiRequests.usagePercent,
                        remaining: payload.dailyApiRequests.remaining,
                        recommendation: payload.recommendedStrategy
                    }]</http:body>
                </http:request>
            </when>
        </choice>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                        message="Quota check failed: #[error.description]"/>
            </on-error-continue>
        </error-handler>
    </flow>
</mule>
```

## How It Works

1. **Scheduled monitoring**: A flow runs every 15 minutes, calling the Salesforce `/limits` REST endpoint to retrieve current API usage statistics.
2. **Threshold evaluation**: DataWeave calculates the usage ratio and classifies it into four levels: NORMAL (under 80%), WARNING (80-89%), HIGH (90-94%), and CRITICAL (95%+).
3. **State persistence**: The current threshold level is stored in a persistent Object Store so that all flows in the application can check it without making an additional API call.
4. **Routing decisions**: Before any Salesforce operation, the integration checks the stored quota level and routes accordingly --- normal REST calls, batched/throttled REST, forced Bulk API, or full halt.
5. **Alerting**: When the threshold crosses WARNING or above, an alert is sent to the operations team with the current usage percentage and recommended action.

## Key Takeaways

- The `/limits` endpoint itself costs one API call, so polling every 15 minutes adds only 96 calls per day.
- Always check `DailyBulkV2QueryJobs` alongside `DailyApiRequests` --- Bulk API has its own separate limits.
- Store circuit-breaker state in a persistent Object Store with a TTL so it auto-resets if the monitor flow fails.
- The Bulk API path uses far fewer API calls (1 per job vs 1 per 200 records), making it the right fallback when quota is tight.
- In multi-worker deployments, use a shared Object Store (e.g., backed by Redis) so all workers see the same quota state.

## Related Recipes

- [Bulk API 2.0 Partial Failure Recovery](../bulk-api-2-partial-failure/)
- [Bulk API v2 Job Orchestrator](../bulk-api-v2-job-orchestrator/)
- [Bulk API v2 Chunk Calculator](../bulk-api-v2-chunk-calculator/)
- [Governor Limit Safe Batch Processing](../governor-limit-safe-batch/)
