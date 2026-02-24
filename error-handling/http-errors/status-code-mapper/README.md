## HTTP Status Code Mapper
> Route different Mule error types to correct HTTP status codes using error type matching.

### When to Use
- Your API must return precise HTTP status codes (400, 401, 403, 404, 429, 500, 502, 503)
- APIkit does not cover all your custom error-to-status mappings
- You want a single, comprehensive mapping table

### Configuration / Code

```xml
<error-handler name="http-status-error-handler">
    <on-error-propagate type="APIKIT:BAD_REQUEST, APP:VALIDATION">
        <set-variable variableName="httpStatus" value="400"/>
        <set-payload value='#[output application/json --- {error: "Bad Request", message: error.description, correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="HTTP:UNAUTHORIZED, MULE:SECURITY">
        <set-variable variableName="httpStatus" value="401"/>
        <set-payload value='#[output application/json --- {error: "Unauthorized", message: "Authentication required", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="HTTP:FORBIDDEN">
        <set-variable variableName="httpStatus" value="403"/>
        <set-payload value='#[output application/json --- {error: "Forbidden", message: "Insufficient permissions", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="APIKIT:NOT_FOUND, APP:NOT_FOUND">
        <set-variable variableName="httpStatus" value="404"/>
        <set-payload value='#[output application/json --- {error: "Not Found", message: error.description, correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="HTTP:TOO_MANY_REQUESTS">
        <set-variable variableName="httpStatus" value="429"/>
        <set-payload value='#[output application/json --- {error: "Too Many Requests", message: "Rate limit exceeded", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="HTTP:BAD_GATEWAY, HTTP:CONNECTIVITY">
        <set-variable variableName="httpStatus" value="502"/>
        <set-payload value='#[output application/json --- {error: "Bad Gateway", message: "Upstream service error", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="HTTP:SERVICE_UNAVAILABLE, DB:CONNECTIVITY">
        <set-variable variableName="httpStatus" value="503"/>
        <set-payload value='#[output application/json --- {error: "Service Unavailable", message: "Service temporarily unavailable", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
    <on-error-propagate type="ANY">
        <set-variable variableName="httpStatus" value="500"/>
        <set-payload value='#[output application/json --- {error: "Internal Server Error", message: "An unexpected error occurred", correlationId: correlationId}]' mimeType="application/json"/>
    </on-error-propagate>
</error-handler>
```

### How It Works
1. Each `on-error-propagate` block matches one or more error types using comma-separated values
2. The `httpStatus` variable controls the HTTP response status code (used by the HTTP listener)
3. Order matters: specific types before `ANY` catch-all
4. Multiple Mule error types can map to the same HTTP status (e.g., both `HTTP:CONNECTIVITY` and `HTTP:BAD_GATEWAY` → 502)

### Gotchas
- The `httpStatus` variable must be a String, not a Number
- If you forget `type="ANY"` at the end, unmatched errors return the default Mule error page
- `HTTP:TIMEOUT` is not the same as `HTTP:CONNECTIVITY` — handle both if you want 502/503 coverage

### Related
- [RFC 7807 Problem Details](../rfc7807-problem-details/) — standardized error body format
- [Default Error Handler](../../global/default-error-handler/) — global handler reference
