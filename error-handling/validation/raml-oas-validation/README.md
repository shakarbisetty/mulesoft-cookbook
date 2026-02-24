## RAML/OAS Request Validation
> Configure APIkit to return specific validation error messages instead of generic 400 errors.

### When to Use
- Your API has a RAML or OAS specification
- Clients need detailed feedback about what failed validation
- You want auto-validation without custom DataWeave checks

### Configuration / Code

```xml
<apikit:config name="api-config" raml="api.raml" outboundHeadersMapName="outboundHeaders"
               httpStatusVarName="httpStatus" keepRamlBaseUri="false"/>

<flow name="api-main">
    <http:listener config-ref="HTTP_Listener" path="/api/*"/>
    <apikit:router config-ref="api-config"/>
    <error-handler>
        <on-error-propagate type="APIKIT:BAD_REQUEST">
            <set-variable variableName="httpStatus" value="400"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "VALIDATION_ERROR",
    message: "Request validation failed against API specification",
    violations: (error.description default "") splitBy "\n" filter !isEmpty($)
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. APIkit router validates requests against the RAML/OAS specification
2. Missing required fields, wrong types, and enum mismatches throw `APIKIT:BAD_REQUEST`
3. `error.description` contains human-readable violation details
4. DataWeave splits multiple violations into an array

### Gotchas
- APIkit validates requests only — not responses
- Validation is based on the spec file bundled in the app — keep it in sync with Design Center
- `Content-Type` header must match spec for body validation to work

### Related
- [APIkit Validation Errors](../../http-errors/apikit-validation-errors/) — comprehensive APIkit handling
- [JSON Schema Validation](../json-schema-validation/) — standalone schema validation
