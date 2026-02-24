## ServiceNow CMDB Integration

> ServiceNow CMDB integration for asset management — create, update, and query Configuration Items with relationship mapping.

### When to Use

- Synchronizing IT asset data between ServiceNow CMDB and external systems (cloud providers, monitoring tools, inventory databases)
- Automating CI creation when new infrastructure is provisioned
- Building a single source of truth for configuration items across hybrid environments
- Querying CMDB relationships for impact analysis during incident management

### Common CMDB Tables

| Table | Description | Key Fields |
|-------|-------------|------------|
| `cmdb_ci_server` | Physical and virtual servers | `name`, `ip_address`, `os`, `ram`, `cpu_count` |
| `cmdb_ci_app_server` | Application servers | `name`, `running_process`, `tcp_port` |
| `cmdb_ci_database` | Database instances | `name`, `type`, `version`, `port` |
| `cmdb_ci_cloud_service_account` | Cloud accounts (AWS, Azure, GCP) | `name`, `account_id`, `region` |
| `cmdb_ci_vm_instance` | Cloud VM instances | `name`, `object_id`, `state` |
| `cmdb_rel_ci` | CI relationships | `parent`, `child`, `type` |
| `cmdb_ci_service` | Business services | `name`, `busines_criticality` |

### Configuration

#### ServiceNow Connector Global Config

```xml
<servicenow:config name="ServiceNow_Config" doc:name="ServiceNow Config">
    <servicenow:basic-connection
        instance="${servicenow.instance}"
        username="${servicenow.username}"
        password="${servicenow.password}" />
</servicenow:config>
```

#### Query CIs with Encoded Query

```xml
<flow name="servicenow-query-servers-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/cmdb/servers"
        allowedMethods="GET" />

    <servicenow:invoke config-ref="ServiceNow_Config"
        doc:name="Query Servers"
        service="ServiceNowTableAPI"
        operation="getRecords"
        type="cmdb_ci_server">
        <servicenow:message>
            <servicenow:body><![CDATA[#[output application/xml
---
{
    getRecords: {
        __encoded_query: "operational_status=1^install_status=1^osLIKELinux",
        __limit: attributes.queryParams.limit default "100",
        __offset: attributes.queryParams.offset default "0"
    }
}]]]></servicenow:body>
        </servicenow:message>
    </servicenow:invoke>

    <ee:transform doc:name="Map Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    servers: payload.getRecordsResponse.*getRecordsResult map {
        sysId: $.sys_id,
        name: $.name,
        ipAddress: $.ip_address,
        os: $.os,
        osVersion: $.os_version,
        ram: $.ram as Number default 0,
        cpuCount: $.cpu_count as Number default 0,
        environment: $.u_environment,
        operationalStatus: $.operational_status,
        lastDiscovered: $.last_discovered
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Create / Update CIs

```xml
<flow name="servicenow-upsert-ci-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/cmdb/servers"
        allowedMethods="POST,PUT" />

    <!-- Check if CI already exists -->
    <servicenow:invoke config-ref="ServiceNow_Config"
        doc:name="Lookup Existing CI"
        service="ServiceNowTableAPI"
        operation="getRecords"
        type="cmdb_ci_server">
        <servicenow:message>
            <servicenow:body><![CDATA[#[output application/xml
---
{
    getRecords: {
        __encoded_query: "name=" ++ payload.name,
        __limit: "1"
    }
}]]]></servicenow:body>
        </servicenow:message>
    </servicenow:invoke>

    <set-variable variableName="existingCi"
        value="#[payload.getRecordsResponse.getRecordsResult.sys_id]" />

    <choice doc:name="Create or Update?">
        <when expression="#[vars.existingCi != null and vars.existingCi != '']">
            <!-- Update existing CI -->
            <servicenow:invoke config-ref="ServiceNow_Config"
                doc:name="Update CI"
                service="ServiceNowTableAPI"
                operation="update"
                type="cmdb_ci_server">
                <servicenow:message>
                    <servicenow:body><![CDATA[#[output application/xml
---
{
    update: {
        sys_id: vars.existingCi,
        ip_address: vars.originalPayload.ipAddress,
        os: vars.originalPayload.os,
        os_version: vars.originalPayload.osVersion,
        ram: vars.originalPayload.ram,
        cpu_count: vars.originalPayload.cpuCount,
        operational_status: "1",
        install_status: "1"
    }
}]]]></servicenow:body>
                </servicenow:message>
            </servicenow:invoke>
        </when>
        <otherwise>
            <!-- Create new CI -->
            <servicenow:invoke config-ref="ServiceNow_Config"
                doc:name="Create CI"
                service="ServiceNowTableAPI"
                operation="insert"
                type="cmdb_ci_server">
                <servicenow:message>
                    <servicenow:body><![CDATA[#[output application/xml
---
{
    insert: {
        name: vars.originalPayload.name,
        ip_address: vars.originalPayload.ipAddress,
        os: vars.originalPayload.os,
        os_version: vars.originalPayload.osVersion,
        ram: vars.originalPayload.ram,
        cpu_count: vars.originalPayload.cpuCount,
        operational_status: "1",
        install_status: "1",
        "class": "cmdb_ci_server"
    }
}]]]></servicenow:body>
                </servicenow:message>
            </servicenow:invoke>
        </otherwise>
    </choice>
