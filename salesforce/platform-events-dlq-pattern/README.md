# Dead Letter Queue Pattern for Salesforce Platform Events

## Problem

Salesforce Platform Events are fire-and-forget: once a subscriber fails to process an event, that event is lost unless you build explicit recovery infrastructure. MuleSoft's default error handling either drops the event silently (on-error-continue) or retries indefinitely (on-error-propagate), neither of which is acceptable for production systems handling order events, payment notifications, or compliance-critical data. Without a Dead Letter Queue, failed events disappear into a black hole.

## Solution

Implement a Dead Letter Queue (DLQ) pattern that catches processing failures, stores the full event payload along with failure metadata (replay ID, error reason, attempt count, timestamp), and provides a separate reprocessing flow that can retry failed events with exponential backoff. Use a persistent Object Store as the DLQ backend and expose an API to inspect and replay failed events.

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

    <!-- DLQ Object Store: persists failed events -->
    <os:object-store name="dlqStore"
                     persistent="true"
                     entryTtl="72"
                     entryTtlUnit="HOURS"
                     maxEntries="10000"/>

    <!-- DLQ Index: tracks all DLQ entry keys for listing -->
    <os:object-store name="dlqIndexStore"
                     persistent="true"
                     entryTtl="72"
                     entryTtlUnit="HOURS"/>

    <!-- Platform Event Subscriber with DLQ Error Handling -->
    <flow name="platform-event-subscriber">
        <salesforce:subscribe-topic config-ref="Salesforce_Config"
                                    topic="/event/Order_Event__e"
                                    replayOption="LATEST"/>

        <set-variable variableName="replayId" value="#[attributes.replayId]"/>
        <set-variable variableName="eventUuid"
                      value="#[payload.Event_UUID__c default attributes.replayId as String]"/>

        <logger level="INFO"
                message='Processing event: replayId=#[vars.replayId], uuid=#[vars.eventUuid]'/>

        <try>
            <!-- Core business logic -->
            <flow-ref name="process-order-event"/>

            <logger level="INFO"
                    message='Event #[vars.eventUuid] processed successfully'/>

            <error-handler>
                <!-- Catch all processing errors and route to DLQ -->
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                            message='Event #[vars.eventUuid] failed: #[error.description]'/>

                    <!-- Build DLQ entry with full context -->
                    <ee:transform doc:name="Build DLQ Entry">
                        <ee:message>
                            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    dlqEntryId: uuid(),
    eventUuid: vars.eventUuid,
    replayId: vars.replayId,
    topic: "/event/Order_Event__e",
    eventPayload: write(vars.originalPayload, "application/json"),
    error: {
        errorType: error.errorType.identifier,
        description: error.description,
        detailedDescription: error.detailedDescription default "",
        stackTrace: error.cause.message default ""
    },
    metadata: {
        attemptCount: 1,
        firstFailedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
        lastFailedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
        status: "PENDING_RETRY",
        nextRetryAt: (now() + |PT5M|) as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    }
}
                            ]]></ee:set-payload>
                        </ee:message>
                    </ee:transform>

                    <!-- Store in DLQ -->
                    <os:store key="#[payload.dlqEntryId]"
                              objectStore="dlqStore">
                        <os:value>#[payload]</os:value>
                    </os:store>

                    <!-- Update DLQ index -->
                    <os:retrieve key="dlqIndex"
                                 objectStore="dlqIndexStore"
                                 target="currentIndex">
                        <os:default-value>#[[] as Array]</os:default-value>
                    </os:retrieve>

                    <os:store key="dlqIndex"
                              objectStore="dlqIndexStore">
                        <os:value>#[vars.currentIndex << payload.dlqEntryId]</os:value>
                    </os:store>

                    <logger level="WARN"
                            message='Event #[vars.eventUuid] stored in DLQ as #[payload.dlqEntryId]'/>
                </on-error-continue>
            </error-handler>
        </try>
    </flow>

    <!-- DLQ Reprocessor: scheduled retry with exponential backoff -->
    <flow name="dlq-reprocessor">
        <scheduler>
            <scheduling-strategy>
                <fixed-frequency frequency="5" timeUnit="MINUTES"/>
            </scheduling-strategy>
        </scheduler>

        <!-- Get all DLQ entries -->
        <os:retrieve key="dlqIndex"
                     objectStore="dlqIndexStore"
                     target="dlqKeys">
            <os:default-value>#[[] as Array]</os:default-value>
        </os:retrieve>

        <set-payload value="#[vars.dlqKeys]"/>

        <foreach>
            <os:retrieve key="#[payload]"
                         objectStore="dlqStore"
                         target="dlqEntry">
                <os:default-value>#[null]</os:default-value>
            </os:retrieve>

            <choice>
                <when expression="#[vars.dlqEntry != null and vars.dlqEntry.metadata.status == 'PENDING_RETRY']">
                    <!-- Check if it is time to retry (exponential backoff) -->
                    <choice>
                        <when expression="#[now() >= (vars.dlqEntry.metadata.nextRetryAt as DateTime)]">
                            <logger level="INFO"
                                    message='Retrying DLQ entry #[vars.dlqEntry.dlqEntryId] (attempt #[vars.dlqEntry.metadata.attemptCount + 1])'/>

                            <try>
                                <!-- Restore original payload and reprocess -->
                                <set-payload value="#[read(vars.dlqEntry.eventPayload, 'application/json')]"/>
                                <flow-ref name="process-order-event"/>

                                <!-- Success: remove from DLQ -->
                                <os:remove key="#[vars.dlqEntry.dlqEntryId]"
                                           objectStore="dlqStore"/>
                                <logger level="INFO"
                                        message='DLQ entry #[vars.dlqEntry.dlqEntryId] reprocessed successfully'/>

                                <error-handler>
                                    <on-error-continue type="ANY">
                                        <!-- Update attempt count and backoff -->
                                        <ee:transform doc:name="Update DLQ Entry">
                                            <ee:message>
                                                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var entry = vars.dlqEntry
