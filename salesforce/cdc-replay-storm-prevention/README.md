# CDC Replay Storm Prevention

## Problem

When a MuleSoft application that subscribes to Salesforce Change Data Capture (CDC) events restarts after an outage, it resumes from its last stored replay ID. If the application was down for hours or days, Salesforce delivers every accumulated CDC event at once --- a "replay storm" that can contain tens of thousands of events. This flood overwhelms the MuleSoft worker, saturates downstream systems, and often triggers governor limits or memory exhaustion. Worse, if the stored replay ID has expired (beyond the 72-hour retention window), the subscription fails entirely with an unknown replay ID error.

## Solution

Implement replay ID persistence with staleness detection, a maximum replay window that rejects replay IDs older than a configurable threshold, and graceful degradation to polling-based sync when the replay gap is too large. Include startup validation that checks the replay ID age before subscribing.

## Implementation

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Configuration -->
    <global-property name="cdc.maxReplayGapHours" value="4"/>
    <global-property name="cdc.stormThreshold" value="5000"/>
    <global-property name="cdc.batchProcessingSize" value="200"/>

    <!-- Persistent replay ID storage -->
    <os:object-store name="replayIdStore"
                     persistent="true"
                     entryTtl="96"
                     entryTtlUnit="HOURS"/>

    <!-- Startup validation flow: runs once on application start -->
    <flow name="cdc-startup-validator" initialState="started">
        <scheduler>
            <scheduling-strategy>
                <!-- Run once at startup, then stop -->
                <fixed-frequency frequency="999999" timeUnit="HOURS"
                                 startDelay="5" startDelayUnit="SECONDS"/>
            </scheduling-strategy>
        </scheduler>

        <!-- Retrieve stored replay state -->
        <os:retrieve key="cdc-replay-state"
                     objectStore="replayIdStore"
                     target="replayState">
            <os:default-value><![CDATA[
                #[{replayId: null, storedAt: null, object: "Account"}]
            ]]></os:default-value>
        </os:retrieve>

        <ee:transform doc:name="Evaluate Replay ID Staleness">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var state = vars.replayState
var maxGapHours = Mule::p('cdc.maxReplayGapHours') as Number
var storedAt = if (state.storedAt != null)
    state.storedAt as DateTime
    else null
var gapHours = if (storedAt != null)
    ((now() - storedAt) as Number {unit: "hours"})
    else 999
