## Data Migration Strategies
> Full, delta, and incremental migration patterns with rollback and audit logging

### When to Use
- Migrating data from a legacy system into Salesforce (or between Salesforce orgs)
- Setting up ongoing incremental sync with a watermark for changed records
- You need rollback capability in case a migration batch introduces bad data
- Large data volumes (millions of records) that require Bulk API and relationship ordering

### Configuration / Code

**Pattern 1: Full Migration with Batch Job**

```xml
<flow name="full-migration-flow">
    <http:listener config-ref="HTTPS_Listener"
        path="/api/migrate/full"
        allowedMethods="POST"/>

    <set-variable variableName="migrationId"
        value="#[uuid()]"/>
    <set-variable variableName="startTime"
        value="#[now()]"/>

    <logger level="INFO"
        message='Starting full migration #[vars.migrationId]'/>

    <!-- Extract from source -->
    <db:select config-ref="Source_Database">
        <db:sql>
            SELECT id, name, industry, phone, website,
                   billing_street, billing_city, billing_state, billing_zip,
                   external_id, created_date, modified_date
            FROM accounts
            ORDER BY id
        </db:sql>
    </db:select>

    <set-variable variableName="totalRecords" value="#[sizeOf(payload)]"/>

    <batch:job jobName="full-migration-batch"
        maxFailedRecords="500"
        blockSize="200">

        <batch:process-records>
            <batch:step name="transform">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    Name: payload.name,
    Industry: payload.industry,
    Phone: payload.phone,
    Website: payload.website,
    BillingStreet: payload.billing_street,
    BillingCity: payload.billing_city,
    BillingState: payload.billing_state,
    BillingPostalCode: payload.billing_zip,
    External_Id__c: payload.external_id,
    Migration_Id__c: vars.migrationId,
    Migration_Source__c: "Legacy_CRM"
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </batch:step>

            <batch:step name="backup-existing">
                <!-- Query existing record for rollback -->
                <salesforce:query config-ref="Salesforce_Config">
                    <salesforce:salesforce-query>
                        SELECT Id, Name, Industry, Phone, Website,
                               BillingStreet, BillingCity, BillingState, BillingPostalCode
                        FROM Account
                        WHERE External_Id__c = ':extId'
                    </salesforce:salesforce-query>
                    <salesforce:parameters>#[{
                        extId: payload.External_Id__c
                    }]</salesforce:parameters>
                </salesforce:query>

                <!-- Store backup for rollback -->
                <choice>
                    <when expression="#[sizeOf(payload) > 0]">
                        <db:insert config-ref="Migration_Database">
                            <db:sql>
                                INSERT INTO migration_backup
                                (migration_id, sf_id, external_id, record_data, backed_up_at)
                                VALUES (:migId, :sfId, :extId, :data, CURRENT_TIMESTAMP)
                            </db:sql>
                            <db:input-parameters>#[{
                                migId: vars.migrationId,
                                sfId: payload[0].Id,
                                extId: payload[0].External_Id__c default vars.currentRecord.External_Id__c,
                                data: write(payload[0], "application/json")
                            }]</db:input-parameters>
                        </db:insert>
                    </when>
                </choice>
            </batch:step>

            <batch:step name="upsert-to-salesforce">
                <batch:aggregator size="200">
                    <salesforce:upsert config-ref="Salesforce_Config"
                        objectType="Account"
                        externalIdFieldName="External_Id__c">
                        <salesforce:records>#[payload]</salesforce:records>
                    </salesforce:upsert>
                </batch:aggregator>
            </batch:step>

            <batch:step name="audit-log">
                <batch:aggregator size="200">
                    <db:bulk-insert config-ref="Migration_Database">
                        <db:sql>
                            INSERT INTO migration_audit_log
                            (migration_id, external_id, operation, status, created_at)
                            VALUES (:migId, :extId, 'UPSERT', 'SUCCESS', CURRENT_TIMESTAMP)
                        </db:sql>
                    </db:bulk-insert>
                </batch:aggregator>
            </batch:step>
        </batch:process-records>

        <batch:on-complete>
            <logger level="INFO"
                message='Migration #[vars.migrationId] complete. Total: #[payload.totalRecords], Success: #[payload.successfulRecords], Failed: #[payload.failedRecords]'/>
        </batch:on-complete>
    </batch:job>
</flow>
```

