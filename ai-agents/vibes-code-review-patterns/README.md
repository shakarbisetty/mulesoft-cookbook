## Vibes Code Review Patterns
> Systematic checklist and fix patterns for reviewing and hardening Vibes-generated Mule code.

### When to Use
- You have Vibes-generated flows that need production hardening
- You are establishing a review process for AI-generated integrations
- You want a repeatable checklist for catching common Vibes mistakes
- You need before/after examples to train reviewers

### Configuration / Code

**Review checklist — 12-point inspection:**

| # | Category | Check | Severity |
|---|----------|-------|----------|
| 1 | Error Handling | Error handler present with specific error types? | Critical |
| 2 | Error Handling | On-error-continue vs propagate used correctly? | Critical |
| 3 | Connections | All connection configs externalized to properties? | Critical |
| 4 | Connections | Secure properties used for passwords/tokens? | Critical |
| 5 | Logging | Structured logging with correlationId at entry/exit? | High |
| 6 | Logging | No sensitive data (PII, tokens) in log messages? | Critical |
| 7 | Config | Hardcoded URLs, ports, paths externalized? | High |
| 8 | Config | Timeout values set (not using defaults)? | Medium |
| 9 | Naming | All processors have descriptive doc:name? | Medium |
| 10 | Testing | MUnit tests generated or stubbed? | High |
| 11 | DataWeave | Null-safe operators used for optional fields? | High |
| 12 | Performance | Connection pools sized appropriately? | Medium |

**Before (Vibes output) — common mistakes annotated:**

```xml
<!-- VIBES GENERATED: REST API for customer lookup -->
<flow name="get-customer-flow">
    <!-- MISTAKE 1: No doc:name on listener -->
    <http:listener config-ref="HTTP_Listener_config" path="/customers/{id}"/>

    <!-- MISTAKE 2: Hardcoded URL, no timeout -->
    <http:request method="GET"
                  url="http://crm-api.internal:8080/api/customers/#[attributes.uriParams.id]"/>

    <!-- MISTAKE 3: No null-safety on response fields -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.customerId,
    name: payload.firstName ++ " " ++ payload.lastName,
    email: payload.contactInfo.email,
    tier: payload.loyaltyProgram.tier
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- MISTAKE 4: No error handler at all -->
</flow>

<!-- MISTAKE 5: Inline connection config with hardcoded credentials -->
<http:request-connection host="crm-api.internal" port="8080"
                         protocol="HTTP">
    <http:authentication>
        <http:basic-authentication username="admin" password="P@ssw0rd123"/>
    </http:authentication>
</http:request-connection>
```

**After (production-ready) — all mistakes fixed:**

```xml
<flow name="get-customer-flow">
    <http:listener config-ref="HTTP_Listener_config" path="/customers/{id}"
                   doc:name="GET /customers/{id}" allowedMethods="GET"/>

    <!-- FIX: Structured entry logging -->
    <logger level="INFO" doc:name="Log Request"
            message='#["GET /customers/" ++ attributes.uriParams.id ++ " correlationId=" ++ correlationId]'/>

    <!-- FIX: Externalized config, explicit timeouts -->
    <http:request config-ref="CRM_API_Config" method="GET"
                  path="/api/customers/#[attributes.uriParams.id]"
                  doc:name="Get Customer from CRM"
                  responseTimeout="10000"/>

    <!-- FIX: Null-safe DataWeave -->
    <ee:transform doc:name="Transform Customer Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.customerId,
    name: (payload.firstName default "") ++ " " ++ (payload.lastName default ""),
    email: payload.contactInfo.email default null,
    tier: payload.loyaltyProgram.tier default "STANDARD"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <logger level="INFO" doc:name="Log Response"
            message='#["Customer " ++ (payload.id default "unknown") ++ " retrieved. correlationId=" ++ correlationId]'/>

    <!-- FIX: Comprehensive error handler -->
    <error-handler>
        <on-error-continue type="HTTP:NOT_FOUND" enableNotifications="false"
                           doc:name="Customer Not Found">
            <ee:transform doc:name="404 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "CUSTOMER_NOT_FOUND",
        message: "Customer not found",
        correlationId: correlationId
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 404}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-continue type="HTTP:CONNECTIVITY, HTTP:TIMEOUT"
                           enableNotifications="false" doc:name="Backend Unavailable">
            <logger level="ERROR" doc:name="Log Backend Error"
                    message='#["CRM backend error: " ++ error.description ++ " correlationId=" ++ correlationId]'/>
            <ee:transform doc:name="503 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "SERVICE_UNAVAILABLE",
        message: "Customer service temporarily unavailable",
        correlationId: correlationId
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 503}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-propagate type="ANY" doc:name="Unexpected Error">
            <logger level="ERROR" doc:name="Log Unexpected Error"
                    message='#["Unexpected error: " ++ error.description ++ " correlationId=" ++ correlationId]'/>
            <ee:transform doc:name="500 Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred",
        correlationId: correlationId
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 500}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>

<!-- FIX: Externalized, secure connection config -->
<http:request-config name="CRM_API_Config" doc:name="CRM API Config">
    <http:request-connection host="${crm.api.host}" port="${crm.api.port}"
                             protocol="HTTPS">
        <tls:context>
            <tls:trust-store insecure="false"/>
        </tls:context>
        <http:authentication>
            <http:basic-authentication username="${secure::crm.api.username}"
                                       password="${secure::crm.api.password}"/>
        </http:authentication>
    </http:request-connection>
</http:request-config>
```

