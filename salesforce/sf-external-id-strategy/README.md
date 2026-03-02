# External ID Strategy for Salesforce Data Migration

## Problem

Data migration into Salesforce requires mapping records between the source system and Salesforce. Without external IDs, every insert returns a new Salesforce ID that must be captured and mapped to the source record for parent-child relationship resolution. This creates a "chicken and egg" problem: to create a Contact with an AccountId, you need the Account's Salesforce ID, but the Account was just created and the ID is buried in a bulk job result. Teams that skip external ID planning end up with manual ID mapping spreadsheets, broken relationships, duplicate records on re-runs, and migrations that cannot be restarted without data cleanup.

## Solution

Design a comprehensive external ID strategy that enables idempotent upserts, automatic parent-child relationship resolution via external ID references, cross-reference mapping between source and Salesforce IDs, and safe re-runnable migrations. Include DataWeave for ID mapping, external ID field design guidelines, and patterns for handling the parent-child sequencing problem.

## Implementation

**External ID Field Design Guidelines**

```yaml
external_id_design:
  naming_convention: "{SourceSystem}_External_Id__c"
  examples:
    - SAP_External_Id__c        # SAP source system
    - Legacy_CRM_Id__c          # Legacy CRM migration
    - ERP_Customer_Number__c    # ERP customer ID
    - Global_UUID__c            # UUID for multi-system identity

  field_properties:
    type: "Text"
    length: 80                   # Accommodate UUIDs (36 chars) with room
    unique: true                 # REQUIRED for upsert operations
    externalId: true             # REQUIRED: marks field as external ID
    caseSensitive: false         # Usually false for usability

  rules:
    - "One external ID field per source system per object"
    - "Never reuse Salesforce IDs as external IDs (they are org-specific)"
    - "Use UUIDs if no natural key exists in the source system"
    - "Make the field unique to prevent duplicate imports"
    - "Never modify external ID values after initial load"
```

**DataWeave: Cross-Reference ID Mapping**

```dw
%dw 2.0
output application/json

// Source data from legacy system
var sourceAccounts = [
    {legacyId: "ACC-001", name: "Acme Corp", industry: "Technology"},
    {legacyId: "ACC-002", name: "Globex Inc", industry: "Manufacturing"}
]

var sourceContacts = [
    {legacyId: "CON-001", firstName: "John", lastName: "Doe",
     email: "john@acme.com", accountLegacyId: "ACC-001"},
    {legacyId: "CON-002", firstName: "Jane", lastName: "Smith",
     email: "jane@globex.com", accountLegacyId: "ACC-002"},
    {legacyId: "CON-003", firstName: "Bob", lastName: "Wilson",
     email: "bob@acme.com", accountLegacyId: "ACC-001"}
]

// Transform accounts for Salesforce upsert
var sfAccounts = sourceAccounts map (acct) -> {
    Legacy_CRM_Id__c: acct.legacyId,     // External ID for upsert
    Name: acct.name,
    Industry: acct.industry
}

// Transform contacts with external ID relationship reference
// Instead of AccountId (which requires knowing the SF ID),
// use Account.Legacy_CRM_Id__c (which resolves automatically)
var sfContacts = sourceContacts map (contact) -> {
    Legacy_CRM_Id__c: contact.legacyId,
    FirstName: contact.firstName,
    LastName: contact.lastName,
    Email: contact.email,
    // This is the key pattern: reference parent by external ID
    "Account.Legacy_CRM_Id__c": contact.accountLegacyId
}
---
{
    accounts: sfAccounts,
    contacts: sfContacts,
    migrationMetadata: {
        sourceSystem: "LegacyCRM",
        externalIdField: "Legacy_CRM_Id__c",
        accountCount: sizeOf(sfAccounts),
        contactCount: sizeOf(sfContacts),
        // Relationship mapping via external ID means:
        // 1. No need to know Salesforce IDs in advance
        // 2. Accounts and contacts can be loaded in ANY order
        //    (as long as accounts exist when contacts are loaded)
        // 3. Re-running the migration is safe (upsert = idempotent)
        note: "Contacts reference accounts via external ID, not Salesforce ID"
    }
}
```

