## Bidirectional Sync & Conflict Resolution
> Synchronize records between Salesforce and an external system with configurable conflict resolution strategies

### When to Use
- Two systems share the same entity (e.g., Account, Contact) and both allow edits
- You need real-time or near-real-time sync without data loss
- Business rules dictate which system "wins" on a per-field or per-record basis
- You want a manual review queue for conflicts that cannot be auto-resolved

### Configuration / Code

**Salesforce CDC Listener — Capture Changes**

```xml
<flow name="sf-cdc-inbound-flow">
    <salesforce:subscribe-channel-listener
        config-ref="Salesforce_Config"
        streamingType="CDC"
        channel="/data/AccountChangeEvent">
        <scheduling-strategy>
            <fixed-frequency frequency="1000"/>
        </scheduling-strategy>
    </salesforce:subscribe-channel-listener>

    <set-variable variableName="changeType"
        value="#[payload.ChangeEventHeader.changeType]"/>
    <set-variable variableName="changedFields"
        value="#[payload.ChangeEventHeader.changedFields]"/>
    <set-variable variableName="sfLastModified"
        value="#[payload.LastModifiedDate]"/>
    <set-variable variableName="externalId"
        value="#[payload.External_Id__c]"/>

    <!-- Skip if change originated from this integration (loop prevention) -->
    <choice>
        <when expression="#[payload.ChangeEventHeader.changeOrigin contains 'com/integration']">
            <logger level="DEBUG" message="Skipping self-originated change"/>
        </when>
        <otherwise>
            <flow-ref name="conflict-check-flow"/>
        </otherwise>
    </choice>
</flow>
```

**Conflict Detection Flow**

```xml
<flow name="conflict-check-flow">
    <!-- Fetch current version from external system -->
    <http:request method="GET" config-ref="External_System_Config"
        path="/api/accounts/{externalId}">
        <http:uri-params>
            #[output application/java --- { externalId: vars.externalId }]
        </http:uri-params>
    </http:request>

    <set-variable variableName="externalRecord" value="#[payload]"/>
    <set-variable variableName="extLastModified"
        value="#[payload.lastModifiedDate]"/>

    <!-- Determine conflict resolution strategy -->
    <choice>
        <!-- No conflict: external not modified since last sync -->
        <when expression="#[vars.extLastModified &lt;= vars.lastSyncTimestamp]">
            <flow-ref name="apply-sf-changes-to-external"/>
        </when>
        <!-- Both modified: apply resolution strategy -->
        <otherwise>
            <flow-ref name="resolve-conflict-flow"/>
        </otherwise>
    </choice>
</flow>
```

**Strategy 1: Last-Write-Wins**

```xml
<flow name="resolve-conflict-lww">
    <choice>
        <when expression="#[vars.sfLastModified > vars.extLastModified]">
            <flow-ref name="apply-sf-changes-to-external"/>
        </when>
        <otherwise>
            <flow-ref name="apply-external-changes-to-sf"/>
        </otherwise>
    </choice>
</flow>
```

**Strategy 2: Field-Level Merge (DataWeave)**

```dataweave
%dw 2.0
output application/json

var sfRecord = vars.sfRecord
var extRecord = vars.externalRecord
var sfChangedFields = vars.changedFields
var fieldPriority = {
    "Name": "salesforce",
    "Phone": "salesforce",
    "BillingAddress": "external",
    "Revenue": "external",
    "Industry": "salesforce"
}

fun resolveField(fieldName, sfVal, extVal) =
    if (sfChangedFields contains fieldName)
        if (fieldPriority[fieldName] default "salesforce" == "salesforce")
            sfVal
        else extVal
    else extVal

---
{
    Name: resolveField("Name", sfRecord.Name, extRecord.name),
    Phone: resolveField("Phone", sfRecord.Phone, extRecord.phone),
    BillingStreet: resolveField("BillingAddress", sfRecord.BillingStreet, extRecord.billingStreet),
    BillingCity: resolveField("BillingAddress", sfRecord.BillingCity, extRecord.billingCity),
    AnnualRevenue: resolveField("Revenue", sfRecord.AnnualRevenue, extRecord.annualRevenue),
    Industry: resolveField("Industry", sfRecord.Industry, extRecord.industry),
    _metadata: {
        mergedAt: now(),
        sfVersion: sfRecord.LastModifiedDate,
        extVersion: extRecord.lastModifiedDate,
        strategy: "field-level-merge"
    }
}
```

**Strategy 3: Manual Review Queue**

```xml
<flow name="resolve-conflict-manual-review">
    <!-- Store both versions for human review -->
    <db:insert config-ref="Database_Config">
        <db:sql>
            INSERT INTO sync_conflict_queue
            (external_id, sf_record, ext_record, sf_modified, ext_modified, status, created_at)
            VALUES (:externalId, :sfJson, :extJson, :sfMod, :extMod, 'PENDING', CURRENT_TIMESTAMP)
        </db:sql>
        <db:input-parameters>#[{
            externalId: vars.externalId,
            sfJson: write(vars.sfRecord, "application/json"),
            extJson: write(vars.externalRecord, "application/json"),
            sfMod: vars.sfLastModified,
            extMod: vars.extLastModified
        }]</db:input-parameters>
    </db:insert>

    <logger level="WARN"
        message='Conflict queued for manual review: #[vars.externalId]'/>
</flow>
```

**Upsert Back to Salesforce (Loop-Safe)**

```xml
<flow name="apply-external-changes-to-sf">
    <salesforce:upsert config-ref="Salesforce_Config"
        objectType="Account"
        externalIdFieldName="External_Id__c">
        <salesforce:records>#[
            [vars.mergedRecord ++ { External_Id__c: vars.externalId }]
        ]</salesforce:records>
    </salesforce:upsert>
</flow>
```

### How It Works
1. A Salesforce CDC listener captures change events on the target object (e.g., Account)
2. The flow checks `changeOrigin` to skip changes made by this integration, preventing infinite loops
3. The external system's current version is fetched and compared against the last-sync timestamp
4. If only one side changed, the change is applied directly
5. If both sides changed, the configured conflict strategy runs:
   - **Last-write-wins**: the most recent `LastModifiedDate` takes precedence
   - **Field-level merge**: each field is resolved based on a priority map (which system owns which field)
   - **Manual review**: both versions are stored in a database queue for human decision
6. The resolved record is upserted using External ID to avoid duplicates
7. A sync timestamp watermark is updated after each successful sync

### Gotchas
- **Infinite sync loops**: Always check `changeOrigin` or use a boolean flag (`Integration_Updated__c`) to skip self-originated changes. Without this, System A writes to B, which triggers B to write back to A, endlessly
- **Clock skew**: Last-write-wins fails if system clocks differ. Use Salesforce `SystemModstamp` (server time) rather than `LastModifiedDate` (which respects field history)
- **CDC 3-day retention**: If your Mule app is down for more than 3 days, CDC events are lost. Use a watermark table to detect gaps and trigger a full reconciliation
- **Bulk changes**: A mass update in Salesforce generates one CDC event per record. Size your Mule worker and connection pool to handle bursts
- **External ID required**: Bidirectional sync only works reliably with a shared External ID. Relying on Salesforce Record ID creates a hard dependency on one system

### Related
- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [Salesforce Streaming API](../salesforce-streaming-api/)
- [Salesforce Invalid Session Recovery](../../error-handling/connector-errors/salesforce-invalid-session/)
- [Bulk API 2.0 Partial Failure](../bulk-api-2-partial-failure/)
