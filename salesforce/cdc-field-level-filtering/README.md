# CDC Field-Level Change Filtering

## Problem

Salesforce Change Data Capture fires an event for every record change, regardless of which fields were modified. In a typical Salesforce org, automated processes like workflow field updates, formula recalculations, and system timestamp updates trigger CDC events constantly. A MuleSoft subscriber that processes every CDC event wastes significant compute on irrelevant changes --- for example, processing an Account CDC event because `LastModifiedDate` changed when only `Status__c` matters. In high-volume orgs, 80-90% of CDC events may be irrelevant to the integration, creating unnecessary load.

## Solution

Use DataWeave to inspect the `changedFields` bitmap in the CDC event header, filter events based on specific field changes, and skip processing when only irrelevant fields were modified. This reduces downstream processing volume by an order of magnitude without missing any meaningful business changes.

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

    <!-- Fields of interest configuration -->
    <global-property name="cdc.watchedFields.Account"
                     value="Status__c,Industry,BillingCity,BillingState,OwnerId"/>
    <global-property name="cdc.watchedFields.Contact"
                     value="Email,Phone,MailingCity,OwnerId"/>

    <!-- CDC Subscriber with Field-Level Filtering -->
    <flow name="cdc-filtered-subscriber">
        <salesforce:subscribe-channel config-ref="Salesforce_PubSub_Config"
                                      channelName="/data/AccountChangeEvent"
                                      replayPreset="LATEST"/>

        <!-- Step 1: Extract change header and determine relevance -->
        <ee:transform doc:name="Analyze Changed Fields">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

// CDC ChangeEventHeader contains the list of changed fields
var header = payload.ChangeEventHeader
var changeType = header.changeType  // CREATE, UPDATE, DELETE, UNDELETE
var changedFields = header.changedFields default []
var entityName = header.entityName  // e.g., "Account"

// Get the configured watched fields for this entity
var watchedFieldsStr = Mule::p('cdc.watchedFields.' ++ entityName) default ""
var watchedFields = if (isEmpty(watchedFieldsStr)) []
                    else watchedFieldsStr splitBy ","

// For CREATE and DELETE, always process (all fields are relevant)
// For UPDATE, check if any watched field was changed
var isRelevant = changeType match {
    case "CREATE"   -> true
    case "DELETE"   -> true
    case "UNDELETE" -> true
    case "UPDATE"   -> if (isEmpty(watchedFields)) true
                       else sizeOf(changedFields filter (f) ->
                           watchedFields contains f) > 0
    else -> false
}

// Identify which watched fields actually changed
var relevantChangedFields = changedFields filter (f) ->
    watchedFields contains f
---
{
    isRelevant: isRelevant,
    changeType: changeType,
    entityName: entityName,
    recordIds: header.recordIds,
    allChangedFields: changedFields,
    relevantChangedFields: relevantChangedFields,
    watchedFields: watchedFields,
    // Include the actual new values for changed fields
    changedValues: relevantChangedFields reduce ((field, acc = {}) ->
        acc ++ {(field): payload[field]}
    ),
    // Pass through the full payload for processing
    fullPayload: payload
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="cdcAnalysis" value="#[payload]"/>

        <!-- Step 2: Gate - only continue if event is relevant -->
        <choice doc:name="Relevance Gate">
            <when expression="#[payload.isRelevant == true]">
                <logger level="INFO"
                        message='Relevant CDC event: #[payload.changeType] on #[payload.entityName] #[payload.recordIds]. Changed fields: #[payload.relevantChangedFields]'/>

                <!-- Step 3: Route by change type -->
                <choice doc:name="Route by Change Type">
                    <when expression="#[payload.changeType == 'CREATE']">
                        <flow-ref name="handle-account-created"/>
                    </when>
                    <when expression="#[payload.changeType == 'UPDATE']">
                        <!-- Further route by which specific field changed -->
                        <flow-ref name="handle-account-field-update"/>
                    </when>
                    <when expression="#[payload.changeType == 'DELETE']">
                        <flow-ref name="handle-account-deleted"/>
                    </when>
                </choice>
            </when>
            <otherwise>
                <logger level="DEBUG"
                        message='Skipping irrelevant CDC event: #[payload.changeType] on #[payload.entityName] #[payload.recordIds]. Changed: #[payload.allChangedFields] (none in watch list)'/>
            </otherwise>
        </choice>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                        message='CDC processing error: #[error.description]'/>
            </on-error-continue>
        </error-handler>
    </flow>

    <!-- Field-specific update routing -->
    <sub-flow name="handle-account-field-update">
        <set-payload value="#[vars.cdcAnalysis]"/>

        <!-- Route to specific handlers based on which fields changed -->
        <choice>
            <!-- Status change: trigger downstream status sync -->
            <when expression="#[payload.relevantChangedFields contains 'Status__c']">
                <logger level="INFO"
                        message='Account status changed to: #[payload.changedValues.Status__c]'/>
                <ee:transform doc:name="Build Status Change Event">
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    eventType: "ACCOUNT_STATUS_CHANGE",
    accountId: vars.cdcAnalysis.recordIds[0],
    newStatus: vars.cdcAnalysis.changedValues.Status__c,
    changedBy: vars.cdcAnalysis.fullPayload.ChangeEventHeader.commitUser,
    changedAt: vars.cdcAnalysis.fullPayload.ChangeEventHeader.commitTimestamp
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
                <flow-ref name="sync-status-to-erp"/>
            </when>

            <!-- Address change: trigger geocoding update -->
            <when expression="#[payload.relevantChangedFields contains 'BillingCity'
                              or payload.relevantChangedFields contains 'BillingState']">
                <logger level="INFO"
                        message='Account address changed. Triggering geocoding update.'/>
                <flow-ref name="update-address-in-external-system"/>
            </when>

            <!-- Owner change: trigger assignment notification -->
            <when expression="#[payload.relevantChangedFields contains 'OwnerId']">
                <logger level="INFO"
                        message='Account owner changed. Triggering assignment sync.'/>
                <flow-ref name="sync-owner-assignment"/>
            </when>
        </choice>
    </sub-flow>

    <!-- Monitoring: Track filter effectiveness -->
    <sub-flow name="track-filter-metrics">
        <os:retrieve key="cdc-filter-metrics"
                     objectStore="metricsStore"
                     target="metrics">
            <os:default-value>#[{total: 0, relevant: 0, filtered: 0}]</os:default-value>
        </os:retrieve>

        <ee:transform doc:name="Update Filter Metrics">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var m = vars.metrics
