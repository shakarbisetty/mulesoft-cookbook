# Bulk API v2 Job Orchestrator

## Problem

Loading parent-child data into Salesforce (e.g., Accounts with their Contacts) via Bulk API v2 requires strict sequencing: parent records must be fully committed before child records can reference their Salesforce IDs. If you submit both jobs simultaneously, child records fail because the parent IDs do not exist yet. Manually orchestrating this --- polling for job completion, extracting generated IDs, mapping them to child records --- is error-prone and often leads to orphaned child records or partial loads.

## Solution

Build a parent-child job orchestration flow in MuleSoft that submits the parent Bulk API v2 job first, polls for completion, retrieves successful results to extract Salesforce-generated IDs, maps those IDs onto child records using an external ID cross-reference, and then submits the child job. Full error handling ensures failed parent records do not produce orphaned children.

## Implementation

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:doc="http://www.mulesoft.org/schema/mule/documentation"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Object Store for job tracking -->
    <os:object-store name="bulkJobStore"
                     persistent="true"
                     entryTtl="24"
                     entryTtlUnit="HOURS"/>

    <!-- Main orchestration flow -->
    <flow name="parent-child-bulk-orchestrator">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/bulk-load"
                       method="POST"/>

        <!-- Step 1: Split incoming payload into parent and child records -->
        <ee:transform doc:name="Separate Parent and Child Records">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    parents: payload.accounts map (acct) -> {
        Name: acct.name,
        Industry: acct.industry,
        BillingCity: acct.billingCity,
        External_Id__c: acct.sourceId
    },
    children: payload.accounts flatMap (acct) ->
        (acct.contacts default []) map (contact) -> {
            FirstName: contact.firstName,
            LastName: contact.lastName,
            Email: contact.email,
            "Account.External_Id__c": acct.sourceId
        },
    metadata: {
        totalParents: sizeOf(payload.accounts),
        totalChildren: sizeOf(payload.accounts flatMap (a) -> a.contacts default []),
        submittedAt: now()
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="childRecords" value="#[payload.children]"/>
        <set-variable variableName="loadMetadata" value="#[payload.metadata]"/>
        <set-payload value="#[payload.parents]"/>

        <!-- Step 2: Submit parent Bulk API v2 job -->
        <salesforce:create-job config-ref="Salesforce_Config"
                               doc:name="Create Parent Job">
            <salesforce:create-job-request>
                <salesforce:job-info
                    object="Account"
                    operation="upsert"
                    externalIdFieldName="External_Id__c"
                    contentType="CSV"
                    lineEnding="LF"/>
            </salesforce:create-job-request>
        </salesforce:create-job>

        <set-variable variableName="parentJobId" value="#[payload.id]"/>
        <logger level="INFO"
                message='Parent job created: #[vars.parentJobId] for #[vars.loadMetadata.totalParents] accounts'/>

        <!-- Upload parent CSV data -->
        <ee:transform doc:name="Convert Parents to CSV">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/csv
---
payload
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <salesforce:create-batch config-ref="Salesforce_Config"
                                 jobId="#[vars.parentJobId]">
            <salesforce:content>#[payload]</salesforce:content>
        </salesforce:create-batch>

        <!-- Close job to start processing -->
        <salesforce:close-job config-ref="Salesforce_Config"
                              jobId="#[vars.parentJobId]"/>

        <!-- Step 3: Poll for parent job completion -->
        <flow-ref name="poll-job-completion" doc:name="Wait for Parent Job"/>

        <!-- Step 4: Retrieve successful results to get SF IDs -->
        <salesforce:get-job-result config-ref="Salesforce_Config"
                                   jobId="#[vars.parentJobId]"
                                   resultType="successfulResults"/>

        <ee:transform doc:name="Build External-to-SF ID Map">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

// Build a lookup from External_Id__c to Salesforce Id
var idMap = payload reduce ((item, acc = {}) ->
    acc ++ {(item.External_Id__c): item.sf__Id}
)
---
{
    idMap: idMap,
    successCount: sizeOf(payload),
    parentJobId: vars.parentJobId
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="parentIdMap" value="#[payload.idMap]"/>

        <!-- Step 5: Check for parent failures before proceeding -->
        <salesforce:get-job-result config-ref="Salesforce_Config"
                                   jobId="#[vars.parentJobId]"
                                   resultType="failedResults"
                                   target="parentFailures"/>

        <choice doc:name="Check Parent Failures">
            <when expression="#[sizeOf(vars.parentFailures default []) > 0]">
                <logger level="WARN"
                        message='#[sizeOf(vars.parentFailures)] parent records failed. Filtering orphaned children.'/>
                <!-- Remove children whose parent failed -->
                <ee:transform doc:name="Filter Orphaned Children">
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
var failedExternalIds = (vars.parentFailures default [])
    map (f) -> f.External_Id__c
---
vars.childRecords filter (child) ->
    not (failedExternalIds contains child."Account.External_Id__c")
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </when>
            <otherwise>
                <set-payload value="#[vars.childRecords]"/>
            </otherwise>
        </choice>

        <!-- Step 6: Submit child Bulk API v2 job -->
        <choice doc:name="Submit Children If Any">
            <when expression="#[sizeOf(payload) > 0]">
                <salesforce:create-job config-ref="Salesforce_Config"
                                       doc:name="Create Child Job">
                    <salesforce:create-job-request>
                        <salesforce:job-info
                            object="Contact"
                            operation="insert"
                            contentType="CSV"
                            lineEnding="LF"/>
                    </salesforce:create-job-request>
                </salesforce:create-job>

                <set-variable variableName="childJobId" value="#[payload.id]"/>

                <ee:transform doc:name="Convert Children to CSV">
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/csv
---
vars.childRecords map (c) -> {
    FirstName: c.FirstName,
    LastName: c.LastName,
    Email: c.Email,
    AccountId: vars.parentIdMap[c."Account.External_Id__c"]
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <salesforce:create-batch config-ref="Salesforce_Config"
                                         jobId="#[vars.childJobId]">
                    <salesforce:content>#[payload]</salesforce:content>
                </salesforce:create-batch>

                <salesforce:close-job config-ref="Salesforce_Config"
                                      jobId="#[vars.childJobId]"/>

                <flow-ref name="poll-job-completion" doc:name="Wait for Child Job"/>
            </when>
        </choice>

        <!-- Final response -->
        <ee:transform doc:name="Build Orchestration Summary">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "COMPLETED",
    parentJob: vars.parentJobId,
    childJob: vars.childJobId default "SKIPPED",
    parentSuccessCount: sizeOf(keysOf(vars.parentIdMap)),
    parentFailureCount: sizeOf(vars.parentFailures default []),
    childRecordsSubmitted: sizeOf(vars.childRecords),
    completedAt: now()
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <error-handler>
            <on-error-propagate type="ANY">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "FAILED",
    parentJob: vars.parentJobId default "NOT_CREATED",
    childJob: vars.childJobId default "NOT_CREATED",
    error: error.description,
    failedAt: now()
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </flow>

    <!-- Reusable polling sub-flow -->
    <sub-flow name="poll-job-completion">
        <set-variable variableName="jobComplete" value="#[false]"/>
        <set-variable variableName="pollAttempts" value="#[0]"/>

        <until-successful maxRetries="60"
                          millisBetweenRetries="10000">
            <salesforce:get-job-info config-ref="Salesforce_Config"
                                     jobId="#[vars.parentJobId]"/>

            <choice>
                <when expression="#[payload.state == 'JobComplete']">
                    <logger level="INFO"
                            message='Job #[payload.id] completed. Processed: #[payload.numberRecordsProcessed], Failed: #[payload.numberRecordsFailed]'/>
                </when>
                <when expression="#[payload.state == 'Failed' or payload.state == 'Aborted']">
                    <raise-error type="APP:BULK_JOB_FAILED"
                                 description='Bulk job #[payload.id] ended with state: #[payload.state]'/>
                </when>
                <otherwise>
                    <raise-error type="MULE:RETRY_EXHAUSTED"
                                 description="Job still processing, will retry"/>
                </otherwise>
            </choice>
        </until-successful>
    </sub-flow>
</mule>
```

## How It Works

1. **Payload separation**: The incoming request is split into parent (Account) and child (Contact) record sets. Each child record references its parent via `External_Id__c`.
2. **Parent job submission**: Accounts are submitted as a Bulk API v2 upsert job using the external ID. The job is closed to trigger processing.
3. **Polling for completion**: An `until-successful` block polls the job status every 10 seconds for up to 10 minutes, checking for `JobComplete`, `Failed`, or `Aborted` states.
4. **ID extraction**: Once the parent job completes, successful results are retrieved and a DataWeave lookup map is built from `External_Id__c` to the Salesforce-generated `Id`.
5. **Orphan prevention**: If any parent records failed, the corresponding child records are filtered out to prevent orphaned children.
6. **Child job submission**: Remaining child records are enriched with the actual Salesforce `AccountId` from the lookup map and submitted as a second Bulk API v2 job.

## Key Takeaways

- Always use external IDs for parent-child mapping --- they survive across environments and make the orchestration idempotent.
- Filter out children of failed parents before submitting the child job to prevent `INVALID_CROSS_REFERENCE_KEY` errors.
- Set polling intervals to at least 10 seconds; more frequent polling wastes API calls and does not speed up processing.
- For three-level hierarchies (e.g., Account > Opportunity > OpportunityLineItem), chain this pattern with an additional stage.
- Store orchestration state in an Object Store so the flow can resume from the correct step if the Mule worker restarts mid-job.

## Related Recipes

- [Bulk API 2.0 Partial Failure Recovery](../bulk-api-2-partial-failure/)
- [Bulk API v2 Chunk Calculator](../bulk-api-v2-chunk-calculator/)
- [SF External ID Strategy](../sf-external-id-strategy/)
- [Data Migration Strategies](../data-migration-strategies/)
