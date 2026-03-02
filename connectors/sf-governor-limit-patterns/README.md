## Salesforce Governor Limit Patterns

> API call counting, circuit breaker on limit approach, rate limiting, and governor-safe query patterns for Mule 4 Salesforce integrations.

### When to Use

- Integration makes hundreds of Salesforce API calls per hour and risks hitting the 24-hour rolling limit
- Need automatic throttling when approaching 80% of the org's API call allocation
- Multiple MuleSoft applications share the same Salesforce org and must coordinate API usage
- After-hours batch jobs consume API calls that are needed by daytime interactive integrations

### The Problem

Salesforce enforces API call limits per org (not per connected app). A typical Enterprise Edition org gets 100,000 API calls per 24-hour rolling window. A single aggressive integration can exhaust this limit, causing all integrations and users to receive `REQUEST_LIMIT_EXCEEDED` errors. There is no built-in throttle in the Salesforce connector; you must implement it yourself.

### Configuration

#### API Limit Check Before Each Call

```xml
<os:object-store name="SF_API_Counter_Store"
    doc:name="SF API Counter Store"
    persistent="true"
    entryTtl="24"
    entryTtlUnit="HOURS"
    maxEntries="100" />

<sub-flow name="sf-governor-check-subflow">
    <!-- Query current API usage from Salesforce -->
    <salesforce:query config-ref="Salesforce_Config"
        doc:name="Check API Limits">
        <salesforce:salesforce-query><![CDATA[SELECT
    Organization.Name
FROM Organization
LIMIT 1]]></salesforce:salesforce-query>
    </salesforce:query>

    <!-- The API usage is in the response headers -->
    <set-variable variableName="apiUsageHeader"
        value="#[attributes.headers.'Sforce-Limit-Info' default '']" />

    <ee:transform doc:name="Parse Limit Info">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var limitInfo = vars.apiUsageHeader
var parts = if (limitInfo != "") limitInfo splitBy "=" else ["api-usage", "0/100000"]
var usage = (parts[-1] default "0/100000") splitBy "/"
---
{
    currentUsage: usage[0] as Number default 0,
    maxLimit: usage[1] as Number default 100000,
    percentUsed: ((usage[0] as Number default 0) / (usage[1] as Number default 100000) * 100) as Number {format: "#.##"},
    isApproachingLimit: ((usage[0] as Number default 0) / (usage[1] as Number default 100000)) > 0.80,
    isCritical: ((usage[0] as Number default 0) / (usage[1] as Number default 100000)) > 0.95
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="apiLimits" value="#[payload]" />
</sub-flow>
```

#### Circuit Breaker Pattern