**Pattern 2: Incremental Sync with Watermark**

```xml
<flow name="incremental-sync-flow">
    <scheduler>
        <scheduling-strategy>
            <cron expression="0 */15 * * * ?"/>  <!-- Every 15 minutes -->
        </scheduling-strategy>
    </scheduler>

    <!-- Load watermark -->
    <os:retrieve key="migration-watermark"
        objectStore="watermark-store"
        target="lastSyncTime">
        <os:default-value>2000-01-01T00:00:00Z</os:default-value>
    </os:retrieve>

    <logger level="INFO"
        message='Incremental sync from watermark: #[vars.lastSyncTime]'/>

    <!-- Fetch only changed records since last sync -->
    <db:select config-ref="Source_Database">
        <db:sql>
            SELECT id, name, industry, phone, website, external_id, modified_date
            FROM accounts
            WHERE modified_date > :watermark
            ORDER BY modified_date ASC
            LIMIT 10000
        </db:sql>
        <db:input-parameters>#[{
            watermark: vars.lastSyncTime
        }]</db:input-parameters>
    </db:select>

    <choice>
        <when expression="#[sizeOf(payload) > 0]">
            <set-variable variableName="newWatermark"
                value="#[max(payload.modified_date)]"/>

            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (r) -> {
    Name: r.name,
    Industry: r.industry,
    Phone: r.phone,
    Website: r.website,
    External_Id__c: r.external_id
}
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <salesforce:upsert config-ref="Salesforce_Config"
                objectType="Account"
                externalIdFieldName="External_Id__c">
                <salesforce:records>#[payload]</salesforce:records>
            </salesforce:upsert>

            <!-- Update watermark only after successful sync -->
            <os:store key="migration-watermark"
                objectStore="watermark-store">
                <os:value>#[vars.newWatermark]</os:value>
            </os:store>

            <logger level="INFO"
                message='Synced #[sizeOf(payload)] records. New watermark: #[vars.newWatermark]'/>
        </when>
        <otherwise>
            <logger level="DEBUG" message="No new records since last sync"/>
        </otherwise>
    </choice>
</flow>

<os:object-store name="watermark-store"
    persistent="true"
    maxEntries="10"
    entryTtl="365"
    entryTtlUnit="DAYS"/>
```

**External ID Mapping (DataWeave)**

```dataweave
%dw 2.0
output application/json

// Map legacy system IDs to Salesforce External IDs
// Handles parent-child relationships by resolving references

var accountIdMap = vars.accountIdMap  // { legacyId -> externalId }

fun mapExternalId(legacyId: String): String =
    accountIdMap[legacyId] default ("LEGACY_" ++ legacyId)

---
payload map (record) -> {
    FirstName: (record.full_name splitBy " ")[0] default "",
    LastName: (record.full_name splitBy " ")[-1] default record.full_name,
    Email: record.email_address,
    Phone: record.phone_number,
    Contact_External_Id__c: "CNT_" ++ record.legacy_contact_id,
    // Resolve parent Account via External ID
    Account: {
        External_Id__c: mapExternalId(record.legacy_account_id)
    },
    // Resolve Record Type by developer name
    RecordType: {
        DeveloperName: if (record.contact_type == "VENDOR")
                "Vendor_Contact"
            else
                "Customer_Contact"
    }
}
```

**Rollback Flow**

