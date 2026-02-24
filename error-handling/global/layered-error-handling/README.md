## Layered Error Handling
> Three-tier strategy: try scope handles retryable errors, flow handler handles business errors, global handler catches everything else.

### When to Use
- Complex flows where different error types need different handling strategies
- You want retryable operations to retry locally without affecting the whole flow
- Global consistency with flow-specific overrides

### Configuration / Code

```xml
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:db="http://www.mulesoft.org/schema/mule/db"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/db http://www.mulesoft.org/schema/mule/db/current/mule-db.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <!-- Layer 3: Global catch-all -->
    <error-handler name="global-error-handler">
        <on-error-propagate type="ANY">
            <logger level="ERROR" message="Global handler caught: #[error.errorType]"/>
            <set-variable variableName="httpStatus" value="500"/>
            <set-payload value='{"error":"Internal server error"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>

    <flow name="order-creation-flow">
        <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>

        <!-- Layer 1: Try scope for retryable operations -->
        <try>
            <http:request config-ref="Inventory_Service" path="/check" method="POST"/>
            <error-handler>
                <on-error-continue type="HTTP:TIMEOUT, HTTP:CONNECTIVITY">
                    <logger level="WARN" message="Inventory check failed, using cached data"/>
                    <set-payload value='#[vars.cachedInventory]'/>
                </on-error-continue>
                <!-- Non-retryable HTTP errors propagate to flow handler -->
            </error-handler>
        </try>

        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (customer_id, items) VALUES (:cid, :items)</db:sql>
            <db:input-parameters><![CDATA[#[{cid: payload.customerId, items: write(payload.items, "application/json")}]]]></db:input-parameters>
        </db:insert>

        <set-payload value='{"status":"created"}' mimeType="application/json"/>

        <!-- Layer 2: Flow-level handler for business errors -->
        <error-handler>
            <on-error-propagate type="DB:CONNECTIVITY">
                <set-variable variableName="httpStatus" value="503"/>
                <set-payload value='{"error":"Database unavailable"}' mimeType="application/json"/>
            </on-error-propagate>
            <on-error-propagate type="DB:QUERY_EXECUTION">
                <set-variable variableName="httpStatus" value="409"/>
                <set-payload value='{"error":"Order conflict"}' mimeType="application/json"/>
            </on-error-propagate>
            <!-- Anything not caught here goes to global handler -->
            <on-error-propagate type="ANY">
                <flow-ref name="global-error-handler"/>
            </on-error-propagate>
        </error-handler>
    </flow>
</mule>
```

### How It Works
1. **Layer 1 (Try scope)**: Handles transient/retryable errors locally — `on-error-continue` swallows and provides fallback data
2. **Layer 2 (Flow handler)**: Catches business-level errors with specific HTTP responses
3. **Layer 3 (Global handler)**: Catches anything that escapes the flow handler — last resort
4. Errors propagate outward: try → flow → global. Each layer handles what it knows about.

### Gotchas
- `on-error-continue` in a try scope resumes after the try, not after the failed component
- Flow-level error handler catches errors from the entire flow, including those that propagated out of try scopes
- If the flow handler has no matching `on-error-propagate` for an error type, it falls through to the global handler
- The global handler should log everything — it is your last chance to capture error context

### Related
- [Default Error Handler](../default-error-handler/) — global handler pattern
- [On-Error-Continue vs Propagate](../on-error-continue-vs-propagate/) — decision matrix
- [HTTP Timeout Fallback](../../connector-errors/http-timeout-fallback/) — try scope for fallback
