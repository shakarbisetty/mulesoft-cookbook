## CDC vs Platform Events Decision Guide
> Choose the right Salesforce event mechanism: Change Data Capture, Platform Events, or Outbound Messages

### When to Use
- You need real-time or near-real-time data propagation from Salesforce to external systems
- You are designing an event-driven architecture involving Salesforce
- You need to decide between push-based and pull-based integration patterns
- Multiple downstream systems need to react to Salesforce data changes

### Configuration / Code

**Decision Matrix**

| Criteria | Change Data Capture (CDC) | Platform Events | Outbound Messages |
|----------|--------------------------|-----------------|-------------------|
| **Trigger** | Any DML on subscribed objects | Apex/Flow/API publish | Workflow rule/Flow |
| **Latency** | Near-real-time (~1-5s) | Near-real-time (~1-3s) | Near-real-time (~5-15s) |
| **Retention** | 3 days | 72 hours (high-volume) / 24 hours (standard) | Retries up to 24 hours |
| **Replay** | Yes (replayId) | Yes (replayId) | No (retry only) |
| **Filtering** | Field-level change tracking | Custom payload schema | Fixed fields per config |
| **Volume** | Matches DML volume | Up to 250K/hour (high-volume) | Limited by workflow eval |
| **Payload** | Changed fields + header | Custom-defined schema | Selected fields (SOAP XML) |
| **Protocol** | CometD / gRPC (Pub/Sub) | CometD / gRPC (Pub/Sub) | SOAP HTTP callback |
| **Setup** | Admin toggle per object | Custom object definition | Workflow + endpoint config |
| **Governor limits** | No publish limits (system) | Counts against Apex limits | Workflow limits apply |
| **Best for** | Data replication, audit | Custom business events | Legacy SOAP integrations |

**Pattern 1: CDC Listener**

```xml
<flow name="cdc-listener-flow">
    <salesforce:subscribe-channel-listener
        config-ref="Salesforce_Config"
        streamingType="CDC"
        channel="/data/AccountChangeEvent"
        replayOption="ONLY_NEW">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-channel-listener>

    <logger level="INFO"
        message='CDC event received. Type: #[payload.ChangeEventHeader.changeType], Entity: #[payload.ChangeEventHeader.entityName]'/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
var header = payload.ChangeEventHeader
---
{
    eventType: header.changeType,
    entityName: header.entityName,
    recordIds: header.recordIds,
    changedFields: header.changedFields,
    changeOrigin: header.changeOrigin,
    transactionKey: header.transactionKey,
    commitTimestamp: header.commitTimestamp,
    data: payload - "ChangeEventHeader"
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="route-to-downstream-systems"/>
</flow>
```

**Pattern 2: Platform Event Subscriber**

```xml
<!-- Platform Event definition (deploy as metadata): Order_Completed__e -->
<!--
  Fields:
    Order_Id__c (Text 18)
    Total_Amount__c (Currency)
    Customer_Id__c (Text 18)
    Fulfillment_Status__c (Text 50)
-->

<flow name="platform-event-subscriber-flow">
    <salesforce:subscribe-channel-listener
        config-ref="Salesforce_Config"
        streamingType="PLATFORM_EVENT"
        channel="/event/Order_Completed__e"
        replayOption="ONLY_NEW">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-channel-listener>

    <logger level="INFO"
        message='Platform Event received: Order #[payload.Order_Id__c], Amount: #[payload.Total_Amount__c]'/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    orderId: payload.Order_Id__c,
    totalAmount: payload.Total_Amount__c,
    customerId: payload.Customer_Id__c,
    fulfillmentStatus: payload.Fulfillment_Status__c,
    replayId: payload.ReplayId,
    createdDate: payload.CreatedDate
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="process-order-completion"/>
</flow>
```

**Pattern 3: Outbound Message HTTP Listener**

```xml
<flow name="outbound-message-receiver-flow">
    <http:listener config-ref="HTTPS_Listener"
        path="/sf/outbound-messages/case-escalation"
        allowedMethods="POST"/>

    <!-- Outbound messages are SOAP XML -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
ns sf http://soap.sforce.com/2005/09/outbound
ns sobj urn:sobject.enterprise.soap.sforce.com
---
{
    actionId: payload.sf#notifications.sf#Notification.sf#Id,
    objectId: payload.sf#notifications.sf#Notification.sf#sObject.sobj#Id,
    caseNumber: payload.sf#notifications.sf#Notification.sf#sObject.sobj#CaseNumber,
    priority: payload.sf#notifications.sf#Notification.sf#sObject.sobj#Priority,
    status: payload.sf#notifications.sf#Notification.sf#sObject.sobj#Status
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="handle-case-escalation"/>

    <!-- Must return SOAP ACK or Salesforce retries -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/xml
ns soapenv http://schemas.xmlsoap.org/soap/envelope/
ns sf http://soap.sforce.com/2005/09/outbound
---
{
    soapenv#Envelope: {
        soapenv#Body: {
            sf#notificationsResponse: {
                sf#Ack: true
            }
        }
    }
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works

**Change Data Capture (CDC)**
1. Enable CDC on specific objects in Salesforce Setup (Change Data Capture page)
2. Salesforce publishes an event for every INSERT, UPDATE, DELETE, or UNDELETE
3. Events include a `ChangeEventHeader` with metadata (changed fields, record IDs, change origin)
4. The Mule Salesforce connector subscribes via CometD and receives events in near-real-time
5. Replay ID support allows recovering missed events after a disconnect (within the 3-day window)

**Platform Events**
1. Define a custom Platform Event object in Salesforce (Setup > Platform Events)
2. Publish events from Apex, Process Builder, Flow, or the REST API
3. Subscribers receive the custom payload with exactly the fields you defined
4. High-volume Platform Events support up to 250K events/hour and 72-hour retention
5. The Mule connector subscribes the same way as CDC but on the `/event/` channel

**Outbound Messages**
1. Configure a Workflow Rule or Flow to trigger an outbound message on record change
2. Salesforce sends a SOAP XML POST to your configured endpoint URL
3. Your Mule app must return a SOAP ACK; otherwise Salesforce retries for up to 24 hours
4. Limited to fields selected at configuration time, no dynamic field tracking

### Gotchas
- **CDC 3-day retention**: If your subscriber is offline for more than 3 days, events are permanently lost. Implement a reconciliation job for disaster recovery
- **Platform Event replay limits**: Standard-volume PE retains events for only 24 hours. High-volume PE extends to 72 hours but requires additional entitlement
- **Outbound Message SOAP dependency**: Outbound messages produce SOAP XML that requires XML namespace-aware parsing. Modern REST-first architectures should prefer CDC or Platform Events
- **CDC gap events**: When CDC cannot deliver all changes (e.g., during high-volume bulk operations), it sends a GAP event. Your subscriber must handle this by querying Salesforce for the missing data
- **Platform Event governor limits**: Publishing from Apex counts against the `Limits.getPublishImmediateDML()` governor limit. In triggers, keep to one `EventBus.publish()` call per transaction
- **CDC does not fire for formula fields**: CDC only tracks stored field changes. Formula field value changes do not generate events
- **Outbound message retry storms**: If your endpoint is down, Salesforce queues retries. When the endpoint comes back, all queued messages arrive at once. Size your Mule workers accordingly

### Related
- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
- [Salesforce Streaming API](../salesforce-streaming-api/)
- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
