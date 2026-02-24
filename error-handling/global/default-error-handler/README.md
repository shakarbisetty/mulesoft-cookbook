## Default Error Handler
> Map all unhandled errors to a standardized JSON response with correlation ID and timestamp.

### When to Use
- Every Mule application needs a global fallback for uncaught errors
- You want consistent error response format across all APIs
- Upstream consumers expect a known JSON error schema

### Configuration / Code

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- Global default error handler -->
    <error-handler name="global-error-handler">
        <on-error-propagate type="HTTP:UNAUTHORIZED">
            <set-variable variableName="httpStatus" value="401"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "UNAUTHORIZED",
    message: error.description default "Authentication required",
    correlationId: correlationId,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>

        <on-error-propagate type="HTTP:NOT_FOUND">
            <set-variable variableName="httpStatus" value="404"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "NOT_FOUND",
    message: error.description default "Resource not found",
    correlationId: correlationId,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>

        <!-- Catch-all for any unhandled error -->
        <on-error-propagate type="ANY">
            <set-variable variableName="httpStatus" value="500"/>
            <logger level="ERROR"
                    message="Unhandled error in flow #[flow.name]: #[error.errorType] - #[error.description]"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "INTERNAL_SERVER_ERROR",
    message: "An unexpected error occurred",
    correlationId: correlationId,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>

    <!-- Reference in your flows -->
    <flow name="orders-api-flow">
        <http:listener config-ref="HTTP_Listener" path="/api/orders" />
        <!-- business logic -->
        <error-handler ref="global-error-handler"/>
    </flow>
</mule>
```

### How It Works
1. Define a named `error-handler` at the global level
2. Add `on-error-propagate` blocks for each HTTP error type you want to handle explicitly
3. The final `type="ANY"` block catches everything else and returns a generic 500
4. Each block sets the HTTP status and builds a JSON body with correlationId and timestamp
5. Reference the handler in any flow via `<error-handler ref="global-error-handler"/>`

### Gotchas
- The `correlationId` variable is auto-populated by Mule — do not overwrite it unless you have a custom scheme
- `on-error-propagate` re-throws the error after handling; use `on-error-continue` if you want to swallow it
- Order matters: specific error types must appear before `ANY`, or they will never match
- The 500 handler should NOT expose `error.description` to clients — it may contain stack traces

### Related
- [On-Error-Continue vs Propagate](../on-error-continue-vs-propagate/) — when to swallow vs re-throw
- [Status Code Mapper](../../http-errors/status-code-mapper/) — comprehensive HTTP status mapping
- [Shared Error Library](../shared-error-library/) — extract handlers into reusable config
