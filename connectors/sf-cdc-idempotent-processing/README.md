## Salesforce CDC Idempotent Processing

> Deduplicate Salesforce Change Data Capture events using replay ID tracking, Object Store watermarks, and composite key filtering.

### When to Use

- Consuming Salesforce CDC events via the Salesforce connector's streaming subscription
- Mule application restarts cause re-delivery of CDC events, creating duplicates in the target system
- Need exactly-once semantics for Salesforce data changes propagated to ERP, data warehouse, or other systems
- Processing high-volume CDC streams where the same record changes multiple times within the replay window

### The Problem

Salesforce CDC delivers change events via the Streaming API (CometD). When a Mule application restarts, it replays events from the last known position, but if the replay ID was not persisted, it replays from the beginning of the 72-hour retention window. Even with replay ID tracking, the same record can generate multiple change events (e.g., a record updated 5 times in 10 seconds produces 5 events). Without deduplication, your downstream system processes all 5, potentially overwriting correct data with stale intermediate states.

### Configuration

#### Salesforce Streaming with Persistent Replay ID

```xml
<salesforce:config name="Salesforce_Config" doc:name="Salesforce Config">
    <salesforce:oauth-user-pass-connection
        consumerKey="${sf.consumerKey}"
        consumerSecret="${sf.consumerSecret}"
        username="${sf.username}"
        password="${sf.password}"
        securityToken="${sf.securityToken}"
        tokenEndpoint="https://login.salesforce.com/services/oauth2/token" />
</salesforce:config>

<os:object-store name="SF_CDC_Replay_Store"
    doc:name="SF CDC Replay Store"
    persistent="true"
    entryTtl="72"
    entryTtlUnit="HOURS"
    maxEntries="1000" />

<os:object-store name="SF_CDC_Dedup_Store"
    doc:name="SF CDC Dedup Store"
    persistent="true"
    entryTtl="24"
    entryTtlUnit="HOURS"
    maxEntries="50000" />
```

#### CDC Subscription with Replay and Dedup

```xml
<flow name="sf-cdc-subscriber-flow">
    <salesforce:subscribe-channel-listener config-ref="Salesforce_Config"
        doc:name="Subscribe to CDC"
        streamingChannel="/data/AccountChangeEvent"
        replayOption="REPLAY_FROM_LAST_EVENT"
        autoReplay="true" />

    <!-- Extract event metadata -->
    <set-variable variableName="replayId"
        value="#[payload.data.event.replayId]" />
    <set-variable variableName="changeType"
        value="#[payload.data.metadata.changeType]" />
    <set-variable variableName="recordIds"
        value="#[payload.data.metadata.recordIds]" />
    <set-variable variableName="commitTimestamp"
        value="#[payload.data.metadata.commitTimestamp]" />
    <set-variable variableName="transactionKey"
        value="#[payload.data.metadata.transactionKey]" />

    <!-- Build dedup key: transactionKey + recordId ensures exactly-once -->
    <set-variable variableName="dedupKey"
        value="#[vars.transactionKey ++ '_' ++ (vars.recordIds[0] default 'unknown')]" />

    <!-- Check for duplicate -->
    <try doc:name="Dedup Check">
        <os:contains key="#[vars.dedupKey]"
            objectStore="SF_CDC_Dedup_Store"
            doc:name="Already Processed?" />

        <choice doc:name="Duplicate?">
            <when expression="#[payload == true]">
                <logger level="DEBUG"
                    message="Skipping duplicate CDC event: #[vars.dedupKey]" />
            </when>
            <otherwise>
                <!-- Mark as processing -->
                <os:store key="#[vars.dedupKey]"
                    objectStore="SF_CDC_Dedup_Store">
                    <os:value><![CDATA[#[vars.commitTimestamp]]]></os:value>
                </os:store>

                <!-- Route by change type -->
                <choice doc:name="Route by Change Type">
                    <when expression="#[vars.changeType == 'CREATE']">
                        <flow-ref name="sf-cdc-handle-create-subflow" />
                    </when>
                    <when expression="#[vars.changeType == 'UPDATE']">
                        <flow-ref name="sf-cdc-handle-update-subflow" />
                    </when>
                    <when expression="#[vars.changeType == 'DELETE']">
                        <flow-ref name="sf-cdc-handle-delete-subflow" />
                    </when>
                    <when expression="#[vars.changeType == 'UNDELETE']">
                        <flow-ref name="sf-cdc-handle-create-subflow" />
                    </when>
                </choice>

                <!-- Persist replay ID after successful processing -->
                <os:store key="AccountChangeEvent_replayId"
                    objectStore="SF_CDC_Replay_Store">
                    <os:value><![CDATA[#[vars.replayId as String]]]></os:value>
                </os:store>
            </otherwise>
        </choice>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                    message="CDC processing failed for #[vars.dedupKey]: #[error.description]. Event will be retried." />
                <!-- Remove dedup key so retry can process it -->
                <os:remove key="#[vars.dedupKey]"
                    objectStore="SF_CDC_Dedup_Store"
                    doc:name="Remove Failed Dedup Key" />
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### Change Event Processing Sub-Flows

```xml
<sub-flow name="sf-cdc-handle-create-subflow">
    <ee:transform doc:name="Map CDC to Target Format">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var changedFields = payload.data.payload
