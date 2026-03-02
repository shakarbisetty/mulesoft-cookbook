# FLS-Aware Salesforce Integration Patterns

## Problem

Salesforce Field-Level Security (FLS) and CRUD permissions control which fields and objects a user can access. Integration users are often provisioned with a "System Administrator" profile during development, masking permission gaps that surface in production when a restricted profile is used. The result is silent data loss: a MuleSoft integration writes 15 fields to an Account record, but the integration user only has write access to 12 of them. Salesforce silently ignores the 3 restricted fields without returning an error. The integration reports success, but 20% of the data was never persisted. This phantom data loss is extremely difficult to detect and diagnose.

## Solution

Implement pre-flight permission checks using the Salesforce `/describe` API, build a FLS validation layer that detects and reports permission gaps before data operations, handle partial field access gracefully with clear logging, and provide an audit mechanism that periodically verifies integration user permissions against the expected field list.

## Implementation

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Expected fields per object (what the integration needs) -->
    <global-property name="fls.required.Account"
        value="Name,Industry,BillingCity,BillingState,BillingCountry,Phone,Website,Status__c,External_Id__c"/>
    <global-property name="fls.required.Contact"
        value="FirstName,LastName,Email,Phone,MailingCity,AccountId,External_Id__c"/>

    <!-- Permission cache (refresh daily) -->
    <os:object-store name="permissionCacheStore"
                     persistent="true"
                     entryTtl="24"
                     entryTtlUnit="HOURS"/>

    <!-- Sub-flow: Pre-flight FLS Check -->
    <sub-flow name="preflight-fls-check">
        <!-- Query object describe for field-level permissions -->
        <http:request method="GET"
                      config-ref="Salesforce_REST_Config"
                      path="/services/data/v59.0/sobjects/#[vars.targetObject]/describe">
            <http:headers>
                #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
            </http:headers>
        </http:request>

        <ee:transform doc:name="Analyze Field Permissions">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var objectDescribe = payload
var objectName = vars.targetObject
var operation = vars.operationType default "update"

// Get required fields from config
var requiredFieldsStr = Mule::p('fls.required.' ++ objectName) default ""
var requiredFields = if (isEmpty(requiredFieldsStr)) []
                     else requiredFieldsStr splitBy ","

// Build field permission map from describe result
var fieldPermissions = objectDescribe.fields reduce ((field, acc = {}) ->
    acc ++ {
        (field.name): {
            readable: field.filterable default false,
            createable: field.createable default false,
            updateable: field.updateable default false,
            name: field.name,
            label: field.label,
            type: field.type
        }
    }
)

// Check each required field against actual permissions
var permissionCheck = requiredFields map (fieldName) -> do {
    var perm = fieldPermissions[fieldName]
    var exists = perm != null
    var hasAccess = if (!exists) false
                   else if (operation == "create") perm.createable
                   else if (operation == "update") perm.updateable
                   else if (operation == "read") perm.readable
                   else false
    ---
    {
        field: fieldName,
        exists: exists,
        hasAccess: hasAccess,
        permission: if (!exists) "FIELD_NOT_FOUND"
                    else if (hasAccess) "GRANTED"
                    else "DENIED",
        details: if (!exists) "Field does not exist on " ++ objectName
                 else if (!hasAccess) "Integration user lacks " ++ operation ++ " permission"
                 else "OK"
    }
}

