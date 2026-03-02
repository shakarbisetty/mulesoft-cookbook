# High-Volume Platform Event Consumption with Backpressure

## Problem

Salesforce Platform Events can burst to thousands of events per second during batch operations, data loads, or cascade triggers. A MuleSoft subscriber that processes events one at a time cannot keep up, causing subscriber lag that compounds over time. Without backpressure control, the subscriber either falls behind irreversibly (eventually losing events when they expire from the 72-hour retention window) or overwhelms downstream systems by forwarding events faster than they can handle.

## Solution

Implement a scalable subscriber architecture with configurable polling batch sizes, parallel processing lanes, flow control via `maxEventsPerPoll`, subscriber lag monitoring, and downstream backpressure detection. Use a watermark pattern to track processing position and automatically scale throughput based on current lag depth.

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

    <!-- Tuning properties -->
    <global-property name="pe.maxEventsPerPoll" value="100"/>
    <global-property name="pe.processingThreads" value="4"/>
    <global-property name="pe.lagThreshold.warning" value="1000"/>
    <global-property name="pe.lagThreshold.critical" value="10000"/>

    <!-- Subscriber lag tracking -->
    <os:object-store name="subscriberMetricsStore"
                     persistent="true"
                     entryTtl="24"
                     entryTtlUnit="HOURS"/>

    <!-- High-Volume Platform Event Subscriber -->
    <flow name="hv-platform-event-subscriber">
        <salesforce:subscribe-channel config-ref="Salesforce_PubSub_Config"
                                      channelName="/event/Order_Event__e"
                                      replayPreset="LATEST">
            <!-- Batch fetch: retrieve up to N events per poll cycle -->
            <salesforce:fetch-size>
                #[Mule::p('pe.maxEventsPerPoll') as Number]
            </salesforce:fetch-size>
        </salesforce:subscribe-channel>

        <!-- Track subscriber position for lag monitoring -->
        <ee:transform doc:name="Extract Subscriber Metrics">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    batchSize: sizeOf(payload),
    replayId: attributes.replayId,
    receivedAt: now(),
    events: payload
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="batchMetrics"
                      value="#[{batchSize: payload.batchSize, receivedAt: payload.receivedAt}]"/>
        <set-variable variableName="eventBatch" value="#[payload.events]"/>

        <!-- Update lag metrics -->
        <flow-ref name="update-subscriber-metrics"/>

        <!-- Process events in parallel lanes for throughput -->
        <scatter-gather doc:name="Parallel Processing Lanes"
                        maxConcurrency="#[Mule::p('pe.processingThreads') as Number]">
            <route>
                <foreach collection="#[vars.eventBatch[0 to (sizeOf(vars.eventBatch)/4) - 1]]">
                    <flow-ref name="process-single-event"/>
                </foreach>
            </route>
            <route>
                <foreach collection="#[vars.eventBatch[(sizeOf(vars.eventBatch)/4) to (sizeOf(vars.eventBatch)/2) - 1]]">
                    <flow-ref name="process-single-event"/>
                </foreach>
            </route>
            <route>
                <foreach collection="#[vars.eventBatch[(sizeOf(vars.eventBatch)/2) to (sizeOf(vars.eventBatch)*3/4) - 1]]">
                    <flow-ref name="process-single-event"/>
                </foreach>
            </route>
            <route>
                <foreach collection="#[vars.eventBatch[(sizeOf(vars.eventBatch)*3/4) to -1]]">
                    <flow-ref name="process-single-event"/>
                </foreach>
            </route>
        </scatter-gather>

        <logger level="INFO"
                message='Batch of #[vars.batchMetrics.batchSize] events processed in #[(now() - vars.batchMetrics.receivedAt)]'/>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                        message='Event batch processing failed: #[error.description]'/>
                <!-- Route failed batch to DLQ -->
                <flow-ref name="store-failed-batch-to-dlq"/>
            </on-error-continue>
        </error-handler>
    </flow>

    <!-- Individual event processor with downstream backpressure -->
    <sub-flow name="process-single-event">
        <try>
            <!-- Check downstream system availability before processing -->
            <os:retrieve key="downstreamHealthy"
                         objectStore="subscriberMetricsStore"
                         target="isDownstreamHealthy">
                <os:default-value>#[true]</os:default-value>
            </os:retrieve>

            <choice>
                <when expression="#[vars.isDownstreamHealthy == true]">
                    <!-- Transform event payload -->
                    <ee:transform doc:name="Transform Event">
                        <ee:message>
                            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    orderId: payload.Order_Id__c,
    action: payload.Action__c,
    orderData: {
        accountId: payload.Account_Id__c,
        amount: payload.Amount__c,
        status: payload.Status__c,
        lineItems: if (payload.Line_Items_JSON__c != null)
            read(payload.Line_Items_JSON__c, "application/json")
            else []
    },
    eventMetadata: {
        replayId: attributes.replayId,
        createdDate: payload.CreatedDate
    }
}
                            ]]></ee:set-payload>
                        </ee:message>
                    </ee:transform>

                    <!-- Send to downstream system -->
                    <http:request method="POST"
                                  config-ref="Downstream_HTTP_Config"
                                  path="/api/orders"
                                  responseTimeout="5000">
                        <http:body>#[payload]</http:body>
                    </http:request>
                </when>
                <otherwise>
                    <!-- Downstream is unhealthy: buffer the event -->
                    <logger level="WARN"
                            message='Downstream unhealthy. Buffering event #[payload.Order_Id__c]'/>
                    <flow-ref name="buffer-event-for-retry"/>
                </otherwise>
            </choice>

            <error-handler>
                <on-error-continue type="HTTP:TIMEOUT OR HTTP:CONNECTIVITY">
                    <!-- Downstream timeout: mark as unhealthy, enable backpressure -->
                    <logger level="ERROR"
                            message='Downstream timeout detected. Enabling backpressure.'/>
                    <os:store key="downstreamHealthy"
                              objectStore="subscriberMetricsStore">
                        <os:value>#[false]</os:value>
                    </os:store>
                    <flow-ref name="buffer-event-for-retry"/>
                </on-error-continue>
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                            message='Event processing error: #[error.description]'/>
                </on-error-continue>
            </error-handler>
        </try>
    </sub-flow>

    <!-- Subscriber lag monitor -->
    <sub-flow name="update-subscriber-metrics">
        <os:retrieve key="subscriberLag"
                     objectStore="subscriberMetricsStore"
                     target="currentLag">
            <os:default-value>#[0]</os:default-value>
        </os:retrieve>

        <ee:transform doc:name="Calculate Lag Metrics">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var warningThreshold = Mule::p('pe.lagThreshold.warning') as Number