```xml
<flow name="migration-rollback-flow">
    <http:listener config-ref="HTTPS_Listener"
        path="/api/migrate/rollback/{migrationId}"
        allowedMethods="POST"/>

    <set-variable variableName="migrationId"
        value="#[attributes.uriParams.migrationId]"/>

    <logger level="WARN"
        message='Rolling back migration #[vars.migrationId]'/>

    <!-- Fetch backup records -->
    <db:select config-ref="Migration_Database">
        <db:sql>
            SELECT sf_id, external_id, record_data
            FROM migration_backup
            WHERE migration_id = :migId
            ORDER BY sf_id
        </db:sql>
        <db:input-parameters>#[{
            migId: vars.migrationId
        }]</db:input-parameters>
    </db:select>

    <set-variable variableName="rollbackCount" value="#[sizeOf(payload)]"/>

    <foreach batchSize="200">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (backup) -> do {
    var original = read(backup.record_data, "application/json")
    ---
    original ++ { Id: backup.sf_id }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <salesforce:update config-ref="Salesforce_Config"
            objectType="Account">
            <salesforce:records>#[payload]</salesforce:records>
        </salesforce:update>
    </foreach>

    <logger level="INFO"
        message='Rollback complete. #[vars.rollbackCount] records restored.'/>

    <!-- Mark migration as rolled back -->
    <db:update config-ref="Migration_Database">
        <db:sql>
            UPDATE migration_audit_log
            SET status = 'ROLLED_BACK', rolled_back_at = CURRENT_TIMESTAMP
            WHERE migration_id = :migId
        </db:sql>
        <db:input-parameters>#[{
            migId: vars.migrationId
        }]</db:input-parameters>
    </db:update>
</flow>
```

**Relationship Ordering: Parent Before Child**

Migration order for dependent objects:

```
Phase 1 (No dependencies):
  Account, Product2, Pricebook2

Phase 2 (Depends on Phase 1):
  Contact (→ Account)
  PricebookEntry (→ Product2, Pricebook2)

Phase 3 (Depends on Phase 2):
  Opportunity (→ Account, Contact)

Phase 4 (Depends on Phase 3):
  OpportunityLineItem (→ Opportunity, PricebookEntry)
  OpportunityContactRole (→ Opportunity, Contact)

Phase 5 (Depends on Phase 4):
  Task (→ any WhoId/WhatId)
  Attachment / ContentDocumentLink (→ any LinkedEntityId)
```

### How It Works
1. **Full migration**: Extracts all records from the source, transforms them, and upserts to Salesforce using External IDs to prevent duplicates
2. **Backup before overwrite**: Before upserting, existing Salesforce records are queried and stored in a backup table tagged with the migration ID
3. **Incremental sync**: A watermark (last modified timestamp) tracks the high-water mark. Each sync run queries only records changed since the watermark
4. **Watermark update**: The watermark is updated only after successful processing, ensuring no records are lost if the job fails mid-run
5. **Rollback**: The backup table allows restoring Salesforce records to their pre-migration state by migration ID
6. **Relationship ordering**: Parent objects are migrated first, child objects reference parents via External ID lookups

### Gotchas
- **Large data volumes need Bulk API**: The standard Salesforce connector upsert is limited to 200 records per call. For millions of records, switch to Bulk API 2.0 to avoid burning through your API call budget
- **Relationship ordering (parent before child)**: If you try to insert a Contact with an AccountId that does not exist yet, the insert fails. Always migrate parent objects before children. Use External IDs for relationship resolution
- **Watermark clock precision**: If source system timestamps have only second precision but multiple records share the same second, some records may be skipped or duplicated. Use `>=` with deduplication rather than `>`
- **Rollback limitations**: Rollback only restores field values. It cannot un-delete records that were created (not updated) during migration. For new records, you need a separate delete step
- **External ID index**: Ensure `External_Id__c` is marked as an External ID field (unique, indexed) in Salesforce. Without the index, upserts perform table scans and may time out on large objects
- **Deleted records in source**: Incremental sync based on `modified_date` does not detect hard deletes in the source system. Implement a periodic reconciliation job that compares record counts or runs a full diff
- **Mixed character encodings**: Legacy systems may use Latin-1 or other encodings. Salesforce requires UTF-8. Add encoding conversion in the transform step to avoid `MALFORMED_ID` or garbled text

### Related
- [Bulk API 2.0 Partial Failure](../bulk-api-2-partial-failure/)
- [Governor Limit Safe Batch](../governor-limit-safe-batch/)
- [Composite API Patterns](../composite-api-patterns/)
- [Batch Block Size Optimization](../../performance/batch/block-size-optimization/)
- [Watermark Incremental Sync](../../performance/batch/watermark-incremental-sync/)