var grantedFields = permissionCheck filter ($.permission == "GRANTED")
var deniedFields = permissionCheck filter ($.permission == "DENIED")
var missingFields = permissionCheck filter ($.permission == "FIELD_NOT_FOUND")
var allClear = sizeOf(deniedFields) == 0 and sizeOf(missingFields) == 0
---
{
    object: objectName,
    operation: operation,
    allClear: allClear,
    summary: {
        totalRequired: sizeOf(requiredFields),
        granted: sizeOf(grantedFields),
        denied: sizeOf(deniedFields),
        missing: sizeOf(missingFields)
    },
    grantedFields: grantedFields map $.field,
    deniedFields: deniedFields,
    missingFields: missingFields,
    recommendation: if (allClear) "All permissions verified. Safe to proceed."
                    else if (sizeOf(missingFields) > 0)
                        "Fields not found: " ++ (missingFields map $.field joinBy ", ") ++
                        ". Check if fields are deployed to this org."
                    else "Permission gaps detected for: " ++
                        (deniedFields map $.field joinBy ", ") ++
                        ". Update integration user profile/permission set."
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Cache the permission check result -->
        <os:store key="#['fls-' ++ vars.targetObject ++ '-' ++ (vars.operationType default 'update')]"
                  objectStore="permissionCacheStore">
            <os:value>#[payload]</os:value>
        </os:store>
    </sub-flow>

    <!-- FLS-Aware Data Write Flow -->
    <flow name="fls-aware-sf-write">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/salesforce/write"
                       method="POST"/>

        <set-variable variableName="targetObject"
                      value="#[payload.objectType]"/>
        <set-variable variableName="operationType"
                      value="#[payload.operation default 'update']"/>
        <set-variable variableName="records" value="#[payload.records]"/>

        <!-- Check cached permissions first -->
        <os:retrieve key="#['fls-' ++ vars.targetObject ++ '-' ++ vars.operationType]"
                     objectStore="permissionCacheStore"
                     target="cachedPermissions">
            <os:default-value>#[null]</os:default-value>
        </os:retrieve>

        <!-- If no cache, run preflight check -->
        <choice>
            <when expression="#[vars.cachedPermissions == null]">
                <flow-ref name="preflight-fls-check"/>
                <set-variable variableName="permissionResult" value="#[payload]"/>
            </when>
            <otherwise>
                <set-variable variableName="permissionResult"
                              value="#[vars.cachedPermissions]"/>
            </otherwise>
        </choice>

        <!-- Decision: proceed, filter, or block -->
        <choice doc:name="FLS Decision">
            <!-- All clear: proceed with all fields -->
            <when expression="#[vars.permissionResult.allClear == true]">
                <logger level="INFO"
                        message='FLS check passed for #[vars.targetObject]. Proceeding with all fields.'/>
                <set-payload value="#[vars.records]"/>
                <flow-ref name="execute-sf-write"/>
            </when>

            <!-- Partial access: filter to accessible fields only -->
            <when expression="#[sizeOf(vars.permissionResult.deniedFields) > 0
                              and sizeOf(vars.permissionResult.grantedFields) > 0]">
                <logger level="WARN"
                        message='FLS partial access for #[vars.targetObject]. Denied fields: #[vars.permissionResult.deniedFields map $.field]. Writing accessible fields only.'/>

                <!-- Strip inaccessible fields from payload -->
                <ee:transform doc:name="Filter to Accessible Fields">
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var allowedFields = vars.permissionResult.grantedFields
---
vars.records map (record) ->
    record filterObject ((value, key) ->
        allowedFields contains (key as String)
        or key as String == "Id"
        or key as String == "External_Id__c"
    )
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <flow-ref name="execute-sf-write"/>

                <!-- Log what was dropped for audit trail -->
                <logger level="WARN"
                        message='FLS AUDIT: Dropped fields #[vars.permissionResult.deniedFields map $.field] from #[sizeOf(vars.records)] #[vars.targetObject] records due to FLS restrictions.'/>
            </when>

            <!-- No access at all: block the operation -->
            <otherwise>
                <logger level="ERROR"
                        message='FLS check FAILED for #[vars.targetObject]. No writable fields found.'/>
                <raise-error type="APP:FLS_VIOLATION"
                             description="Integration user has no write access to any required field on #[vars.targetObject]"/>
            </otherwise>
        </choice>
    </flow>

    <!-- Scheduled FLS Audit (runs daily) -->
    <flow name="fls-daily-audit">
        <scheduler>
            <scheduling-strategy>
                <cron expression="0 0 6 * * ?"/>  <!-- 6 AM daily -->
            </scheduling-strategy>
        </scheduler>

        <set-variable variableName="auditResults" value="#[[] as Array]"/>

        <!-- Audit each configured object -->
        <foreach collection="#[['Account', 'Contact', 'Opportunity', 'Case']]">
            <set-variable variableName="targetObject" value="#[payload]"/>
            <set-variable variableName="operationType" value="update"/>

            <try>
                <flow-ref name="preflight-fls-check"/>

                <choice>
                    <when expression="#[payload.allClear == false]">
                        <logger level="WARN"
                                message='FLS audit failed for #[payload.object]: #[payload.summary.denied] denied, #[payload.summary.missing] missing'/>
                    </when>
                </choice>

                <error-handler>
                    <on-error-continue type="ANY">
                        <logger level="ERROR"
                                message='FLS audit error for #[vars.targetObject]: #[error.description]'/>
                    </on-error-continue>
                </error-handler>
            </try>
        </foreach>

        <logger level="INFO" message="Daily FLS audit complete."/>
    </flow>

    <!-- Sub-flow: Execute the actual Salesforce write -->
    <sub-flow name="execute-sf-write">
        <choice>
            <when expression="#[vars.operationType == 'create']">
                <salesforce:create config-ref="Salesforce_Config"
                                   type="#[vars.targetObject]">
                    <salesforce:records>#[payload]</salesforce:records>
                </salesforce:create>
            </when>
            <when expression="#[vars.operationType == 'upsert']">
                <salesforce:upsert config-ref="Salesforce_Config"
                                   objectType="#[vars.targetObject]"
                                   externalIdFieldName="External_Id__c">
                    <salesforce:records>#[payload]</salesforce:records>
                </salesforce:upsert>
            </when>
            <otherwise>
                <salesforce:update config-ref="Salesforce_Config"
                                   type="#[vars.targetObject]">
                    <salesforce:records>#[payload]</salesforce:records>
                </salesforce:update>
            </otherwise>
        </choice>
    </sub-flow>