```xml
<flow name="sf-api-with-circuit-breaker-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/accounts"
        allowedMethods="GET" />

    <!-- Check circuit breaker state -->
    <os:retrieve key="sf_circuit_state"
        objectStore="SF_API_Counter_Store"
        doc:name="Get Circuit State">
        <os:default-value>CLOSED</os:default-value>
    </os:retrieve>

    <set-variable variableName="circuitState" value="#[payload]" />

    <choice doc:name="Circuit Breaker">
        <when expression="#[vars.circuitState == 'OPEN']">
            <!-- Check if cooldown period has passed -->
            <os:retrieve key="sf_circuit_opened_at"
                objectStore="SF_API_Counter_Store">
                <os:default-value>0</os:default-value>
            </os:retrieve>

            <choice doc:name="Cooldown Expired?">
                <when expression="#[(now() as Number - (payload as Number default 0)) > 300000]">
                    <!-- 5 min cooldown passed, try half-open -->
                    <os:store key="sf_circuit_state"
                        objectStore="SF_API_Counter_Store">
                        <os:value>HALF_OPEN</os:value>
                    </os:store>
                    <flow-ref name="sf-make-api-call-subflow" />
                </when>
                <otherwise>
                    <set-payload value="#[output application/json --- {
                        error: 'Circuit breaker OPEN',
                        message: 'Salesforce API limit approaching. Requests throttled.',
                        retryAfter: 300
                    }]" />
                    <set-variable variableName="httpStatus" value="429" />
                </otherwise>
            </choice>
        </when>
        <otherwise>
            <flow-ref name="sf-make-api-call-subflow" />
        </otherwise>
    </choice>
</flow>

<sub-flow name="sf-make-api-call-subflow">
    <try doc:name="Salesforce Call with Limit Tracking">
        <salesforce:query config-ref="Salesforce_Config"
            doc:name="Query Accounts">
            <salesforce:salesforce-query><![CDATA[SELECT Id, Name, Industry, AnnualRevenue
FROM Account
WHERE LastModifiedDate = LAST_N_DAYS:7
LIMIT 200]]></salesforce:salesforce-query>
        </salesforce:query>

        <!-- Track usage after each call -->
        <flow-ref name="sf-track-api-usage-subflow" />

        <error-handler>
            <on-error-continue type="SALESFORCE:LIMIT_EXCEEDED">
                <logger level="ERROR"
                    message="Salesforce API limit exceeded! Opening circuit breaker." />
                <os:store key="sf_circuit_state"
                    objectStore="SF_API_Counter_Store">
                    <os:value>OPEN</os:value>
                </os:store>
                <os:store key="sf_circuit_opened_at"
                    objectStore="SF_API_Counter_Store">
                    <os:value>#[now() as Number as String]</os:value>
                </os:store>
                <set-payload value="#[output application/json --- {
                    error: 'API_LIMIT_EXCEEDED',
                    message: 'Salesforce daily API limit reached. Circuit breaker activated.'
                }]" />
                <set-variable variableName="httpStatus" value="503" />
            </on-error-continue>
        </error-handler>
    </try>
</sub-flow>

<sub-flow name="sf-track-api-usage-subflow">
    <set-variable variableName="apiUsage"
        value="#[attributes.headers.'Sforce-Limit-Info' default '']" />

    <ee:transform doc:name="Parse Usage">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
var parts = (vars.apiUsage splitBy "=")[-1] default "0/100000"
var usage = parts splitBy "/"
---
{
    used: usage[0] as Number default 0,
    max: usage[1] as Number default 100000,
    percent: (usage[0] as Number / usage[1] as Number * 100)
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice doc:name="Approaching Limit?">
        <when expression="#[payload.percent > 80]">
            <logger level="WARN"
                message="Salesforce API usage at #[payload.percent]% (#[payload.used]/#[payload.max])" />

            <choice doc:name="Critical?">
                <when expression="#[payload.percent > 95]">
                    <os:store key="sf_circuit_state"
                        objectStore="SF_API_Counter_Store">
                        <os:value>OPEN</os:value>
                    </os:store>
                    <os:store key="sf_circuit_opened_at"
                        objectStore="SF_API_Counter_Store">
                        <os:value>#[now() as Number as String]</os:value>
                    </os:store>
                    <logger level="ERROR"
                        message="API usage CRITICAL at #[payload.percent]%. Circuit breaker OPENED." />
                </when>
            </choice>
        </when>
    </choice>
</sub-flow>
```

#### Composite API to Reduce Call Count

