## Salesforce Streaming API Integration
> Real-time notifications via PushTopics, Generic Events, and CometD with replay durability

### When to Use
- You need real-time notifications when Salesforce records are created, updated, or deleted
- PushTopics give you SOQL-filtered notifications on standard/custom objects
- Generic Streaming Events provide a custom publish-subscribe channel
- You need replay capability to recover events after a subscriber disconnect
- Your use case predates Platform Events / CDC and you are maintaining an existing integration

### Configuration / Code

**PushTopic Definition (via Salesforce Apex or Workbench)**

```java
// Execute in Developer Console or Workbench
PushTopic pushTopic = new PushTopic();
pushTopic.Name = 'HighValueOpportunities';
pushTopic.Query = 'SELECT Id, Name, Amount, StageName, CloseDate, Account.Name ' +
                  'FROM Opportunity ' +
                  'WHERE Amount > 100000';
pushTopic.ApiVersion = 59.0;
pushTopic.NotifyForOperationCreate = true;
pushTopic.NotifyForOperationUpdate = true;
pushTopic.NotifyForOperationUndelete = true;
pushTopic.NotifyForOperationDelete = true;
pushTopic.NotifyForFields = 'Referenced';  // Only fire when queried fields change
insert pushTopic;
```

**Mule Streaming Connector: PushTopic Subscription**

```xml
<flow name="streaming-pushtopic-flow">
    <salesforce:subscribe-topic-listener
        config-ref="Salesforce_Config"
        topic="HighValueOpportunities">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-topic-listener>

    <logger level="INFO"
        message='PushTopic event received: #[payload.Id] - #[payload.Name]'/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    eventType: "OPPORTUNITY_CHANGE",
    recordId: payload.Id,
    name: payload.Name,
    amount: payload.Amount,
    stage: payload.StageName,
    closeDate: payload.CloseDate,
    accountName: payload.Account.Name,
    receivedAt: now() as String { format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ" }
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="notify-sales-team"/>
</flow>
```

**Replay Configuration for Durability**

```xml
<!-- Replay from a stored position to recover missed events -->
<flow name="streaming-with-replay-flow">
    <salesforce:subscribe-topic-listener
        config-ref="Salesforce_Config"
        topic="HighValueOpportunities"
        replayOption="FROM_REPLAY_ID"
        replayId="#[vars.lastReplayId]">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-topic-listener>

    <!-- Store replay ID after processing -->
    <set-variable variableName="currentReplayId"
        value="#[attributes.replayId]"/>

    <flow-ref name="process-event"/>

    <!-- Persist replay ID for recovery -->
    <os:store key="sf-streaming-replay-id"
        objectStore="persistent-store">
        <os:value>#[vars.currentReplayId]</os:value>
    </os:store>
</flow>

<!-- On application startup, load last replay ID -->
<flow name="load-replay-id-on-startup">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="999999999"/>  <!-- Run once -->
        </scheduling-strategy>
    </scheduler>

    <try>
        <os:retrieve key="sf-streaming-replay-id"
            objectStore="persistent-store"
            target="lastReplayId"/>
    </try>
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <!-- First run: start from latest -->
            <set-variable variableName="lastReplayId" value="#[-1]"/>
        </on-error-continue>
    </error-handler>
</flow>

<os:object-store name="persistent-store"
    persistent="true"
    maxEntries="100"
    entryTtl="30"
    entryTtlUnit="DAYS"/>
```

**Generic Streaming Event (Custom Channel)**

```xml
<!-- Subscribe to a generic streaming channel -->
<flow name="generic-streaming-flow">
    <salesforce:subscribe-channel-listener
        config-ref="Salesforce_Config"
        streamingType="GENERIC"
        channel="/u/notifications/ImportComplete">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-channel-listener>

    <logger level="INFO"
        message='Generic event received: #[payload]'/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    channel: "/u/notifications/ImportComplete",
    payload: payload.payload default payload,
    receivedAt: now()
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

**Comparison: Streaming API vs CDC vs Platform Events**

| Feature | Streaming API (PushTopic) | Change Data Capture | Platform Events |
|---------|--------------------------|---------------------|-----------------|
| **Filtering** | SOQL WHERE clause | All changes on object | Custom payload |
| **Setup** | Apex PushTopic insert | Admin toggle | Custom event definition |
| **Field control** | SOQL SELECT fields | All changed fields | Custom schema |
| **Replay** | 24-hour window | 3-day window | 24-72 hour window |
| **Protocol** | CometD (legacy) | CometD or gRPC Pub/Sub | CometD or gRPC Pub/Sub |
| **Limits** | 50 PushTopics per org (was 40) | Per-object enablement | Publishing governor limits |
| **Direction** | Salesforce outbound only | Salesforce outbound only | Bidirectional |
| **Recommendation** | Legacy; migrate to CDC/PE | Data replication | Custom business events |

### How It Works
1. A PushTopic is defined in Salesforce with a SOQL query specifying which object and fields to monitor
2. When a DML operation matches the PushTopic criteria, Salesforce publishes an event on the CometD channel
3. The Mule Salesforce connector subscribes to the channel using long-polling (CometD Bayeux protocol)
4. Each event includes a `replayId` — an incrementing integer unique to the channel
5. To recover missed events after a disconnect, the subscriber reconnects with the last processed `replayId`
6. Replay IDs are persisted in an Object Store so they survive Mule application restarts
7. Generic Streaming Events work similarly but allow arbitrary JSON payloads published via Apex or REST API

### Gotchas
- **40-50 PushTopic limit per org**: Salesforce limits PushTopics to 50 per org (API v37.0+, 40 in older versions). Plan topic allocation carefully across integrations
- **Replay ID storage is critical**: If you lose the replay ID and restart with `-1` (latest), you miss all events during the downtime. If you restart with `-2` (all available), you may reprocess already-handled events. Persist replay IDs in a durable Object Store
- **Concurrent client limits**: Salesforce limits concurrent CometD clients to 2,000 per org. Each Mule worker with a streaming listener counts as one client
- **PushTopic SOQL restrictions**: PushTopic queries do not support aggregate functions, ORDER BY, LIMIT, or semi-joins. The query must return `Id` and only fields on the subscribed object (one level of parent relationship allowed)
- **Streaming is being superseded**: Salesforce recommends CDC and Platform Events over PushTopics for new development. PushTopics are not deprecated but receive no new features
- **Network timeouts**: CometD long-polling requires stable network connections. Set the Mule HTTP client timeout to at least 120 seconds to avoid premature disconnects
- **No guaranteed ordering**: Events may arrive out of order during high-volume periods. Use `replayId` sequence for ordering if needed

### Related
- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