---
{
    operation: "INSERT",
    sourceSystem: "Salesforce",
    sourceObject: "Account",
    recordId: vars.recordIds[0],
    commitTimestamp: vars.commitTimestamp,
    data: {
        accountId: changedFields.Id,
        name: changedFields.Name,
        industry: changedFields.Industry,
        annualRevenue: changedFields.AnnualRevenue,
        billingCity: changedFields.BillingCity,
        billingState: changedFields.BillingState,
        billingCountry: changedFields.BillingCountry,
        phone: changedFields.Phone,
        website: changedFields.Website,
        ownerId: changedFields.OwnerId
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="Target_API_Config"
        method="POST"
        path="/api/accounts" />
</sub-flow>

<sub-flow name="sf-cdc-handle-update-subflow">
    <ee:transform doc:name="Map Changed Fields Only">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var changedFields = payload.data.payload
var header = payload.data.metadata
// CDC only includes changed fields — non-null fields are the ones that changed
var fieldMap = changedFields mapObject ((value, key) ->
    if (value != null and (key as String) != "Id")
        { (key): value }
    else {}
)
---
{
    operation: "UPDATE",
    sourceSystem: "Salesforce",
    recordId: vars.recordIds[0],
    commitTimestamp: vars.commitTimestamp,
    changedFields: fieldMap,
    changeOrigin: header.changeOrigin default "unknown"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="Target_API_Config"
        method="PATCH"
        path="#['/api/accounts/' ++ vars.recordIds[0]]" />
</sub-flow>

<sub-flow name="sf-cdc-handle-delete-subflow">
    <ee:transform doc:name="Build Delete Event">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    operation: "DELETE",
    sourceSystem: "Salesforce",
    recordId: vars.recordIds[0],
    commitTimestamp: vars.commitTimestamp
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="Target_API_Config"
        method="DELETE"
        path="#['/api/accounts/' ++ vars.recordIds[0]]" />
</sub-flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Extract only the fields that actually changed (non-null values in CDC payload)
fun extractChangedFields(cdcPayload: Object): Object =
    cdcPayload filterObject ((value, key) ->
        value != null
        and (key as String) != "Id"
        and (key as String) != "LastModifiedDate"
    )

// Build a composite dedup key from CDC metadata
fun buildDedupKey(metadata: Object): String =
    (metadata.transactionKey default "none") ++ "_" ++
    (metadata.recordIds[0] default "unknown") ++ "_" ++
    (metadata.sequenceNumber default 0) as String
---
{
    example: buildDedupKey({
        transactionKey: "abc-123",
        recordIds: ["001xx000003GYlA"],
        sequenceNumber: 1
    })
}
```

### Gotchas

- **72-hour replay window** — Salesforce retains CDC events for 72 hours. If your Mule application is down for longer, events are permanently lost. Implement a reconciliation flow that does a full or incremental SOQL query on restart if the gap exceeds 72 hours
- **CDC sends only changed fields on UPDATE** — Unlike triggers, CDC UPDATE events include only the fields that changed plus the record ID. If your target system requires the full record, you must query Salesforce for the complete object after receiving the CDC event
- **Gap events** — When Salesforce cannot deliver all events (e.g., high volume or overflow), it sends a GAP event. Your flow must handle this by falling back to a SOQL-based sync for the affected time range
- **`transactionKey` is the true dedup key** — `replayId` is not stable across Salesforce pod switches. Use `transactionKey` combined with `recordId` for reliable deduplication
- **Compound CDC events** — A single transaction that updates 200 records produces a single CDC event with up to 200 record IDs. Your processing logic must iterate over `recordIds`, not assume a single ID
- **Object Store TTL must exceed replay window** — If your dedup store TTL is shorter than the replay window, replayed events will pass dedup. Set TTL to at least 72 hours
- **CDC requires Enterprise Edition or higher** — CDC is not available on Salesforce Professional Edition. It also requires enabling CDC on each object individually via Setup

### Testing

```xml
<munit:test name="sf-cdc-dedup-test"
    description="Verify duplicate CDC events are skipped">

    <munit:behavior>
        <munit-tools:mock-when processor="os:contains">
            <munit-tools:then-return>
                <munit-tools:payload value="#[true]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="dedupKey" value="tx-001_001xx000003GYlA" />
        <set-variable variableName="changeType" value="UPDATE" />
        <set-variable variableName="replayId" value="12345" />
        <flow-ref name="sf-cdc-subscriber-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="http:request"
            times="0" />
    </munit:validation>
</munit:test>
```

### Related

- [Database CDC](../database-cdc/) — Similar patterns for database-level change capture
- [SF Bulk API v2 Optimization](../sf-bulk-api-v2-optimization/) — Bulk querying as a fallback when CDC gap events occur
- [SF Governor Limit Patterns](../sf-governor-limit-patterns/) — Staying within API limits when processing high-volume CDC