**Properties file structure (externalized config):**

```properties
# src/main/resources/config/${env}.yaml
crm:
  api:
    host: "crm-api.internal"
    port: "443"

# src/main/resources/config/${env}.secure.yaml (encrypted)
crm:
  api:
    username: "![encrypted-value]"
    password: "![encrypted-value]"
```

**Common Vibes mistakes — quick reference:**

| Mistake | Frequency | Fix |
|---------|-----------|-----|
| No error handler | ~90% of generations | Add error-handler with specific types + catch-all |
| Hardcoded URLs | ~85% | Move to `${property}` references |
| Inline credentials | ~80% | Use `${secure::property}` |
| No doc:name | ~70% | Add descriptive names to all processors |
| No null-safety in DW | ~75% | Add `default` or `?` operators |
| No logging | ~65% | Add entry/exit loggers with correlationId |
| No timeouts | ~60% | Set responseTimeout on HTTP requests |
| Default connection pool | ~55% | Size pool based on expected concurrency |
| No MUnit tests | ~95% | Generate separately (see Vibes MUnit Generation) |

### How It Works
1. Receive Vibes-generated Mule XML and open it alongside the 12-point checklist
2. Walk through each check systematically, annotating issues found
3. Apply fixes in priority order: Critical (security, error handling) first, then High, then Medium
4. Externalize all configuration values to property files with environment-specific overrides
5. Replace hardcoded credentials with `secure::` property references
6. Add null-safety operators in all DataWeave transforms where fields might be absent
7. Verify the fixed code deploys successfully and passes MUnit tests

### Gotchas
- **Vibes uses default configs**: Connection configs often use default pool sizes (5), no timeouts, and HTTP instead of HTTPS. Always review and override
- **Missing secure properties**: Vibes has no concept of `secure::` properties. Every credential, token, and API key must be manually moved to encrypted property files
- **No MUnit tests generated**: Vibes generates the flow but not the tests. Use a separate Vibes prompt for MUnit generation, then review those too
- **DataWeave null pointer exceptions**: Vibes-generated DataWeave rarely uses `default` or `?` operators. Production data with missing fields will cause runtime NPEs
- **Hardcoded HTTP (not HTTPS)**: Vibes defaults to HTTP protocol. In production, all external calls should use HTTPS with proper TLS configuration
- **Copy-paste config drift**: When Vibes generates multiple flows, it may create duplicate connection configs with slightly different settings. Consolidate into shared global configs

### Related
- [Vibes Prompt Engineering](../vibes-prompt-engineering/)
- [Vibes Governance](../vibes-governance/)
- [Vibes MUnit Generation](../../devops/testing/vibes-munit-generation/)
- [Error Scenario Testing](../../devops/testing/error-scenario-testing/)
