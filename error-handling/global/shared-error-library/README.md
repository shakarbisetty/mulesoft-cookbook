## Shared Error Handler Library
> Extract reusable error handlers into a shared XML config file referenced across multiple flows.

### When to Use
- Multiple Mule applications need the same error response format
- You want DRY error handling across dozens of flows
- Centralized error response standards for your organization

### Configuration / Code

**shared-error-handler.xml** (in `src/main/mule/`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <error-handler name="api-error-handler">
        <on-error-propagate type="APIKIT:BAD_REQUEST">
            <set-variable variableName="httpStatus" value="400"/>
            <flow-ref name="build-error-response"/>
        </on-error-propagate>
        <on-error-propagate type="APIKIT:NOT_FOUND">
            <set-variable variableName="httpStatus" value="404"/>
            <flow-ref name="build-error-response"/>
        </on-error-propagate>
        <on-error-propagate type="APIKIT:METHOD_NOT_ALLOWED">
            <set-variable variableName="httpStatus" value="405"/>
            <flow-ref name="build-error-response"/>
        </on-error-propagate>
        <on-error-propagate type="ANY">
            <set-variable variableName="httpStatus" value="500"/>
            <flow-ref name="build-error-response"/>
        </on-error-propagate>
    </error-handler>

    <sub-flow name="build-error-response">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: vars.httpStatus as Number,
        message: error.description default "Unknown error",
        correlationId: correlationId,
        timestamp: now()
    }
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </sub-flow>
</mule>
```

**Reference in any flow file:**

```xml
<flow name="customers-api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/customers/*"/>
    <apikit:router config-ref="api-config"/>
    <error-handler ref="api-error-handler"/>
</flow>
```

### How It Works
1. Define the error handler and helper sub-flows in a dedicated XML config file
2. Mule automatically loads all XML files in `src/main/mule/` at startup
3. Reference the named error handler via `ref` attribute in any flow
4. The `build-error-response` sub-flow is reused by every error type

### Gotchas
- The shared config file must be in `src/main/mule/` or a subdirectory — it is not auto-loaded from other locations
- If you package this as a Mule domain project, all apps in the domain share the handler
- Name collisions: ensure your error handler name is unique across all loaded config files
- Sub-flows referenced from error handlers must be in the same app (or domain)

### Related
- [Default Error Handler](../default-error-handler/) — inline global handler pattern
- [Error Type Mapping](../error-type-mapping/) — custom error types for cleaner routing
