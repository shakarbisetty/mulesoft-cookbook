## Workday Parallel Pagination

> Parallel SOAP page retrieval for large Workday data syncs with configurable concurrency, retry handling, and result aggregation.

### When to Use

- Syncing large datasets from Workday (10,000+ workers, positions, or compensation records)
- Current sequential pagination takes too long for the sync window (e.g., nightly batch must complete in 2 hours)
- Need to pull Workday data for real-time dashboards where latency matters
- Workday Report-as-a-Service (RaaS) returns too many rows for a single response

### The Problem

Workday's SOAP API paginates large result sets, returning 100-250 records per page. For 50,000 workers, that is 200+ sequential SOAP calls, each taking 2-5 seconds. Sequential processing means a 15-minute minimum sync time. Parallel pagination retrieves multiple pages simultaneously, reducing sync time to under 3 minutes, but requires careful handling of page tokens, error recovery, and result ordering.

### Configuration

#### Initial Page Request to Get Total Count

```xml
<flow name="workday-parallel-sync-flow">
    <scheduler doc:name="Nightly Sync">
        <scheduling-strategy>
            <cron expression="0 0 1 * * ?" timeZone="UTC" />
        </scheduling-strategy>
    </scheduler>

    <!-- First page: get total count and page metadata -->
    <ee:transform doc:name="Build Initial SOAP Request">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/xml
ns wd http://www.workday.com/service/Human_Resources
---
{
    wd#Get_Workers_Request: {
        wd#Request_Criteria: {
            wd#Exclude_Inactive_Workers: true
        },
        wd#Response_Filter: {
            wd#Page: 1,
            wd#Count: 200
        },
        wd#Response_Group: {
            wd#Include_Personal_Information: true,
            wd#Include_Employment_Information: true,
            wd#Include_Compensation: false,
            wd#Include_Organizations: true
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <wsc:consume config-ref="Workday_HCM_Config"
        doc:name="Get First Page"
        operation="Get_Workers" />

    <!-- Extract pagination metadata -->
    <ee:transform doc:name="Extract Page Info">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
ns wd http://www.workday.com/service/Human_Resources
var response = payload.body
var results = response.wd#Get_Workers_Response.wd#Response_Results
---
{
    totalResults: results.wd#Total_Results as Number,
    totalPages: results.wd#Total_Pages as Number,
    pageSize: 200,
    firstPageData: response.wd#Get_Workers_Response.wd#Response_Data.wd#Worker
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="paginationMeta" value="#[payload]" />
    <set-variable variableName="allWorkers" value="#[payload.firstPageData]" />

    <logger level="INFO"
        message="Workday sync: #[payload.totalResults] workers across #[payload.totalPages] pages" />

    <!-- Build list of remaining pages to fetch -->
    <ee:transform doc:name="Build Page List">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
(2 to vars.paginationMeta.totalPages) as Array map {
    pageNumber: $
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Parallel fetch remaining pages -->
    <parallel-foreach doc:name="Fetch Pages in Parallel"
        collection="#[payload]"
        maxConcurrency="${workday.parallel.maxConcurrency}">
        <try doc:name="Fetch Single Page">
            <ee:transform doc:name="Build Page Request">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/xml
ns wd http://www.workday.com/service/Human_Resources
---
{
    wd#Get_Workers_Request: {
        wd#Request_Criteria: {
            wd#Exclude_Inactive_Workers: true
        },
        wd#Response_Filter: {
            wd#Page: payload.pageNumber,
            wd#Count: 200
        },
        wd#Response_Group: {
            wd#Include_Personal_Information: true,
            wd#Include_Employment_Information: true,
            wd#Include_Compensation: false,
            wd#Include_Organizations: true
        }
    }
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <wsc:consume config-ref="Workday_HCM_Config"
                doc:name="Get Page"
                operation="Get_Workers" />

            <ee:transform doc:name="Extract Workers">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/java
ns wd http://www.workday.com/service/Human_Resources
---
payload.body.wd#Get_Workers_Response.wd#Response_Data.wd#Worker default []]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <error-handler>
                <on-error-continue type="WSC:TIMEOUT, WSC:CONNECTIVITY">
                    <logger level="WARN"
                        message="Page #[payload.pageNumber] failed. Will retry." />
                    <!-- Return empty for this page; retry logic below -->
                    <set-payload value="#[[]]" />
                </on-error-continue>
            </error-handler>
        </try>
    </parallel-foreach>

    <!-- Aggregate all pages -->
    <ee:transform doc:name="Aggregate Workers">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
vars.allWorkers ++ (payload flatMap $.payload)]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <logger level="INFO"
        message="Aggregated #[sizeOf(payload)] workers from Workday" />

    <!-- Process aggregated results -->
    <batch:job jobName="workday-worker-sync"
        blockSize="200"
        maxFailedRecords="50">
        <batch:process-records>
            <batch:step name="transform-and-upsert">
                <flow-ref name="workday-transform-worker-subflow" />
            </batch:step>
        </batch:process-records>
    </batch:job>
</flow>
```

#### Worker Data Transformation

