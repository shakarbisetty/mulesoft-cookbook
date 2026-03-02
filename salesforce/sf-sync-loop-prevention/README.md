# Preventing Sync Loops in Bidirectional Salesforce Integration

## Problem

In bidirectional integrations between Salesforce and external systems, a sync loop occurs when MuleSoft updates a Salesforce record, which triggers a CDC event, which MuleSoft processes and updates the external system, which triggers a webhook back to MuleSoft, which updates Salesforce again --- and the loop repeats indefinitely. This causes exponential API consumption, data overwrites, performance degradation, and in severe cases, hitting Salesforce governor limits within minutes. The loop is especially insidious because each leg of the loop looks correct in isolation.

## Solution

Implement multiple complementary loop prevention strategies: integration user filtering (ignore changes made by the integration user), external ID marker fields (mark records currently being synced), timestamp-based deduplication (skip processing if the record was just updated), and the "sync flag" pattern that uses a custom field to signal that a change originated from the integration. DataWeave handles all detection logic.

## Implementation

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Integration user ID (the SF user that MuleSoft authenticates as) -->
    <global-property name="sf.integrationUserId" value="${sf.integration.user.id}"/>
    <!-- Dedup window: ignore changes within this many seconds of last sync -->
    <global-property name="sync.dedupWindowSeconds" value="10"/>

    <!-- Sync state tracking -->
    <os:object-store name="syncStateStore"
                     persistent="true"
                     entryTtl="1"
                     entryTtlUnit="HOURS"/>

    <!-- ============================================ -->
    <!-- STRATEGY 1: Integration User Filtering       -->
    <!-- ============================================ -->
    <sub-flow name="strategy-1-user-filter">
        <ee:transform doc:name="Check Change Author">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var header = payload.ChangeEventHeader
var commitUser = header.commitUser
var integrationUserId = Mule::p('sf.integrationUserId')