**Migration Flow with External ID Upserts**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:db="http://www.mulesoft.org/schema/mule/db"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Cross-reference store: maps source IDs to Salesforce IDs -->
    <os:object-store name="crossRefStore"
                     persistent="true"
                     entryTtl="30"
                     entryTtlUnit="DAYS"/>

    <!-- Phase 1: Load parent records (Accounts) -->
    <flow name="migration-phase1-accounts">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/migration/accounts"
                       method="POST"/>

        <!-- Fetch source accounts -->
        <db:select config-ref="Legacy_DB_Config">
            <db:sql>
                SELECT legacy_id, company_name, industry, billing_city,
                       billing_state, billing_country
                FROM legacy_accounts
                WHERE migration_status = 'PENDING'
                ORDER BY legacy_id
            </db:sql>
        </db:select>

        <set-variable variableName="sourceRecordCount" value="#[sizeOf(payload)]"/>

        <!-- Transform to Salesforce format with external ID -->
        <ee:transform doc:name="Map to SF Account Format">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (record) -> {
    // External ID field enables upsert (insert or update)
    Legacy_CRM_Id__c: record.legacy_id,
    Name: record.company_name,
    Industry: record.industry,
    BillingCity: record.billing_city,
    BillingState: record.billing_state,
    BillingCountry: record.billing_country
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Upsert: creates new records or updates existing ones
             based on Legacy_CRM_Id__c match -->
        <salesforce:upsert config-ref="Salesforce_Config"
                           objectType="Account"
                           externalIdFieldName="Legacy_CRM_Id__c">
            <salesforce:records>#[payload]</salesforce:records>
        </salesforce:upsert>

        <!-- Build cross-reference map from results -->
        <ee:transform doc:name="Build Cross-Reference Map">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var results = payload
var successCount = sizeOf(results filter $.success == true)
var failCount = sizeOf(results filter $.success == false)
---
{
    phase: "ACCOUNTS",
    totalProcessed: sizeOf(results),
    successCount: successCount,
    failCount: failCount,
    crossReference: (results filter $.success == true) map (r) -> {
        externalId: r.externalId,
        salesforceId: r.id,
        created: r.created
    },
    failures: (results filter $.success == false) map (r) -> {
        externalId: r.externalId,
        errors: r.errors
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Store cross-reference for Phase 2 -->
        <foreach collection="#[payload.crossReference]">
            <os:store key="#['xref-Account-' ++ payload.externalId]"
                      objectStore="crossRefStore">
                <os:value>#[payload.salesforceId]</os:value>
            </os:store>
        </foreach>

        <logger level="INFO"
                message='Phase 1 complete: #[payload.successCount] accounts loaded, #[payload.failCount] failed'/>
    </flow>

    <!-- Phase 2: Load child records (Contacts) using external ID references -->
    <flow name="migration-phase2-contacts">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/migration/contacts"
                       method="POST"/>

        <db:select config-ref="Legacy_DB_Config">
            <db:sql>
                SELECT c.legacy_id, c.first_name, c.last_name, c.email,
                       c.phone, c.account_legacy_id
                FROM legacy_contacts c
                JOIN legacy_accounts a ON c.account_legacy_id = a.legacy_id
                WHERE c.migration_status = 'PENDING'
                ORDER BY c.legacy_id
            </db:sql>
        </db:select>

        <!-- Transform contacts: use external ID reference for Account -->
        <ee:transform doc:name="Map to SF Contact Format">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (record) -> {
    // Contact's own external ID
    Legacy_CRM_Id__c: record.legacy_id,
    FirstName: record.first_name,
    LastName: record.last_name,
    Email: record.email,
    Phone: record.phone,
    // Reference parent Account by its external ID
    // Salesforce resolves this to the actual AccountId automatically
    "Account": {
        "Legacy_CRM_Id__c": record.account_legacy_id
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <salesforce:upsert config-ref="Salesforce_Config"
                           objectType="Contact"
                           externalIdFieldName="Legacy_CRM_Id__c">
            <salesforce:records>#[payload]</salesforce:records>
        </salesforce:upsert>

        <!-- Build results summary -->
        <ee:transform doc:name="Contact Load Results">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
var results = payload
---
{
    phase: "CONTACTS",
    totalProcessed: sizeOf(results),
    successCount: sizeOf(results filter $.success == true),
    failCount: sizeOf(results filter $.success == false),
    failures: (results filter $.success == false) map (r) -> {
        externalId: r.externalId,
        errors: r.errors
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <logger level="INFO"
                message='Phase 2 complete: #[payload.successCount] contacts loaded, #[payload.failCount] failed'/>

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                        message='Contact migration failed: #[error.description]'/>
            </on-error-propagate>
        </error-handler>
    </flow>

    <!-- Utility: Verify cross-references post-migration -->
    <flow name="verify-cross-references">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/migration/verify"
                       method="GET"/>

        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>
                SELECT Id, Legacy_CRM_Id__c, Name,
                    (SELECT Id, Legacy_CRM_Id__c, Name FROM Contacts)
                FROM Account
                WHERE Legacy_CRM_Id__c != null
                ORDER BY Legacy_CRM_Id__c
            </salesforce:salesforce-query>
        </salesforce:query>

        <ee:transform doc:name="Build Verification Report">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    verificationReport: {
        totalAccounts: sizeOf(payload),
        accountsWithContacts: sizeOf(payload filter
            sizeOf($.Contacts default []) > 0),
        orphanedAccounts: sizeOf(payload filter
            sizeOf($.Contacts default []) == 0),
        totalContacts: sum(payload map sizeOf($.Contacts default [])),
        details: payload map (acct) -> {
            accountId: acct.Id,
            externalId: acct.Legacy_CRM_Id__c,
            name: acct.Name,
            contactCount: sizeOf(acct.Contacts default [])
        }
    },
    verifiedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

## How It Works

1. **External ID field creation**: A custom text field marked as `External ID` and `Unique` is created on each Salesforce object. This field holds the source system's identifier.
2. **Upsert operations**: Instead of insert, the migration uses upsert with the external ID field. If a record with that external ID exists, it is updated; otherwise, it is created. This makes the migration idempotent.
3. **Relationship resolution by external ID**: Child records reference their parent using the parent's external ID instead of the Salesforce ID. The syntax `"Account.Legacy_CRM_Id__c": "ACC-001"` tells Salesforce to resolve the AccountId automatically.
4. **Cross-reference persistence**: After the parent upsert completes, a cross-reference map (external ID to Salesforce ID) is stored in an Object Store for any downstream process that needs Salesforce IDs.
5. **Verification**: A post-migration verification flow queries Salesforce to confirm parent-child relationships were created correctly and identifies orphaned records.

## Key Takeaways

- Always create external ID fields before starting any migration. Retrofitting external IDs onto records that have already been migrated without them is significantly harder.
- Use the relationship external ID reference syntax (`"Account.Legacy_CRM_Id__c"`) to avoid the parent-child sequencing problem entirely. Salesforce resolves the relationship server-side.
- Make external ID fields unique to prevent duplicate imports. Without uniqueness, a re-run of the migration creates duplicate records instead of updating existing ones.
- Never use Salesforce IDs as external IDs. They are org-specific, so a record with `Id = 001xxx` in production will have a different `Id` in sandbox.
- Build a verification step that checks relationship integrity post-migration. Broken relationships are the most common migration defect and the hardest to detect without explicit checks.

## Related Recipes

- [Data Migration Strategies](../data-migration-strategies/)
- [Bulk API v2 Job Orchestrator](../bulk-api-v2-job-orchestrator/)
- [Bulk API 2.0 Partial Failure Recovery](../bulk-api-2-partial-failure/)
- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
