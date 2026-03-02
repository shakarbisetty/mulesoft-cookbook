# Dynamic Multi-Org Salesforce Routing

## Problem

Enterprise organizations often maintain multiple Salesforce orgs: production, sandbox, regional orgs (EMEA, APAC, Americas), or separate orgs for different business units acquired through M&A. A naive approach creates a separate MuleSoft application per org, leading to code duplication, deployment complexity, and operational overhead that scales linearly with org count. When a new org is added (a common occurrence during acquisitions), deploying and configuring another copy of the application takes weeks.

## Solution

Build a single MuleSoft application that dynamically routes requests to the correct Salesforce org based on request attributes (header, query parameter, or payload field). Use externalized configuration for per-org credentials, connection pooling, and a registry pattern that allows adding new orgs without code changes or redeployment.

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

    <!-- Org registry stored externally (loaded from secure properties) -->
    <!-- In production, use Anypoint Secrets Manager or HashiCorp Vault -->

    <!-- Per-org Salesforce configurations -->
    <salesforce:sfdc-config name="SF_Config_US_PROD">
        <salesforce:oauth-client-credentials-connection
            consumerKey="${sf.us.prod.clientId}"
            consumerSecret="${sf.us.prod.clientSecret}"
            tokenUrl="https://login.salesforce.com/services/oauth2/token"
            audienceUrl="https://login.salesforce.com"/>
    </salesforce:sfdc-config>

    <salesforce:sfdc-config name="SF_Config_EMEA_PROD">
        <salesforce:oauth-client-credentials-connection
            consumerKey="${sf.emea.prod.clientId}"
            consumerSecret="${sf.emea.prod.clientSecret}"
            tokenUrl="https://login.salesforce.com/services/oauth2/token"
            audienceUrl="https://login.salesforce.com"/>
    </salesforce:sfdc-config>

    <salesforce:sfdc-config name="SF_Config_APAC_PROD">
        <salesforce:oauth-client-credentials-connection
            consumerKey="${sf.apac.prod.clientId}"
            consumerSecret="${sf.apac.prod.clientSecret}"
            tokenUrl="https://login.salesforce.com/services/oauth2/token"
            audienceUrl="https://login.salesforce.com"/>
    </salesforce:sfdc-config>

    <!-- Org registry Object Store (cached org metadata) -->
    <os:object-store name="orgRegistryStore"
                     persistent="true"
                     entryTtl="24"
                     entryTtlUnit="HOURS"/>

    <!-- Main API: Dynamic routing based on X-Salesforce-Org header -->
    <flow name="multi-org-api-router">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/salesforce/{operation}"
                       method="POST"/>

        <!-- Step 1: Extract target org from request -->
        <ee:transform doc:name="Resolve Target Org">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

// Org resolution priority:
// 1. Explicit header (X-Salesforce-Org)
// 2. Payload field (orgCode)
// 3. Derive from region in user data
var explicitOrg = attributes.headers."x-salesforce-org" default ""
var payloadOrg = payload.orgCode default ""
var derivedOrg = payload.region default "" match {
    case "US" -> "US_PROD"
    case "EMEA" -> "EMEA_PROD"
    case "APAC" -> "APAC_PROD"
    else -> ""
}

var targetOrg = if (!isEmpty(explicitOrg)) upper(explicitOrg)
                else if (!isEmpty(payloadOrg)) upper(payloadOrg)
                else if (!isEmpty(derivedOrg)) derivedOrg
                else "UNKNOWN"

// Org registry: maps org codes to config names and metadata
var orgRegistry = {
    US_PROD: {
        configName: "SF_Config_US_PROD",
        apiVersion: "v59.0",
        instanceUrl: "https://na1.salesforce.com",
        rateLimit: 100000,
        label: "US Production"
    },
    EMEA_PROD: {
        configName: "SF_Config_EMEA_PROD",
        apiVersion: "v59.0",
        instanceUrl: "https://eu1.salesforce.com",
        rateLimit: 50000,
        label: "EMEA Production"
    },
    APAC_PROD: {
        configName: "SF_Config_APAC_PROD",
        apiVersion: "v59.0",
        instanceUrl: "https://ap1.salesforce.com",
        rateLimit: 50000,
        label: "APAC Production"
    }
}