```xml
<flow name="sf-composite-batch-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sf/composite-upsert"
        allowedMethods="POST" />

    <!-- Composite API: up to 25 subrequests in 1 API call -->
    <ee:transform doc:name="Build Composite Request">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    compositeRequest: (payload[0 to 24] default []) map ((record, idx) -> {
        method: "PATCH",
        url: "/services/data/v59.0/sobjects/Account/External_Id__c/$(record.externalId)",
        referenceId: "ref_$(idx)",
        body: {
            Name: record.name,
            Industry: record.industry,
            AnnualRevenue: record.revenue
        }
    })
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="Salesforce_REST_Config"
        method="POST"
        path="/services/data/v59.0/composite">
        <http:headers><![CDATA[#[output application/java --- {
            "Content-Type": "application/json"
        }]]]></http:headers>
    </http:request>

    <ee:transform doc:name="Parse Results">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    totalSubrequests: sizeOf(payload.compositeResponse),
    successful: sizeOf(payload.compositeResponse filter $.httpStatusCode >= 200 and $.httpStatusCode < 300),
    failed: sizeOf(payload.compositeResponse filter $.httpStatusCode >= 400),
    errors: payload.compositeResponse filter ($.httpStatusCode >= 400) map {
        ref: $.referenceId,
        status: $.httpStatusCode,
        error: $.body
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Parse Sforce-Limit-Info header
fun parseApiLimits(header: String): Object = do {
    var parts = (header splitBy "=")[-1] default "0/100000"
    var usage = parts splitBy "/"
    ---
    {
        used: usage[0] as Number default 0,
        max: usage[1] as Number default 100000,
        remaining: (usage[1] as Number default 100000) - (usage[0] as Number default 0),
        percentUsed: round((usage[0] as Number / usage[1] as Number) * 100)
    }
}

// Calculate safe API calls remaining for this integration
fun safeCallBudget(limits: Object, reservePercent: Number = 20): Number =
    max([0, limits.remaining - (limits.max * reservePercent / 100)])
---
{
    example: parseApiLimits("api-usage=75000/100000"),
    budget: safeCallBudget(parseApiLimits("api-usage=75000/100000"))
}
```

### Gotchas

- **`Sforce-Limit-Info` header is not always present** — The header appears on REST API responses but not on Streaming API or Metadata API calls. If your connector uses SOAP internally, you may not get this header at all
- **Limits are per org, not per connected app** — If 5 MuleSoft apps and 3 third-party tools share one Salesforce org, they all draw from the same pool. You need centralized tracking (e.g., shared Object Store or database counter) to coordinate
- **API call counting is approximate** — Salesforce's own counter updates asynchronously. Your tracked count may be 5-10% behind the real usage. Always leave a safety margin (20% reserve)
- **Composite API counts as 1 API call** — A composite request with 25 subrequests counts as 1 API call against the limit, not 25. This is the single most effective way to reduce API consumption
- **Bulk API has separate limits** — Bulk API batches are counted separately from REST API calls. Use Bulk API for large data operations to preserve your REST API budget for interactive requests
- **Salesforce license tier matters** — API Edition gets 15,000 calls/day, Enterprise gets 100,000, Unlimited gets 500,000. Performance Edition gets 500,000 + 1,000 per user license. Check your exact allocation in Setup > Company Information
- **Circuit breaker cooldown must account for rolling window** — Salesforce's limit is a 24-hour rolling window, not a daily reset. A 5-minute cooldown may re-open the breaker while the limit is still exceeded. Consider exponential backoff

### Testing

```xml
<munit:test name="sf-circuit-breaker-opens-test"
    description="Verify circuit breaker opens at 95% usage">

    <munit:behavior>
        <munit-tools:mock-when processor="os:retrieve">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="key"
                    whereValue="sf_circuit_state" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#['CLOSED']" />
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <munit-tools:mock-when processor="salesforce:query">
            <munit-tools:then-return>
                <munit-tools:payload value="#[[{Id: '001', Name: 'Test'}]]" />
                <munit-tools:attributes value="#[{headers: {'Sforce-Limit-Info': 'api-usage=96000/100000'}}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="sf-api-with-circuit-breaker-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="os:store"
            times="2" />
    </munit:validation>
</munit:test>
```

### Related

- [SF Bulk API v2 Optimization](../sf-bulk-api-v2-optimization/) — Bulk API uses separate limits and is more efficient
- [SF CDC Idempotent Processing](../sf-cdc-idempotent-processing/) — CDC streaming does not consume REST API calls