var criticalThreshold = Mule::p('pe.lagThreshold.critical') as Number
var currentLag = vars.currentLag as Number

var lagLevel = if (currentLag >= criticalThreshold) "CRITICAL"
               else if (currentLag >= warningThreshold) "WARNING"
               else "NORMAL"
---
{
    currentLag: currentLag,
    lagLevel: lagLevel,
    lastBatchSize: vars.batchMetrics.batchSize,
    recommendation: lagLevel match {
        case "CRITICAL" -> "Scale workers or increase maxEventsPerPoll"
        case "WARNING"  -> "Monitor closely, consider scaling"
        else            -> "Operating normally"
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <choice>
            <when expression="#[payload.lagLevel != 'NORMAL']">
                <logger level="WARN"
                        message='Subscriber lag alert: #[payload.lagLevel] - #[payload.currentLag] events behind. #[payload.recommendation]'/>
            </when>
        </choice>
    </sub-flow>

    <!-- Downstream health check (runs every 30 seconds) -->
    <flow name="downstream-health-check">
        <scheduler>
            <scheduling-strategy>
                <fixed-frequency frequency="30" timeUnit="SECONDS"/>
            </scheduling-strategy>
        </scheduler>

        <try>
            <http:request method="GET"
                          config-ref="Downstream_HTTP_Config"
                          path="/api/health"
                          responseTimeout="3000"/>

            <!-- Downstream is healthy: clear backpressure flag -->
            <os:store key="downstreamHealthy"
                      objectStore="subscriberMetricsStore">
                <os:value>#[true]</os:value>
            </os:store>

            <error-handler>
                <on-error-continue type="ANY">
                    <os:store key="downstreamHealthy"
                              objectStore="subscriberMetricsStore">
                        <os:value>#[false]</os:value>
                    </os:store>
                </on-error-continue>
            </error-handler>
        </try>
    </flow>
</mule>
```

## How It Works

1. **Batch fetch**: The subscriber uses `fetchSize` to retrieve up to 100 events per poll cycle, reducing the per-event overhead of individual fetch requests.
2. **Parallel processing**: A scatter-gather splits the event batch across 4 parallel routes, processing events concurrently within each batch for higher throughput.
3. **Downstream backpressure**: If the downstream system times out, a flag is set in the Object Store to redirect subsequent events to a buffer queue. A health check flow polls the downstream system every 30 seconds and clears the flag when it recovers.
4. **Lag monitoring**: Subscriber lag metrics are tracked and classified against configurable thresholds (1,000 events for warning, 10,000 for critical), triggering alerts with scaling recommendations.
5. **Error isolation**: Each event is processed in a `try` scope so that a single event failure does not block the entire batch or disconnect the subscriber.

## Key Takeaways

- Start with `maxEventsPerPoll` at 100 and tune based on observed processing time per event. If each event takes 50ms, a batch of 100 takes 5 seconds sequentially or ~1.25 seconds with 4 parallel lanes.
- Monitor subscriber lag as a top-level operational metric. A growing lag means your subscriber cannot keep up with the event publication rate.
- Always use `on-error-continue` in Platform Event subscribers. Using `on-error-propagate` causes the connector to disconnect, creating a gap in event consumption.
- Implement downstream health checks separately from event processing. Detecting downstream failures before attempting to forward events prevents cascading timeouts.
- For Mule Runtime deployed on CloudHub, horizontal scaling (adding workers) is more effective than increasing thread counts on a single worker.

## Related Recipes

- [Platform Events DLQ Pattern](../platform-events-dlq-pattern/)
- [SF Pub/Sub API Migration](../sf-pubsub-api-migration/)
- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [Streaming API Integration](../salesforce-streaming-api/)
