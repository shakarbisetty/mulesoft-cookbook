# Automated Reconnection After Salesforce Sandbox Refresh

## Problem

When a Salesforce sandbox is refreshed, it copies production metadata and data into a clean environment, destroying all existing OAuth tokens, Connected App client secrets (unless the Connected App is packaged), session state, and sometimes custom objects. MuleSoft integrations pointing to the refreshed sandbox immediately fail with `INVALID_SESSION_ID` or `INVALID_CLIENT_ID` errors. Teams often do not realize the sandbox was refreshed until their CI/CD pipelines or scheduled integrations start failing, and manual remediation takes hours of coordination between the MuleSoft and Salesforce teams.

## Solution

Build a sandbox refresh detection and recovery system that monitors for refresh indicators, automatically invalidates stale connections, notifies the operations team with a specific remediation runbook, and (where possible) executes automated re-authentication. Include a pre-refresh checklist that minimizes downtime when refreshes are planned.

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

    <!-- Sandbox connection properties -->
    <global-property name="sf.sandbox.loginUrl"
                     value="https://test.salesforce.com"/>
    <global-property name="sf.sandbox.expectedOrgId"
                     value="${sf.sandbox.org.id}"/>

    <!-- Health tracking -->
    <os:object-store name="sandboxHealthStore"
                     persistent="true"
                     entryTtl="24"
                     entryTtlUnit="HOURS"/>

    <!-- Scheduled sandbox health check (runs every 30 minutes) -->
    <flow name="sandbox-health-monitor">
        <scheduler>
            <scheduling-strategy>
                <fixed-frequency frequency="30" timeUnit="MINUTES"/>
            </scheduling-strategy>
        </scheduler>

        <try>
            <!-- Step 1: Attempt a lightweight API call -->
            <http:request method="GET"
                          config-ref="SF_Sandbox_REST_Config"
                          path="/services/data/v59.0/limits">
                <http:headers>
                    #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
                </http:headers>
                <http:response-validator>
                    <http:success-status-code-validator values="200"/>
                </http:response-validator>
            </http:request>

            <!-- Step 2: Verify org identity (detect if org ID changed) -->
            <http:request method="GET"
                          config-ref="SF_Sandbox_REST_Config"
                          path="/services/data/v59.0/query">
                <http:query-params>
                    #[{'q': 'SELECT Id, Name, OrganizationType FROM Organization'}]
                </http:query-params>
                <http:headers>
                    #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
                </http:headers>
            </http:request>

            <ee:transform doc:name="Validate Org Identity">
                <ee:message>
                    <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var currentOrgId = payload.records[0].Id
