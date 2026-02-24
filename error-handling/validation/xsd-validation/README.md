## XML Schema (XSD) Validation
> Validate incoming XML payloads against an XSD schema with structured error details.

### When to Use
- Your API accepts XML payloads from legacy systems
- SOAP-to-REST proxies where incoming XML must be validated
- Schema compliance is required before processing

### Configuration / Code

```xml
<flow name="xml-validation-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/xml-import" method="POST"/>
    <try>
        <xml:validate-schema schemas="schemas/order.xsd"
                             xmlns:xml="http://www.mulesoft.org/schema/mule/xml-module"/>
        <error-handler>
            <on-error-propagate type="XML-MODULE:SCHEMA_NOT_HONOURED">
                <set-variable variableName="httpStatus" value="400"/>
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "XML_VALIDATION_FAILED",
    message: "XML payload does not conform to schema",
    violations: error.description splitBy "\n" filter !isEmpty($),
    schema: "order.xsd"
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </on-error-propagate>
        </error-handler>
    </try>
    <flow-ref name="process-xml-order"/>
</flow>
```

### How It Works
1. `xml:validate-schema` checks the XML payload against the XSD file
2. On violation, throws `XML-MODULE:SCHEMA_NOT_HONOURED`
3. Error description contains all XSD validation errors

### Gotchas
- Schema path is relative to `src/main/resources/`
- The XML module must be added as a dependency
- Multiple XSD files can be referenced with comma separation
- Large XML validation can be memory-intensive — use streaming for big payloads

### Related
- [JSON Schema Validation](../json-schema-validation/) — JSON equivalent
- [SOAP Fault to REST](../../http-errors/soap-fault-to-rest/) — SOAP error handling
