## Custom Business Validation
> Implement multi-field business rule validation in DataWeave and raise APP:VALIDATION errors.

### When to Use
- Business rules that cannot be expressed in JSON Schema (cross-field, conditional)
- You need validation logic specific to your domain
- Multiple validation rules checked at once

### Configuration / Code

```xml
<flow name="order-validation-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <ee:transform>
        <ee:set-variable variableName="validationErrors"><![CDATA[%dw 2.0
output application/java
var errors = []
    ++ (if (payload.amount <= 0) [{field: "amount", message: "Must be positive"}] else [])
    ++ (if (payload.amount > 10000 and payload.approver == null) [{field: "approver", message: "Required for orders over 10,000"}] else [])
    ++ (if (payload.shipDate < payload.orderDate) [{field: "shipDate", message: "Cannot be before order date"}] else [])
    ++ (if (isEmpty(payload.items)) [{field: "items", message: "At least one item required"}] else [])
---
errors]]></ee:set-variable>
    </ee:transform>

    <choice>
        <when expression="#[sizeOf(vars.validationErrors) > 0]">
            <raise-error type="APP:VALIDATION"
                         description="#[write(vars.validationErrors, 'application/json')]"/>
        </when>
    </choice>

    <flow-ref name="process-order"/>

    <error-handler>
        <on-error-propagate type="APP:VALIDATION">
            <set-variable variableName="httpStatus" value="422"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "VALIDATION_ERROR",
    message: "Business validation failed",
    violations: read(error.description, "application/json")
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. DataWeave evaluates all business rules and collects violations into an array
2. If any violations exist, `raise-error` throws `APP:VALIDATION` with the error list as description
3. The error handler parses the violations back from the description and returns 422

### Gotchas
- `raise-error` description is a String — serialize complex objects to JSON and parse back
- Always validate ALL rules, not just the first failure — users expect a complete error list
- `APP:VALIDATION` is a custom type — define it consistently across your organization

### Related
- [JSON Schema Validation](../json-schema-validation/) — schema-level validation
- [Bulk Per-Record Validation](../bulk-per-record-validation/) — array-level validation
- [Error Type Mapping](../../global/error-type-mapping/) — custom error types