var expectedOrgId = Mule::p('sf.sandbox.expectedOrgId')
var orgIdMatch = currentOrgId == expectedOrgId
---
{
    status: "HEALTHY",
    currentOrgId: currentOrgId,
    expectedOrgId: expectedOrgId,
    orgIdMatch: orgIdMatch,
    orgName: payload.records[0].Name,
    orgType: payload.records[0].OrganizationType,
    checkedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    warning: if (!orgIdMatch)
        "Org ID mismatch detected. Sandbox may have been refreshed from a different source."
        else null
}
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <os:store key="sandboxHealth"
                      objectStore="sandboxHealthStore">
                <os:value>#[payload]</os:value>
            </os:store>

            <!-- Alert on org ID mismatch (partial refresh indicator) -->
            <choice>
                <when expression="#[payload.orgIdMatch == false]">
                    <logger level="WARN"
                            message='Sandbox org ID mismatch: expected #[payload.expectedOrgId], got #[payload.currentOrgId]'/>
                    <flow-ref name="send-sandbox-alert">
                        <properties>
                            <property name="alertType" value="ORG_ID_MISMATCH"/>
                        </properties>
                    </flow-ref>
                </when>
            </choice>

            <error-handler>
                <!-- Authentication failure: likely sandbox refresh -->
                <on-error-continue type="HTTP:UNAUTHORIZED OR SALESFORCE:INVALID_SESSION">
                    <logger level="ERROR"
                            message="Sandbox authentication failed. Possible sandbox refresh detected."/>

                    <ee:transform doc:name="Build Refresh Detection Report">
                        <ee:message>
                            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "REFRESH_DETECTED",
    detectedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    errorType: error.errorType.identifier,
    errorMessage: error.description,
    impactAssessment: {
        affectedFlows: [
            "sandbox-data-sync",
            "sandbox-test-automation",
            "sandbox-cdc-subscriber"
        ],
        estimatedDowntime: "30-60 minutes (manual steps required)",
        severity: "HIGH"
    },
    remediationSteps: [
        "1. Verify sandbox refresh completed in Salesforce Setup",
        "2. Log into refreshed sandbox and verify Connected App exists",
        "3. If Connected App missing: recreate with same Consumer Key or deploy from package",
        "4. Reset Consumer Secret in Connected App settings",
        "5. Update sf.sandbox.clientSecret in Anypoint Secrets Manager",
        "6. Update sf.sandbox.org.id property if org ID changed",
        "7. Restart MuleSoft application to pick up new credentials",
        "8. Run sandbox health check to verify connectivity"
    ],
    automatedActions: [
        "Invalidated cached Salesforce connection",
        "Stopped sandbox CDC subscriber to prevent error floods",
        "Sent alert to operations team"
    ]
}
                            ]]></ee:set-payload>
                        </ee:message>
                    </ee:transform>

                    <!-- Store the detection report -->
                    <os:store key="sandboxHealth"
                              objectStore="sandboxHealthStore">
                        <os:value>#[payload]</os:value>
                    </os:store>

                    <!-- Invalidate the stale connection -->
                    <salesforce:invalidate-connection
                        config-ref="SF_Sandbox_Config"/>

                    <!-- Stop CDC subscriber to prevent error flooding -->
                    <flow-ref name="stop-sandbox-dependent-flows"/>

                    <!-- Send detailed alert -->
                    <flow-ref name="send-sandbox-refresh-alert"/>
                </on-error-continue>

                <!-- Network/connectivity error (different from refresh) -->
                <on-error-continue type="HTTP:CONNECTIVITY OR HTTP:TIMEOUT">
                    <logger level="WARN"
                            message="Sandbox connectivity issue (not necessarily a refresh): #[error.description]"/>

                    <os:store key="sandboxHealth"
                              objectStore="sandboxHealthStore">
                        <os:value>#[{
                            status: "CONNECTIVITY_ISSUE",
                            error: error.description,
                            checkedAt: now()
                        }]</os:value>
                    </os:store>
                </on-error-continue>
            </error-handler>
        </try>
    </flow>

    <!-- Stop dependent flows to prevent error cascades -->
    <sub-flow name="stop-sandbox-dependent-flows">
        <logger level="WARN"
                message="Stopping sandbox-dependent flows to prevent error cascades."/>
        <!-- In practice, you would use the Mule Runtime Manager API
             or a flow control mechanism to pause these flows -->
        <os:store key="sandboxFlowsEnabled"
                  objectStore="sandboxHealthStore">
            <os:value>#[false]</os:value>
        </os:store>
    </sub-flow>

    <!-- Alert with full remediation runbook -->
    <sub-flow name="send-sandbox-refresh-alert">
        <ee:transform doc:name="Format Alert">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    channel: "ops-alerts",
    severity: "HIGH",
    title: "Salesforce Sandbox Refresh Detected",
    message: "The Salesforce sandbox connection has failed, likely due to a sandbox refresh. " ++
             "All sandbox-dependent integrations have been paused. " ++
             "Manual remediation is required.",
    environment: Mule::p('mule.env') default "sandbox",
    detectedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    runbook: "https://wiki.internal/runbooks/salesforce-sandbox-refresh",
    quickSteps: [
        "Check if sandbox refresh was scheduled",
        "Verify Connected App in refreshed sandbox",
        "Update client secret in Secrets Manager",
        "Restart MuleSoft app"
    ]
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <http:request method="POST"
                      config-ref="Alerts_HTTP_Config"
                      path="/api/alerts">
            <http:body>#[payload]</http:body>
        </http:request>
    </sub-flow>

    <!-- Manual re-verification endpoint (called after remediation) -->
    <flow name="sandbox-reconnect-verify">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/admin/sandbox/verify"
                       method="POST"/>

        <!-- Force re-authentication -->
        <salesforce:invalidate-connection config-ref="SF_Sandbox_Config"/>

        <!-- Test the connection with a simple query -->
        <try>
            <salesforce:query config-ref="SF_Sandbox_Config">
                <salesforce:salesforce-query>
                    SELECT Id FROM Organization LIMIT 1
                </salesforce:salesforce-query>
            </salesforce:query>

            <!-- Re-enable dependent flows -->
            <os:store key="sandboxFlowsEnabled"
                      objectStore="sandboxHealthStore">
                <os:value>#[true]</os:value>
            </os:store>

            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "RECONNECTED",
    message: "Sandbox connection re-established. Dependent flows re-enabled.",
    verifiedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <error-handler>
                <on-error-continue type="ANY">
                    <ee:transform>
                        <ee:message>
                            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "STILL_DISCONNECTED",
    message: "Sandbox connection still failing: " ++ error.description,
    nextSteps: [
        "Verify Connected App credentials are updated",
        "Check IP restrictions in Salesforce Setup",
        "Confirm sandbox refresh is fully complete"
    ]
}
                            ]]></ee:set-payload>
                        </ee:message>
                    </ee:transform>
                </on-error-continue>
            </error-handler>
        </try>
    </flow>