var orgConfig = orgRegistry[targetOrg]
---
{
    targetOrg: targetOrg,
    orgConfig: orgConfig,
    isValidOrg: orgConfig != null,
    operation: attributes.uriParams.operation,
    requestPayload: payload
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Validate org exists in registry -->
        <choice>
            <when expression="#[payload.isValidOrg == false]">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    error: "UNKNOWN_ORG",
    message: "Salesforce org '" ++ payload.targetOrg ++ "' is not registered",
    validOrgs: ["US_PROD", "EMEA_PROD", "APAC_PROD"]
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
                <set-variable variableName="httpStatus" value="#[400]"/>
            </when>
            <otherwise>
                <set-variable variableName="targetOrg" value="#[payload.targetOrg]"/>
                <set-variable variableName="orgConfig" value="#[payload.orgConfig]"/>
                <set-variable variableName="operation" value="#[payload.operation]"/>
                <set-payload value="#[payload.requestPayload]"/>

                <logger level="INFO"
                        message='Routing to #[vars.orgConfig.label] (#[vars.targetOrg]) for operation: #[vars.operation]'/>

                <!-- Step 2: Route to correct Salesforce config -->
                <choice doc:name="Route to Org">
                    <when expression="#[vars.targetOrg == 'US_PROD']">
                        <flow-ref name="execute-sf-operation-us"/>
                    </when>
                    <when expression="#[vars.targetOrg == 'EMEA_PROD']">
                        <flow-ref name="execute-sf-operation-emea"/>
                    </when>
                    <when expression="#[vars.targetOrg == 'APAC_PROD']">
                        <flow-ref name="execute-sf-operation-apac"/>
                    </when>
                </choice>
            </otherwise>
        </choice>

        <error-handler>
            <on-error-propagate type="ANY">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    error: error.errorType.identifier,
    message: error.description,
    targetOrg: vars.targetOrg default "UNKNOWN",
    operation: vars.operation default "UNKNOWN"
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </flow>

    <!-- Per-org execution flows (each uses its own SF config) -->
    <sub-flow name="execute-sf-operation-us">
        <choice>
            <when expression="#[vars.operation == 'query']">
                <salesforce:query config-ref="SF_Config_US_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
            </when>
            <when expression="#[vars.operation == 'create']">
                <salesforce:create config-ref="SF_Config_US_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:create>
            </when>
            <when expression="#[vars.operation == 'update']">
                <salesforce:update config-ref="SF_Config_US_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:update>
            </when>
        </choice>
    </sub-flow>

    <sub-flow name="execute-sf-operation-emea">
        <choice>
            <when expression="#[vars.operation == 'query']">
                <salesforce:query config-ref="SF_Config_EMEA_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
            </when>
            <when expression="#[vars.operation == 'create']">
                <salesforce:create config-ref="SF_Config_EMEA_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:create>
            </when>
            <when expression="#[vars.operation == 'update']">
                <salesforce:update config-ref="SF_Config_EMEA_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:update>
            </when>
        </choice>
    </sub-flow>

    <sub-flow name="execute-sf-operation-apac">
        <choice>
            <when expression="#[vars.operation == 'query']">
                <salesforce:query config-ref="SF_Config_APAC_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
            </when>
            <when expression="#[vars.operation == 'create']">
                <salesforce:create config-ref="SF_Config_APAC_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:create>
            </when>
            <when expression="#[vars.operation == 'update']">
                <salesforce:update config-ref="SF_Config_APAC_PROD"
                                   type="#[payload.objectType]">
                    <salesforce:records>#[payload.records]</salesforce:records>
                </salesforce:update>
            </when>
        </choice>
    </sub-flow>

    <!-- Cross-org query: query all orgs and merge results -->
    <flow name="cross-org-aggregate-query">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/salesforce/cross-org/query"
                       method="POST"/>

        <scatter-gather doc:name="Query All Orgs">
            <route>
                <salesforce:query config-ref="SF_Config_US_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (r) -> r ++ {_sourceOrg: "US_PROD"}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </route>
            <route>
                <salesforce:query config-ref="SF_Config_EMEA_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (r) -> r ++ {_sourceOrg: "EMEA_PROD"}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </route>
            <route>
                <salesforce:query config-ref="SF_Config_APAC_PROD">
                    <salesforce:salesforce-query>#[payload.soql]</salesforce:salesforce-query>
                </salesforce:query>
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
payload map (r) -> r ++ {_sourceOrg: "APAC_PROD"}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </route>
        </scatter-gather>

        <!-- Merge all results into single array -->
        <ee:transform doc:name="Merge Cross-Org Results">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    totalRecords: sizeOf(flatten(payload..payload)),
    results: flatten(payload..payload),
    queriedOrgs: ["US_PROD", "EMEA_PROD", "APAC_PROD"]
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

## How It Works

1. **Org resolution**: The target org is determined from request context with a priority chain: explicit `X-Salesforce-Org` header, `orgCode` field in the payload, or derived from a `region` field using a mapping table.
2. **Registry validation**: The resolved org code is checked against an org registry that maps each code to a Salesforce connector configuration, API version, instance URL, and rate limit. Unknown orgs are rejected with a 400 error.
3. **Dynamic routing**: A choice router directs the request to the correct per-org sub-flow, which uses the appropriate Salesforce connector configuration.
4. **Per-org execution**: Each org has its own sub-flow with its own connector config, ensuring connection pooling and authentication are isolated per org.
5. **Cross-org aggregation**: A scatter-gather pattern queries all orgs simultaneously and merges results, with each record tagged with its source org for traceability.

## Key Takeaways

- Each Salesforce org must have its own connector configuration with separate credentials. Never share Connected App credentials across orgs.
- Store credentials in Anypoint Secrets Manager or HashiCorp Vault, not in property files. When a new org is added, only the secrets need updating.
- The per-org sub-flow pattern (while verbose) ensures connection pool isolation. A stalled connection to one org does not affect others.
- For cross-org queries, always tag records with their source org. Salesforce IDs are only unique within a single org.
- Add per-org rate limiting to prevent one org's traffic from consuming the entire application's capacity.

## Related Recipes

- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
- [SF Sandbox Refresh Reconnect](../sf-sandbox-refresh-reconnect/)
- [SF Invalid Session Recovery](../sf-invalid-session-recovery/)
- [SF API Quota Monitoring](../sf-api-quota-monitoring/)
