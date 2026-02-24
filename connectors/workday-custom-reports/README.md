## Workday Custom Reports

> Pull custom reports from Workday via RaaS (Report as a Service) with pagination and DataWeave parsing.

### When to Use

- Extracting HR data (employees, compensation, benefits) from Workday on a schedule
- Building integrations that consume Workday custom reports for downstream systems (payroll, identity management, data warehouse)
- Replacing Workday Studio or EIB-based exports with API-driven extraction
- Feeding Workday data into analytics platforms or data lakes

### Configuration

#### Workday Connector Global Config

```xml
<workday:config name="Workday_Config" doc:name="Workday Config">
    <workday:basic-connection
        username="${workday.username}"
        password="${workday.password}"
        tenantName="${workday.tenant}"
        hostName="${workday.host}" />
</workday:config>
```

#### Custom Report via RaaS (HTTP)

Workday custom reports are exposed as REST endpoints under `/ccx/service/customreport2/`. For maximum flexibility, use the HTTP connector with Workday's RaaS URL directly.

```xml
<http:request-config name="Workday_RaaS_Config" doc:name="Workday RaaS HTTP">
    <http:request-connection
        host="${workday.host}"
        port="443"
        protocol="HTTPS">
        <http:authentication>
            <http:basic-authentication
                username="${workday.username}@${workday.tenant}"
                password="${workday.password}" />
        </http:authentication>
    </http:request-connection>
</http:request-config>

<flow name="workday-custom-report-flow">
    <scheduler doc:name="Daily Trigger">
        <scheduling-strategy>
            <cron expression="0 0 6 * * ?" timeZone="America/Los_Angeles" />
        </scheduling-strategy>
    </scheduler>

    <set-variable variableName="reportOwner" value="${workday.reportOwner}" />
    <set-variable variableName="reportName" value="${workday.reportName}" />
    <set-variable variableName="pageSize" value="100" />
    <set-variable variableName="page" value="1" />
    <set-variable variableName="allResults" value="#[[]]" />

    <flow-ref name="workday-paginated-fetch" />
</flow>
```

#### Paginated Report Fetching

```xml
<sub-flow name="workday-paginated-fetch">
    <until-successful maxRetries="3" millisBetweenRetries="5000">
        <http:request config-ref="Workday_RaaS_Config"
            method="GET"
            path="/ccx/service/customreport2/${workday.tenant}/#[vars.reportOwner]/#[vars.reportName]">
            <http:query-params><![CDATA[#[output application/java
---
{
    "format": "json",
    "count": vars.pageSize,
    "page": vars.page
}]]]></http:query-params>
        </http:request>
    </until-successful>

    <ee:transform doc:name="Parse Page">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload.Report_Entry]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="allResults"
        value="#[vars.allResults ++ payload]" />

    <choice doc:name="More Pages?">
        <when expression="#[sizeOf(payload) == vars.pageSize as Number]">
            <set-variable variableName="page"
                value="#[vars.page as Number + 1]" />
            <flow-ref name="workday-paginated-fetch" />
        </when>
    </choice>
</sub-flow>
```

#### Full Flow with Batch Processing

```xml
<flow name="workday-report-batch-flow">
    <scheduler doc:name="Daily Trigger">
        <scheduling-strategy>
            <cron expression="0 0 6 * * ?" timeZone="America/Los_Angeles" />
        </scheduling-strategy>
    </scheduler>

    <http:request config-ref="Workday_RaaS_Config"
        method="GET"
        path="/ccx/service/customreport2/${workday.tenant}/${workday.reportOwner}/${workday.reportName}">
        <http:query-params><![CDATA[#[output application/java
---
{
    "format": "json"
}]]]></http:query-params>
        <http:response-validator>
            <http:success-status-code-validator values="200" />
        </http:response-validator>
    </http:request>

    <ee:transform doc:name="Parse Report">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload.Report_Entry]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <batch:job jobName="workday-employee-sync"
        maxFailedRecords="10"
        blockSize="50">
        <batch:process-records>
            <batch:step name="transform-step">
                <ee:transform doc:name="Map Employee">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    employeeId: payload.Employee_ID,
    firstName: payload.First_Name,
    lastName: payload.Last_Name,
    email: payload.Email_Address,
    department: payload.Department,
    jobTitle: payload.Job_Title,
    hireDate: payload.Hire_Date,
    managerId: payload.Manager_ID,
    location: payload.Location,
    status: if (payload.Active == "1") "active" else "inactive"
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </batch:step>
            <batch:step name="upsert-step">
                <db:insert config-ref="Database_Config" doc:name="Upsert Employee">
                    <db:sql><![CDATA[INSERT INTO employees
(employee_id, first_name, last_name, email, department, job_title, hire_date, manager_id, location, status, updated_at)
VALUES (:employeeId, :firstName, :lastName, :email, :department, :jobTitle, :hireDate, :managerId, :location, :status, CURRENT_TIMESTAMP)
ON CONFLICT (employee_id) DO UPDATE SET
first_name = :firstName, last_name = :lastName, email = :email,
department = :department, job_title = :jobTitle, manager_id = :managerId,
location = :location, status = :status, updated_at = CURRENT_TIMESTAMP]]></db:sql>
                    <db:input-parameters><![CDATA[#[payload]]]></db:input-parameters>
                </db:insert>
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <logger level="INFO"
                message="Workday sync complete: #[payload.processedRecords] processed, #[payload.failedRecords] failed" />
        </batch:on-complete>
    </batch:job>
</flow>
```