var isStale = gapHours > maxGapHours
var isExpired = gapHours > 72  // SF retention limit
---
{
    replayId: state.replayId,
    storedAt: state.storedAt,
    gapHours: gapHours as String {format: "#.##"},
    isStale: isStale,
    isExpired: isExpired,
    decision: if (state.replayId == null) "SUBSCRIBE_LATEST"
              else if (isExpired) "FULL_SYNC_THEN_SUBSCRIBE"
              else if (isStale) "POLLING_CATCHUP_THEN_SUBSCRIBE"
              else "RESUME_FROM_REPLAY_ID",
    maxGapHours: maxGapHours
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="startupDecision" value="#[payload]"/>

        <logger level="INFO"
                message='CDC startup decision: #[payload.decision] (gap: #[payload.gapHours]h, stale: #[payload.isStale], expired: #[payload.isExpired])'/>

        <!-- Route based on staleness decision -->
        <choice doc:name="Startup Strategy Router">
            <!-- Case 1: Normal resume from stored replay ID -->
            <when expression="#[payload.decision == 'RESUME_FROM_REPLAY_ID']">
                <logger level="INFO"
                        message='Resuming CDC from replay ID: #[payload.replayId] (gap: #[payload.gapHours]h)'/>
                <flow-ref name="start-cdc-subscriber-with-replay"/>
            </when>

            <!-- Case 2: Stale but within retention - use polling to catch up -->
            <when expression="#[payload.decision == 'POLLING_CATCHUP_THEN_SUBSCRIBE']">
                <logger level="WARN"
                        message='Replay ID is stale (#[payload.gapHours]h gap). Starting polling catchup.'/>
                <flow-ref name="polling-catchup-sync"/>
                <!-- After polling fills the gap, subscribe to LATEST -->
                <flow-ref name="start-cdc-subscriber-latest"/>
            </when>

            <!-- Case 3: Expired replay ID - full sync needed -->
            <when expression="#[payload.decision == 'FULL_SYNC_THEN_SUBSCRIBE']">
                <logger level="ERROR"
                        message='Replay ID expired (#[payload.gapHours]h gap). Initiating full delta sync.'/>
                <flow-ref name="full-delta-sync"/>
                <flow-ref name="start-cdc-subscriber-latest"/>
            </when>

            <!-- Case 4: First time - subscribe to LATEST -->
            <otherwise>
                <logger level="INFO" message="No stored replay ID. Subscribing to LATEST."/>
                <flow-ref name="start-cdc-subscriber-latest"/>
            </otherwise>
        </choice>
    </flow>

    <!-- CDC subscriber with stored replay ID -->
    <flow name="cdc-subscriber-with-replay" initialState="stopped">
        <salesforce:subscribe-channel config-ref="Salesforce_PubSub_Config"
                                      channelName="/data/AccountChangeEvent"
                                      replayPreset="CUSTOM">
            <salesforce:replay-id>#[vars.storedReplayId]</salesforce:replay-id>
        </salesforce:subscribe-channel>

        <flow-ref name="process-cdc-with-storm-protection"/>
    </flow>

    <!-- CDC subscriber from LATEST (no replay) -->
    <flow name="cdc-subscriber-latest" initialState="stopped">
        <salesforce:subscribe-channel config-ref="Salesforce_PubSub_Config"
                                      channelName="/data/AccountChangeEvent"
                                      replayPreset="LATEST"/>

        <flow-ref name="process-cdc-with-storm-protection"/>
    </flow>

    <!-- Storm protection: throttle if too many events arrive at once -->
    <sub-flow name="process-cdc-with-storm-protection">
        <!-- Track events-per-minute rate -->
        <os:retrieve key="cdc-event-counter"
                     objectStore="replayIdStore"
                     target="eventCounter">
            <os:default-value>#[{count: 0, windowStart: now() as String}]</os:default-value>
        </os:retrieve>

        <ee:transform doc:name="Check Storm Condition">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var counter = vars.eventCounter
var windowStart = counter.windowStart as DateTime
var windowElapsed = (now() - windowStart) as Number {unit: "minutes"}
var currentCount = if (windowElapsed > 1) 1
                   else (counter.count as Number) + 1
var isStorm = currentCount > (Mule::p('cdc.stormThreshold') as Number)
---
{
    eventCount: currentCount,
    windowMinute: if (windowElapsed > 1) now() as String else counter.windowStart,
    isStorm: isStorm,
    rate: currentCount
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <os:store key="cdc-event-counter" objectStore="replayIdStore">
            <os:value>#[{count: payload.eventCount, windowStart: payload.windowMinute}]</os:value>
        </os:store>

        <choice>
            <when expression="#[payload.isStorm]">
                <logger level="WARN"
                        message='Storm detected: #[payload.rate] events/min. Throttling processing.'/>
                <!-- Add small delay to prevent overwhelming downstream -->
                <set-variable variableName="throttleDelay" value="#[100]"/>
            </when>
        </choice>

        <!-- Process the CDC event -->
        <flow-ref name="process-account-cdc-event"/>

        <!-- Persist replay ID after successful processing -->
        <os:store key="cdc-replay-state" objectStore="replayIdStore">
            <os:value>#[{
                replayId: attributes.replayId,
                storedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
                object: "Account"
            }]</os:value>
        </os:store>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                        message='CDC event processing failed: #[error.description]. Event NOT acknowledged.'/>
            </on-error-continue>
        </error-handler>
    </sub-flow>

    <!-- Polling-based catchup for stale replay IDs -->
    <sub-flow name="polling-catchup-sync">
        <logger level="INFO" message="Starting polling catchup sync..."/>

        <!-- Query records modified since the last known replay timestamp -->
        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>
                SELECT Id, Name, Industry, LastModifiedDate
                FROM Account
                WHERE LastModifiedDate > :lastSyncTime
                ORDER BY LastModifiedDate ASC
            </salesforce:salesforce-query>
            <salesforce:parameters>
                #[{'lastSyncTime': vars.replayState.storedAt}]
            </salesforce:parameters>
        </salesforce:query>

        <logger level="INFO"
                message='Polling catchup: #[sizeOf(payload)] records to sync'/>

        <!-- Process in batches to avoid memory issues -->
        <foreach batchSize="#[Mule::p('cdc.batchProcessingSize') as Number]">
            <flow-ref name="process-catchup-batch"/>
        </foreach>

        <logger level="INFO" message="Polling catchup complete. Switching to CDC subscriber."/>
    </sub-flow>
</mule>
```

## How It Works

1. **Startup validation**: When the application starts, it retrieves the stored replay state and calculates how long the application was offline. This determines the recovery strategy.
2. **Staleness classification**: The replay ID gap is classified into four categories: normal (under 4 hours), stale (4-72 hours), expired (over 72 hours), or first-time (no stored replay ID).
3. **Graceful degradation**: Stale replay IDs trigger a SOQL-based polling catchup that queries records modified during the downtime. Once caught up, the subscriber starts from LATEST. Expired replay IDs trigger a full delta sync.
4. **Storm detection**: An events-per-minute counter tracks the incoming event rate. If it exceeds the configurable threshold (5,000 events/min), the flow adds throttle delays to protect downstream systems.
5. **Replay ID persistence**: After every successfully processed event, the replay ID and timestamp are stored in a persistent Object Store. This ensures the replay position survives application restarts.

## Key Takeaways

- Always store replay IDs with a timestamp. The replay ID alone is not enough to determine whether it is safe to resume; you need to know when it was last updated.
- Set `maxReplayGapHours` based on your downstream system's tolerance. If your downstream can handle 4 hours of backfill events, set it to 4. If only 1 hour, set it to 1.
- Polling catchup uses SOQL queries (which do not count against streaming event quotas) to fill the gap before subscribing, avoiding the replay storm entirely.
- The 72-hour retention window is an absolute limit. If your application might be down for more than 72 hours (weekend deployments, DR scenarios), build a full delta sync capability.
- Monitor the events-per-minute rate as an operational metric. A sustained rate above your processing capacity means you need to scale horizontally.

## Related Recipes

- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [CDC Field-Level Filtering](../cdc-field-level-filtering/)
- [Platform Events DLQ Pattern](../platform-events-dlq-pattern/)
- [Streaming API Integration](../salesforce-streaming-api/)