// If the change was made by our integration user, it originated
// from MuleSoft and should NOT be processed again
var isSelfOriginated = commitUser == integrationUserId
---
{
    recordId: header.recordIds[0],
    commitUser: commitUser,
    integrationUserId: integrationUserId,
    isSelfOriginated: isSelfOriginated,
    verdict: if (isSelfOriginated) "SKIP_SELF_ORIGINATED" else "PROCESS"
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </sub-flow>

    <!-- ============================================ -->
    <!-- STRATEGY 2: Sync Flag Pattern                -->
    <!-- ============================================ -->

    <!-- When MuleSoft writes TO Salesforce, set the sync flag -->
    <sub-flow name="strategy-2-write-with-sync-flag">
        <ee:transform doc:name="Add Sync Flag to Payload">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload ++ {
    // Custom checkbox field: true = this update came from integration
    Integration_Sync__c: true,
    // Timestamp of when integration last touched this record
    Last_Integration_Sync__c: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"}
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <salesforce:update config-ref="Salesforce_Config"
                           type="Account">
            <salesforce:records>#[payload]</salesforce:records>
        </salesforce:update>
    </sub-flow>

    <!-- When reading CDC events, check the sync flag -->
    <sub-flow name="strategy-2-check-sync-flag">
        <ee:transform doc:name="Check Sync Flag">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

// If Integration_Sync__c is in the changed fields AND is true,
// this update was made by the integration and should be skipped
var changedFields = payload.ChangeEventHeader.changedFields default []
var syncFlagChanged = changedFields contains "Integration_Sync__c"
var syncFlagValue = payload.Integration_Sync__c default false
---
{
    recordId: payload.ChangeEventHeader.recordIds[0],
    syncFlagChanged: syncFlagChanged,
    syncFlagValue: syncFlagValue,
    isSyncOriginated: syncFlagChanged and syncFlagValue,
    verdict: if (syncFlagChanged and syncFlagValue)
        "SKIP_INTEGRATION_ORIGINATED" else "PROCESS"
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </sub-flow>

    <!-- ============================================ -->
    <!-- STRATEGY 3: Timestamp-Based Deduplication    -->
    <!-- ============================================ -->
    <sub-flow name="strategy-3-timestamp-dedup">
        <set-variable variableName="recordId"
                      value="#[payload.ChangeEventHeader.recordIds[0]]"/>

        <!-- Check when we last synced this record -->
        <os:retrieve key="#['last-sync-' ++ vars.recordId]"
                     objectStore="syncStateStore"
                     target="lastSyncTime">
            <os:default-value>#[null]</os:default-value>
        </os:retrieve>

        <ee:transform doc:name="Check Timestamp Window">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var lastSync = vars.lastSyncTime
var dedupWindow = Mule::p('sync.dedupWindowSeconds') as Number
var commitTime = payload.ChangeEventHeader.commitTimestamp as DateTime

var isWithinDedupWindow = if (lastSync != null)
    ((commitTime - (lastSync as DateTime)) as Number {unit: "seconds"}) < dedupWindow
    else false
---
{
    recordId: vars.recordId,
    commitTime: commitTime as String,
    lastSyncTime: lastSync,
    dedupWindowSeconds: dedupWindow,
    isWithinDedupWindow: isWithinDedupWindow,
    verdict: if (isWithinDedupWindow) "SKIP_WITHIN_DEDUP_WINDOW" else "PROCESS"
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </sub-flow>

    <!-- ============================================ -->
    <!-- COMBINED: Multi-Strategy Loop Prevention     -->
    <!-- ============================================ -->
    <flow name="loop-safe-cdc-subscriber">
        <salesforce:subscribe-channel config-ref="Salesforce_PubSub_Config"
                                      channelName="/data/AccountChangeEvent"
                                      replayPreset="LATEST"/>

        <set-variable variableName="originalPayload" value="#[payload]"/>

        <!-- Apply all three strategies in sequence -->

        <!-- Strategy 1: Integration user filter (cheapest check first) -->
        <flow-ref name="strategy-1-user-filter"/>
        <set-variable variableName="userFilterResult" value="#[payload]"/>

        <choice>
            <when expression="#[payload.isSelfOriginated]">
                <logger level="DEBUG"
                        message='Loop prevented (user filter): #[payload.recordId] changed by integration user'/>
            </when>
            <otherwise>
                <!-- Strategy 2: Sync flag check -->
                <set-payload value="#[vars.originalPayload]"/>
                <flow-ref name="strategy-2-check-sync-flag"/>
                <set-variable variableName="syncFlagResult" value="#[payload]"/>

                <choice>
                    <when expression="#[payload.isSyncOriginated]">
                        <logger level="DEBUG"
                                message='Loop prevented (sync flag): #[payload.recordId] has Integration_Sync__c = true'/>
                    </when>
                    <otherwise>
                        <!-- Strategy 3: Timestamp dedup -->
                        <set-payload value="#[vars.originalPayload]"/>
                        <flow-ref name="strategy-3-timestamp-dedup"/>

                        <choice>
                            <when expression="#[payload.isWithinDedupWindow]">
                                <logger level="DEBUG"
                                        message='Loop prevented (timestamp): #[payload.recordId] within dedup window'/>
                            </when>
                            <otherwise>
                                <!-- All checks passed: safe to process -->
                                <logger level="INFO"
                                        message='Processing CDC event for #[payload.recordId] (passed all loop checks)'/>

                                <set-payload value="#[vars.originalPayload]"/>
                                <flow-ref name="process-and-sync-to-external"/>

                                <!-- Record sync timestamp for dedup -->
                                <os:store key="#['last-sync-' ++ vars.recordId]"
                                          objectStore="syncStateStore">
                                    <os:value>#[now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}]</os:value>
                                </os:store>
                            </otherwise>
                        </choice>
                    </otherwise>
                </choice>
            </otherwise>
        </choice>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                        message='CDC processing error: #[error.description]'/>
            </on-error-continue>
        </error-handler>
    </flow>
</mule>
```

## How It Works

1. **Strategy 1 - User filter**: The cheapest check runs first. The CDC event header contains `commitUser`, which is the Salesforce user ID that made the change. If it matches the integration user, the event is skipped immediately.
2. **Strategy 2 - Sync flag**: A custom checkbox field `Integration_Sync__c` is set to `true` whenever MuleSoft writes to Salesforce. When a CDC event arrives, if this field is in the changed fields list and is `true`, the event originated from the integration.
3. **Strategy 3 - Timestamp dedup**: The last sync time for each record is stored in an Object Store. If a CDC event arrives within the configurable dedup window (default 10 seconds) of the last sync, it is skipped as a likely echo of the integration's own write.
4. **Layered defense**: All three strategies run in sequence, cheapest first. A change must pass all three checks before being processed. This multi-layer approach catches edge cases that any single strategy would miss.
5. **State recording**: After successful processing, the current timestamp is stored for the timestamp dedup strategy, completing the feedback loop.

## Key Takeaways

- Always use a dedicated integration user in Salesforce for MuleSoft connections. This makes user-based filtering possible and also simplifies audit trails.
- The sync flag pattern requires a custom field on the Salesforce object. Coordinate with your Salesforce admin to add `Integration_Sync__c` (checkbox) and `Last_Integration_Sync__c` (DateTime).
- Layer multiple strategies because each has blind spots: user filtering fails if multiple integrations share a user, sync flags fail if Apex code clears the flag, and timestamp dedup has a window where legitimate rapid changes might be dropped.
- Set the dedup window to slightly longer than the round-trip time of your integration (write to SF + CDC delivery + processing). Too short and loops slip through; too long and legitimate rapid changes are dropped.
- Monitor how many events are being filtered by each strategy. If user filtering catches 99% of loops, the other strategies serve as safety nets.

## Related Recipes

- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
- [CDC Field-Level Filtering](../cdc-field-level-filtering/)
- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [SF Flow vs MuleSoft Decision](../sf-flow-vs-mulesoft-decision/)