</mule>
```

**Pre-Refresh Checklist**

```yaml
pre_refresh_checklist:
  before_refresh:
    - action: "Document current Connected App Consumer Key"
      owner: "Salesforce Admin"
    - action: "Note current sandbox Org ID from Setup > Company Information"
      owner: "Salesforce Admin"
    - action: "Pause all MuleSoft flows targeting this sandbox"
      owner: "MuleSoft Dev"
    - action: "Verify Connected App is in a managed package (survives refresh)"
      owner: "Salesforce Admin"
    - action: "Notify all teams with integrations pointing to this sandbox"
      owner: "Release Manager"

  after_refresh:
    - action: "Log into refreshed sandbox (password is reset to production password)"
      owner: "Salesforce Admin"
    - action: "Verify Connected App exists (check Setup > App Manager)"
      owner: "Salesforce Admin"
    - action: "If missing, recreate Connected App or install from package"
      owner: "Salesforce Admin"
    - action: "Reset Consumer Secret and update in Secrets Manager"
      owner: "Salesforce Admin + MuleSoft Dev"
    - action: "Update sf.sandbox.org.id if org ID changed"
      owner: "MuleSoft Dev"
    - action: "Restart MuleSoft application"
      owner: "MuleSoft Dev"
    - action: "Call /api/admin/sandbox/verify to confirm connectivity"
      owner: "MuleSoft Dev"
    - action: "Resume paused flows"
      owner: "MuleSoft Dev"
```

## How It Works

1. **Periodic health check**: A scheduled flow runs every 30 minutes, making a lightweight API call to the sandbox and verifying the org identity matches the expected org ID.
2. **Refresh detection**: When the health check fails with `UNAUTHORIZED` or `INVALID_SESSION`, the system flags a probable sandbox refresh. It stores a detection report with impact assessment and remediation steps.
3. **Automated mitigation**: The system immediately invalidates the stale connection (preventing error accumulation in logs) and stops all sandbox-dependent flows to prevent error cascades.
4. **Operations alerting**: A detailed alert is sent to the operations team with specific remediation steps, estimated downtime, and a link to the runbook.
5. **Manual verification**: After the operations team completes remediation, they call the `/api/admin/sandbox/verify` endpoint, which tests the connection and re-enables dependent flows.

## Key Takeaways

- Package your Connected Apps in a managed or unmanaged package so they survive sandbox refreshes. Unpackaged Connected Apps are destroyed during refresh.
- Sandbox refreshes reset the admin password to the production password. The Salesforce admin must log in and potentially update the Connected App before MuleSoft can reconnect.
- Always store the expected org ID in a property. After refresh, the org ID may change if the sandbox was refreshed from a different source, which affects external ID references and cross-org data.
- Stop dependent flows immediately upon refresh detection. Letting them continue creates thousands of error log entries that obscure the real issue.
- Schedule sandbox refreshes during off-hours and coordinate with the MuleSoft team. Unplanned refreshes are the leading cause of sandbox integration outages.

## Related Recipes

- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
- [SF Invalid Session Recovery](../sf-invalid-session-recovery/)
- [SF Multi-Org Dynamic Routing](../sf-multi-org-dynamic-routing/)