var newAttempt = entry.metadata.attemptCount + 1
// Exponential backoff: 5m, 10m, 20m, 40m, 80m (cap at 2 hours)
var backoffMinutes = min([5 * (2 pow (newAttempt - 1)), 120])
var maxAttempts = 10
---
entry update {
    case .metadata.attemptCount -> newAttempt
    case .metadata.lastFailedAt -> now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    case .metadata.nextRetryAt -> (now() + ("PT$(backoffMinutes)M" as Period))
        as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
    case .metadata.status -> if (newAttempt >= maxAttempts)
        "PERMANENTLY_FAILED" else "PENDING_RETRY"
    case .error.description -> error.description
}
                                                ]]></ee:set-payload>
                                            </ee:message>
                                        </ee:transform>

                                        <os:store key="#[payload.dlqEntryId]"
                                                  objectStore="dlqStore">
                                            <os:value>#[payload]</os:value>
                                        </os:store>
                                    </on-error-continue>
                                </error-handler>
                            </try>
                        </when>
                    </choice>
                </when>
            </choice>
        </foreach>
    </flow>

    <!-- API: Inspect DLQ contents -->
    <flow name="dlq-admin-api">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/dlq"
                       method="GET"/>

        <os:retrieve key="dlqIndex"
                     objectStore="dlqIndexStore"
                     target="dlqKeys">
            <os:default-value>#[[] as Array]</os:default-value>
        </os:retrieve>

        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    totalEntries: sizeOf(vars.dlqKeys),
    entries: vars.dlqKeys
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

## How It Works

1. **Event subscription**: The subscriber listens to Platform Events on a specific topic. Each event is assigned a UUID for tracking (either from the event payload or derived from the replay ID).
2. **Try-catch processing**: The core business logic runs inside a `try` scope. If processing succeeds, the event flows through normally. If any error occurs, the `on-error-continue` handler activates.
3. **DLQ storage**: Failed events are wrapped in a DLQ entry object containing the original payload, error details, replay ID, attempt count, and retry scheduling metadata. This entry is stored in a persistent Object Store.
4. **Exponential backoff retry**: A scheduled flow runs every 5 minutes, iterates over all DLQ entries, and retries those whose `nextRetryAt` timestamp has passed. Backoff doubles each attempt: 5m, 10m, 20m, 40m, 80m, capped at 2 hours.
5. **Permanent failure**: After 10 failed attempts, the entry is marked `PERMANENTLY_FAILED` and requires manual intervention via the admin API.
6. **Admin API**: An HTTP endpoint exposes the DLQ contents for operations teams to inspect failed events and trigger manual replays.

## Key Takeaways

- Always use `on-error-continue` (not `on-error-propagate`) in Platform Event subscribers. Propagating errors causes the connector to disconnect and potentially miss subsequent events.
- Store the full event payload in the DLQ, not just a reference. Platform Events are retained for only 24 hours (72 hours for high-volume), so you cannot replay from source after that window.
- Cap exponential backoff at a reasonable maximum (2 hours) to prevent events from sitting in the DLQ for days without a retry attempt.
- Set a maximum attempt count and alert on `PERMANENTLY_FAILED` entries so operations can investigate root causes.
- Use a TTL on the DLQ Object Store that exceeds your maximum retry window to prevent entries from expiring before all retries are exhausted.

## Related Recipes

- [Streaming API Integration](../salesforce-streaming-api/)
- [CDC Replay Storm Prevention](../cdc-replay-storm-prevention/)
- [High-Volume Platform Events](../high-volume-platform-events/)
- [SF Pub/Sub API Migration](../sf-pubsub-api-migration/)