</flow>
```

#### DataWeave: CI Relationship Mapping

```dataweave
%dw 2.0
output application/json

// Map infrastructure topology into CMDB relationships
fun buildRelationships(infra) =
    (infra.applications flatMap ((app) ->
        // App "Runs on" Server
        (app.servers map {
            parent: app.sysId,
            child: $.sysId,
            "type": "cmdb_rel_type_id=d93304fb0a0a0b78006081a72ef08444"  // Runs on::Runs
        }) ++
        // App "Uses" Database
        (app.databases map {
            parent: app.sysId,
            child: $.sysId,
            "type": "cmdb_rel_type_id=cb5592603751200032ff8c00dfbe5d17"  // Uses::Used by
        })
    ))

var infra = payload
---
{
    metadata: {
        generatedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
        totalRelationships: sizeOf(buildRelationships(infra))
    },
    relationships: buildRelationships(infra) map {
        parent_sys_id: $.parent,
        child_sys_id: $.child,
        type_sys_id: $.("type") replace /cmdb_rel_type_id=/ with "",
        connectionType: if ($.("type") contains "d93304fb") "runs_on"
            else if ($.("type") contains "cb559260") "uses"
            else "depends_on"
    }
}
```

#### Bulk CI Relationship Creation

```xml
<flow name="servicenow-create-relationships-flow">
    <foreach doc:name="For Each Relationship" collection="#[payload.relationships]">
        <until-successful maxRetries="3" millisBetweenRetries="2000">
            <servicenow:invoke config-ref="ServiceNow_Config"
                doc:name="Create Relationship"
                service="ServiceNowTableAPI"
                operation="insert"
                type="cmdb_rel_ci">
                <servicenow:message>
                    <servicenow:body><![CDATA[#[output application/xml
---
{
    insert: {
        parent: payload.parent_sys_id,
        child: payload.child_sys_id,
        "type": payload.type_sys_id
    }
}]]]></servicenow:body>
                </servicenow:message>
            </servicenow:invoke>
        </until-successful>
    </foreach>
</flow>
```

### How It Works

1. **Query existing CIs** — Use encoded query strings to filter CMDB records by operational status, class, environment, or custom fields
2. **Upsert pattern** — Look up the CI by a unique key (name, serial number, or IP), then branch to create or update
3. **Map relationships** — After CIs exist, create `cmdb_rel_ci` records linking parent and child CIs with the correct relationship type sys_id
4. **Pagination** — Use `__limit` and `__offset` parameters to page through large result sets. ServiceNow defaults to 250 records per call
5. **Batch sync** — For bulk operations, iterate through source records and upsert each CI, then create/update relationships

### Gotchas

- **ACLs blocking API access** — ServiceNow ACLs (Access Control Lists) can silently filter out records the integration user cannot see. The API returns 200 OK with an empty result set instead of a 403. Always verify with a user that has `itil` and `cmdb_read` roles
- **Encoded query syntax** — ServiceNow encoded queries use `^` as AND, `^OR` as OR, and operators like `LIKE`, `STARTSWITH`, `IN`. The syntax is not documented in the standard API docs; export it from the ServiceNow list filter UI by right-clicking the breadcrumb
- **Pagination limits** — The `sysparm_limit` (REST) or `__limit` (SOAP) maximum is governed by the `glide.json.max_response_records` property, often set to 10,000. For larger datasets, use date-based windowing
- **Relationship type sys_ids** — Relationship types are records in `cmdb_rel_type`. The sys_id values differ between ServiceNow instances (dev vs prod). Never hardcode sys_ids; query `cmdb_rel_type` by name at runtime
- **Duplicate CIs** — ServiceNow has no built-in unique constraint on CI name. Multiple CIs with the same name can exist. Use Identification Rules (IRE) or implement your own dedup logic with a composite key
- **Rate limiting** — ServiceNow instances have REST API rate limits (varies by plan). Implement throttling with a delay between calls when processing hundreds of CIs. The `X-RateLimit-Remaining` header indicates quota
- **XML vs JSON** — The MuleSoft ServiceNow connector uses SOAP (XML) by default. For REST/JSON, use the HTTP connector with the ServiceNow Table API directly (`/api/now/table/{tableName}`)

### Related

- [Workday Custom Reports](../workday-custom-reports/) — Similar enterprise connector pattern for HR data
- [Database CDC](../database-cdc/) — For keeping CMDB in sync with source databases via change detection
- [SAP IDoc Processing](../sap-idoc-processing/) — Enterprise ERP integration with similar upsert patterns