```xml
<sub-flow name="workday-transform-worker-subflow">
    <ee:transform doc:name="Map Worker to Target">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
ns wd http://www.workday.com/service/Human_Resources
var worker = payload
var personalData = worker.wd#Worker_Data.wd#Personal_Data
var employmentData = worker.wd#Worker_Data.wd#Employment_Data
var name = personalData.wd#Name_Data.wd#Legal_Name_Data.wd#Name_Detail_Data
---
{
    workdayId: worker.wd#Worker_Reference.wd#ID @(wd#"type": "WID"),
    employeeId: worker.wd#Worker_Reference.wd#ID @(wd#"type": "Employee_ID"),
    firstName: name.wd#First_Name,
    lastName: name.wd#Last_Name,
    email: personalData.wd#Contact_Data.wd#Email_Address_Data.wd#Email_Address default "",
    hireDate: employmentData.wd#Worker_Status_Data.wd#Hire_Date,
    jobTitle: employmentData.wd#Worker_Job_Data[0].wd#Position_Data.wd#Business_Title default "",
    department: employmentData.wd#Worker_Job_Data[0].wd#Position_Data.wd#Business_Site_Summary_Data.wd#Name default "",
    isActive: employmentData.wd#Worker_Status_Data.wd#Active as Boolean default true
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="Target_HR_API"
        method="PUT"
        path="#['/api/employees/' ++ payload.employeeId]" />
</sub-flow>
```

#### Workday Web Service Configuration

```xml
<wsc:config name="Workday_HCM_Config" doc:name="Workday HCM Config">
    <wsc:connection
        wsdlLocation="https://${workday.host}/ccx/service/${workday.tenant}/Human_Resources/v42.0?wsdl"
        service="Human_ResourcesService"
        port="Human_Resources"
        address="https://${workday.host}/ccx/service/${workday.tenant}/Human_Resources/v42.0">
        <wsc:custom-transport-configuration>
            <http:request-connection
                host="${workday.host}"
                port="443"
                protocol="HTTPS">
                <http:authentication>
                    <http:basic-authentication
                        username="${workday.user}@${workday.tenant}"
                        password="${workday.password}" />
                </http:authentication>
            </http:request-connection>
        </wsc:custom-transport-configuration>
    </wsc:connection>
</wsc:config>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Calculate optimal parallelism based on total pages and worker capacity
fun optimalConcurrency(totalPages: Number, vcores: Number): Number = do {
    var maxThreads = vcores * 4
    ---
    min([totalPages, maxThreads, 10])
}

// Estimate sync duration
fun estimateSyncTime(totalPages: Number, avgPageTimeMs: Number, concurrency: Number): String = do {
    var totalMs = ceil(totalPages / concurrency) * avgPageTimeMs
    var minutes = floor(totalMs / 60000)
    var seconds = ceil((totalMs mod 60000) / 1000)
    ---
    "$(minutes)m $(seconds)s"
}
---
{
    "50k_workers_200_per_page": {
        pages: 250,
        concurrency: optimalConcurrency(250, 1),
        estimatedTime: estimateSyncTime(250, 3000, optimalConcurrency(250, 1))
    }
}
```

### Gotchas

- **Workday rate limits** — Workday throttles API calls per tenant. Excessive parallelism (more than 8-10 concurrent calls) triggers HTTP 429 responses. Start with `maxConcurrency=4` and increase only if Workday does not throttle
- **`parallel-foreach` memory** — All pages are held in memory until aggregation. For 50,000 workers with rich data, this can be 500 MB+. On CloudHub 0.1 or 0.2 vCore workers, this will OOM. Use at least 1 vCore for parallel pagination
- **Page consistency** — Workday does not guarantee snapshot isolation across pages. If workers are added or modified during pagination, you may get duplicates or miss records. Run sync during off-hours and deduplicate by worker ID
- **SOAP timeout configuration** — Default SOAP timeout is 30 seconds. Large pages from Workday can take 10-15 seconds. Set the HTTP request timeout to 60 seconds to avoid premature timeouts on slow pages
- **Namespace versioning** — Workday API namespaces include version numbers. When upgrading from v40 to v42, all namespace URIs change. Update both the WSDL location and the DataWeave namespace declarations
- **Authentication format** — Workday requires `username@tenant` format. Forgetting the `@tenant` suffix causes silent authentication failures that return HTTP 200 with an empty response body

### Testing

```xml
<munit:test name="workday-parallel-pagination-test"
    description="Verify parallel fetch aggregates all pages">

    <munit:behavior>
        <munit-tools:mock-when processor="wsc:consume">
            <munit-tools:then-return>
                <munit-tools:payload value="#[readUrl('classpath://test-workday-response.xml')]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="paginationMeta"
            value="#[{totalResults: 600, totalPages: 3, pageSize: 200}]" />
        <flow-ref name="workday-parallel-sync-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[sizeOf(payload)]"
            is="#[MunitTools::greaterThan(0)]" />
    </munit:validation>
</munit:test>
```

### Related

- [Workday Custom Reports](../workday-custom-reports/) — RaaS reports as an alternative to paginated API calls
- [ServiceNow Incident Lifecycle](../servicenow-incident-lifecycle/) — Similar parallel patterns for ServiceNow table queries