#### DataWeave: Workday Response Parsing

```dataweave
%dw 2.0
output application/json

var employees = payload.Report_Entry
---
{
    metadata: {
        reportName: "Active Employees",
        extractedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
        totalRecords: sizeOf(employees)
    },
    employees: employees map ((emp) -> {
        id: emp.Employee_ID,
        name: {
            first: emp.First_Name,
            last: emp.Last_Name,
            preferred: emp.Preferred_Name default emp.First_Name
        },
        contact: {
            workEmail: emp.Email_Address,
            workPhone: emp.Work_Phone default null
        },
        position: {
            title: emp.Job_Title,
            department: emp.Department,
            costCenter: emp.Cost_Center,
            location: emp.Location,
            manager: emp.Manager_ID
        },
        dates: {
            hired: emp.Hire_Date as Date {format: "yyyy-MM-dd"} default null,
            terminated: emp.Termination_Date as Date {format: "yyyy-MM-dd"} default null
        },
        isActive: emp.Active == "1"
    })
}
```

### How It Works

1. **Scheduler triggers** — A cron-based scheduler fires daily (or on your cadence) to initiate the report extraction
2. **RaaS endpoint call** — The HTTP connector calls Workday's custom report REST endpoint (`/ccx/service/customreport2/{tenant}/{owner}/{reportName}`) with JSON format
3. **Pagination loop** — For large reports, an `until-successful` loop fetches pages using `count` and `page` query parameters until a page returns fewer records than the page size
4. **DataWeave transform** — The nested Workday XML/JSON response is mapped to a normalized structure suitable for downstream systems
5. **Batch processing** — Records are processed in configurable block sizes with upsert logic to handle both new and updated employees
6. **Error handling** — Failed records are counted; the batch job continues processing remaining records up to `maxFailedRecords`

### Gotchas

- **Report timeout for large datasets** — Workday custom reports with 50,000+ rows can time out at the Workday API level. Break large reports into filtered segments (by supervisory org, date range, or worker type) and merge results
- **Workday rate limits** — Workday enforces API rate limits per tenant. The default is approximately 20 concurrent connections. Add `until-successful` with exponential backoff, and avoid scheduling multiple report extractions simultaneously
- **XSLT dependencies** — Some Workday report transformations use XSLT-based Advanced Reports. These require the `xslt` field in the report definition and may return XML even when JSON is requested. Always check the response content type
- **RaaS URL format** — The report owner in the URL is the Workday username of the report creator, not the integration system user. If the report owner leaves the organization, the report URL breaks. Use a service account as report owner
- **Date formats** — Workday returns dates in `yyyy-MM-dd` format but datetime fields use ISO 8601 with timezone. DataWeave parsing must account for both formats
- **Custom report field names** — Field names in the JSON response match the report column aliases, which are case-sensitive and may contain spaces. Use bracket notation in DataWeave: `payload."Field With Spaces"`
- **Sandbox vs production** — Workday sandbox tenants are refreshed periodically, which resets custom report definitions and integration system credentials. Always re-validate after sandbox refresh

### Related

- [ServiceNow CMDB](../servicenow-cmdb/) — Similar connector-based enterprise system extraction
- [Database CDC](../database-cdc/) — For incremental sync patterns instead of full report pulls
- [NetSuite Patterns](../netsuite-patterns/) — Another ERP connector with similar pagination challenges
