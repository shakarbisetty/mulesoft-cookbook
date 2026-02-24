## GraphQL Error Response Format
> Format errors following the GraphQL spec with errors array containing message, locations, path, and extensions.

### When to Use
- Your Mule app serves a GraphQL API (via APIkit for GraphQL)
- Error responses must conform to the GraphQL specification
- You need structured error reporting with field-level paths

### Configuration / Code

```xml
<flow name="graphql-error-handler-flow">
    <apikit:router config-ref="graphql-config"/>

    <error-handler>
        <on-error-propagate type="APIKIT:BAD_REQUEST">
            <set-variable variableName="httpStatus" value="200"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    data: null,
    errors: [{
        message: error.description,
        locations: [{line: 1, column: 1}],
        path: [],
        extensions: {
            code: "VALIDATION_ERROR",
            correlationId: correlationId,
            timestamp: now()
        }
    }]
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
        <on-error-propagate type="ANY">
            <set-variable variableName="httpStatus" value="200"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    data: null,
    errors: [{
        message: "Internal server error",
        extensions: {
            code: "INTERNAL_ERROR",
            correlationId: correlationId
        }
    }]
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. GraphQL errors always return HTTP 200 — the error is in the response body
2. The `errors` array follows the GraphQL spec: `message` (required), `locations`, `path`, `extensions`
3. `data: null` indicates the query failed entirely; partial results use `data` with specific null fields
4. `extensions` carries custom metadata like correlation ID and error codes

### Gotchas
- GraphQL errors MUST return HTTP 200, not 4xx/5xx — this is a spec requirement
- Never expose internal error details in the `message` field
- If using batched queries, each query in the batch can have its own errors array

### Related
- [APIkit Validation Errors](../apikit-validation-errors/) — RAML/OAS validation
- [RFC 7807 Problem Details](../rfc7807-problem-details/) — REST equivalent
