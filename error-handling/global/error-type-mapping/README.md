## Error Type Mapping
> Map connector-specific errors to custom domain error types for cleaner error handler logic.

### When to Use
- You want to decouple your error handling from specific connector error types
- Different connectors throw similar errors that should be handled the same way
- You want application-level error semantics (APP:VALIDATION, APP:NOT_FOUND)

### Configuration / Code

```xml
<flow name="customer-lookup-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/customers/{id}"/>

    <!-- Map connector errors to domain errors -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT * FROM customers WHERE id = :id</db:sql>
        <db:input-parameters><![CDATA[#[{ id: attributes.uriParams.id }]]]></db:input-parameters>
        <error-mapping
            sourceType="DB:CONNECTIVITY"
            targetType="APP:SERVICE_UNAVAILABLE"/>
        <error-mapping
            sourceType="DB:QUERY_EXECUTION"
            targetType="APP:DATA_ERROR"/>
    </db:select>

    <!-- Validate result -->
    <choice>
        <when expression="#[isEmpty(payload)]">
            <raise-error type="APP:NOT_FOUND"
                         description="Customer not found"/>
        </when>
    </choice>

    <!-- Error handler uses clean domain types -->
    <error-handler>
        <on-error-propagate type="APP:NOT_FOUND">
            <set-variable variableName="httpStatus" value="404"/>
            <set-payload value='{"error": "Customer not found"}'
                         mimeType="application/json"/>
        </on-error-propagate>
        <on-error-propagate type="APP:SERVICE_UNAVAILABLE">
            <set-variable variableName="httpStatus" value="503"/>
            <set-payload value='{"error": "Service temporarily unavailable"}'
                         mimeType="application/json"/>
        </on-error-propagate>
        <on-error-propagate type="APP:DATA_ERROR">
            <set-variable variableName="httpStatus" value="500"/>
            <set-payload value='{"error": "Data processing error"}'
                         mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `error-mapping` on any component maps a source error type to a target type
2. The `APP:*` namespace is reserved for application-defined error types
3. When the mapped error is thrown, the error handler matches against the target type
4. `raise-error` creates custom errors for business logic violations
5. This decouples your error handling from connector internals

### Gotchas
- `error-mapping` only works on the component it is defined on — not globally
- You cannot map to `MULE:*` types — only `APP:*` or other custom namespaces
- The original error is preserved in `error.cause` for debugging
- `raise-error` description should be user-friendly — it appears in `error.description`

### Related
- [Shared Error Library](../shared-error-library/) — centralize error handlers
- [Custom Business Validation](../../validation/custom-business-validation/) — raise-error for validation
- [Status Code Mapper](../../http-errors/status-code-mapper/) — map error types to HTTP codes
