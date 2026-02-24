## Content Negotiation
> Return JSON or XML based on the Accept header with minimal transformation overhead.

### When to Use
- APIs that must serve both JSON and XML clients
- Legacy systems requiring XML while modern clients use JSON
- RESTful APIs following HTTP content negotiation standards

### Configuration / Code

```xml
<flow name="content-negotiated-api">
    <http:listener config-ref="HTTP_Listener" path="/api/orders/{id}"/>
    <flow-ref name="get-order"/>
    <choice>
        <when expression="#[attributes.headers.accept contains 'application/xml']">
            <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/xml
---
{ order: payload }]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </when>
        <otherwise>
            <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Check the `Accept` header from the request
2. Route to the appropriate DataWeave output format
3. Default to JSON if no Accept header or unsupported format
4. Set Content-Type response header automatically based on output format

### Gotchas
- `Accept: */*` should default to JSON (most common format)
- Some clients send `Accept: application/xml, application/json` — honor the first preference
- XML output requires a root element — wrap the payload if needed

### Related
- [GZIP Compression](../gzip-compression/) — compressing responses
- [RAML Traits](../../../api-management/api-design/raml-traits/) — API spec content types