</mule>
```

## How It Works

1. **Describe API query**: The pre-flight check calls `/sobjects/{Object}/describe` to retrieve the full field metadata for the target object, including `createable`, `updateable`, and `filterable` flags for each field.
2. **Permission analysis**: DataWeave compares each required field (from configuration) against the describe response. Fields are classified as GRANTED (accessible), DENIED (exists but no permission), or FIELD_NOT_FOUND (does not exist in this org).
3. **Graceful degradation**: If some fields are denied, the payload is filtered to include only accessible fields plus identity fields (Id, External_Id__c). The operation proceeds with partial data rather than failing entirely. Dropped fields are logged for audit.
4. **Permission caching**: Describe results are cached for 24 hours in a persistent Object Store to avoid making a describe call before every operation.
5. **Daily audit**: A scheduled flow checks permissions for all configured objects every morning and logs any gaps. This catches permission changes made by Salesforce admins before they cause data loss in production.

## Key Takeaways

- Salesforce silently drops fields that the running user cannot write. There is no error, no warning, and no indication in the API response that data was lost. Pre-flight checks are the only way to detect this.
- Always test integrations with the actual integration user profile, never with System Administrator. Permission gaps are invisible with admin profiles.
- Cache describe results (they change rarely) but refresh them daily. Permission set assignments and profile changes take effect immediately in Salesforce but your cache will be stale.
- Log every field that is filtered out due to FLS restrictions. This audit trail is essential for diagnosing "missing data" reports from business users.
- Create a dedicated Permission Set for the integration user that grants exactly the fields needed by the integration. Using broad profiles leads to security review failures.

## Related Recipes

- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
- [SF External ID Strategy](../sf-external-id-strategy/)
- [SF Invalid Session Recovery](../sf-invalid-session-recovery/)
- [Data Migration Strategies](../data-migration-strategies/)
