## APIkit Validation Errors
> Let APIkit validate requests against RAML/OAS and return detailed validation error messages.

### When to Use
- Your API has a RAML or OAS specification
- You want automatic request validation (headers, query params, body schema)
- Clients need specific feedback about what failed validation

### Configuration / Code

```xml
<flow name="api-main-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/*"/>
    <apikit:router config-ref="api-config"/>

    <error-handler>
        <on-error-propagate type="APIKIT:BAD_REQUEST">
            <set-variable variableName="httpStatus" value="400"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "VALIDATION_ERROR",
    message: "Request validation failed",
    details: error.description splitBy "\n" map trim($) filter !isEmpty($),
    correlationId: correlationId
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
        <on-error-propagate type="APIKIT:NOT_FOUND">
            <set-variable variableName="httpStatus" value="404"/>
            <set-payload value='#[output application/json --- {error: "NOT_FOUND", message: "Resource not found"}]' mimeType="application/json"/>
        </on-error-propagate>
        <on-error-propagate type="APIKIT:METHOD_NOT_ALLOWED">
            <set-variable variableName="httpStatus" value="405"/>
            <set-payload value='#[output application/json --- {error: "METHOD_NOT_ALLOWED", message: error.description}]' mimeType="application/json"/>
        </on-error-propagate>
        <on-error-propagate type="APIKIT:NOT_ACCEPTABLE">
            <set-variable variableName="httpStatus" value="406"/>
            <set-payload value='#[output application/json --- {error: "NOT_ACCEPTABLE", message: error.description}]' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `apikit:router` validates incoming requests against your RAML/OAS specification
2. Missing required fields, wrong types, enum mismatches all throw `APIKIT:BAD_REQUEST`
3. `error.description` contains the validation details — split on newlines for multiple violations
4. Each APIKIT error type maps to a standard HTTP status code

### Gotchas
- APIkit validates request body only if `Content-Type` matches the spec — send the right header
- Enum validation messages may be cryptic — consider wrapping them for readability
- APIkit does NOT validate response bodies — only requests
- If you disable validation in `apikit:config`, none of these errors will be thrown

### Related
- [RAML/OAS Validation](../../validation/raml-oas-validation/) — deeper validation patterns
- [JSON Schema Validation](../../validation/json-schema-validation/) — standalone schema validation
- [RFC 7807 Problem Details](../rfc7807-problem-details/) — standardized error format