var newTotal = m.total + 1
var newRelevant = m.relevant + (if (vars.cdcAnalysis.isRelevant) 1 else 0)
var newFiltered = m.filtered + (if (vars.cdcAnalysis.isRelevant) 0 else 1)
---
{
    total: newTotal,
    relevant: newRelevant,
    filtered: newFiltered,
    filterRate: if (newTotal > 0)
        ((newFiltered / newTotal) * 100) as String {format: "#.#"} ++ "%"
        else "0%",
    since: m.since default now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <os:store key="cdc-filter-metrics" objectStore="metricsStore">
            <os:value>#[payload]</os:value>
        </os:store>
    </sub-flow>
</mule>
```

**Performance Impact Analysis**

| Scenario | Without Filtering | With Filtering | Reduction |
|---|---|---|---|
| 10,000 CDC events/hour, 5 watched fields out of 50 | 10,000 processed | ~1,500 processed | 85% |
| Nightly batch update (system fields only) | All events processed | 0 events processed | 100% |
| Owner reassignment + status change | 2 events processed per record | 2 events processed per record | 0% (both relevant) |
| Formula field recalculation | All events processed | 0 events processed | 100% |

## How It Works

1. **Change header inspection**: Every CDC event includes a `ChangeEventHeader` with a `changedFields` array listing which fields were modified. DataWeave extracts this list.
2. **Watch list comparison**: The list of changed fields is compared against a configurable set of "watched fields" defined per entity. Only events where at least one watched field changed are considered relevant.
3. **Change type awareness**: CREATE, DELETE, and UNDELETE events are always relevant regardless of fields, since they represent record-level lifecycle changes. Only UPDATE events are filtered.
4. **Field-specific routing**: When an event passes the relevance gate, it is further routed to specialized handlers based on which specific watched field changed. This enables targeted processing (e.g., status changes go to ERP sync, address changes go to geocoding).
5. **Metrics tracking**: A filter metrics sub-flow tracks total events, relevant events, and filtered events, providing visibility into the filter's effectiveness.

## Key Takeaways

- In a typical Salesforce org, 70-90% of CDC events are irrelevant to external integrations (caused by system field updates, formula recalculations, and workflow field updates). Filtering saves enormous compute.
- Always process CREATE and DELETE events regardless of field filtering. These represent record lifecycle changes that downstream systems need to know about.
- Make the watched fields list configurable via properties so it can be updated without redeploying the application.
- Track your filter rate as a metric. If it drops below 50%, your watched field list may be too broad.
- The `changedFields` array in CDC events is already available in the event payload --- no additional API call is needed to inspect it.

## Related Recipes

- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [CDC Replay Storm Prevention](../cdc-replay-storm-prevention/)
- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
- [SF Sync Loop Prevention](../sf-sync-loop-prevention/)
