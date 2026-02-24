## RFC 7807 / RFC 9457 Problem Details
> Return standardized application/problem+json error responses with type, title, status, detail, and instance fields.

### When to Use
- Your API consumers expect RFC 9457 Problem Details format
- You need machine-readable error responses with type URIs
- Standardizing error responses across multiple APIs

### Configuration / Code

```xml
<on-error-propagate type="APP:VALIDATION">
    <set-variable variableName="httpStatus" value="422"/>
    <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    "type": "https://api.example.com/errors/validation-error",
    "title": "Validation Error",
    "status": 422,
    "detail": error.description,
    "instance": "/" ++ (attributes.requestPath default "unknown"),
    "correlationId": correlationId,
    "timestamp": now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"},
    "errors": (error.errorMessage.payload.errors default []) map {
        field: $.field,
        message: $.message
    }
}]]></ee:set-payload>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{
    "Content-Type": "application/problem+json"
}]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</on-error-propagate>
```

### How It Works
1. The error handler catches the specific error type
2. DataWeave builds the RFC 9457 response body with required fields (`type`, `title`, `status`, `detail`)
3. `instance` points to the request path for traceability
4. The `Content-Type` header is set to `application/problem+json`
5. Optional `errors` array provides field-level validation details

### Gotchas
- The `type` field should be a URI that resolves to documentation about the error
- `Content-Type` must be `application/problem+json`, not `application/json`
- Some HTTP clients do not recognize `application/problem+json` — consider also accepting `application/json`
- `instance` should be a URI-reference, typically the request path

### Related
- [Status Code Mapper](../status-code-mapper/) — HTTP status routing
- [Custom Business Validation](../../validation/custom-business-validation/) — generating validation errors
- [APIkit Validation Errors](../apikit-validation-errors/) — auto-validation error details
