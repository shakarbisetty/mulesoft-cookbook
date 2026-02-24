## JSON Schema Validation
> Validate incoming JSON against a schema and collect all violations, not just the first.

### When to Use
- You need validation beyond what APIkit provides
- Custom JSON payloads without a RAML/OAS spec
- You want all violations in a single response, not one at a time

### Configuration / Code

```xml
<flow name="json-validation-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <try>
        <json:validate-schema schema="schemas/order-schema.json"
                              xmlns:json="http://www.mulesoft.org/schema/mule/json"/>
        <error-handler>
            <on-error-propagate type="JSON:SCHEMA_NOT_HONOURED">
                <set-variable variableName="httpStatus" value="400"/>
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "SCHEMA_VALIDATION_FAILED",
    violations: error.description splitBy "\n" map trim($) filter !isEmpty($),
    schema: "order-schema.json"
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </try>
    <flow-ref name="process-order"/>
</flow>
```

### How It Works
1. `json:validate-schema` checks the payload against the JSON Schema file
2. On violation, throws `JSON:SCHEMA_NOT_HONOURED` with all violations in `error.description`
3. DataWeave parses the description into individual violations

### Gotchas
- Schema file path is relative to `src/main/resources/`
- The JSON module must be added as a dependency in `pom.xml`
- For large payloads, validation can be CPU-intensive — cache compiled schemas
- JSON Schema draft version must match your schema files (Draft-04, Draft-07, etc.)

### Related
- [XSD Validation](../xsd-validation/) — XML schema validation
- [Custom Business Validation](../custom-business-validation/) — business rule validation
