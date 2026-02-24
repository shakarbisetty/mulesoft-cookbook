## SOAP Fault to REST Error
> Catch SOAP faults from Web Service Consumer and transform to structured REST JSON errors.

### When to Use
- Your Mule API proxies a backend SOAP service
- Upstream REST consumers should not see raw SOAP fault XML
- You need to map SOAP fault codes to HTTP status codes

### Configuration / Code

```xml
<flow name="soap-proxy-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders/{id}"/>

    <wsc:consume config-ref="WSC_Config" operation="GetOrder">
        <wsc:message>
            <wsc:body><![CDATA[#[output application/xml --- { GetOrderRequest: { orderId: attributes.uriParams.id } }]]]></wsc:body>
        </wsc:message>
    </wsc:consume>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload.Body.GetOrderResponse]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <error-handler>
        <on-error-propagate type="WSC:SOAP_FAULT">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
var fault = error.errorMessage.payload
---
{
    error: fault.Body.Fault.faultcode default "SOAP_FAULT",
    message: fault.Body.Fault.faultstring default "Downstream SOAP service error",
    detail: fault.Body.Fault.detail default null,
    correlationId: correlationId
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
            <set-variable variableName="httpStatus" value="502"/>
        </on-error-propagate>
        <on-error-propagate type="WSC:CANNOT_DISPATCH">
            <set-variable variableName="httpStatus" value="503"/>
            <set-payload value='#[output application/json --- {error: "Service Unavailable", message: "SOAP service unreachable"}]' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `wsc:consume` calls the SOAP service; on SOAP fault, it throws `WSC:SOAP_FAULT`
2. The error message payload contains the SOAP fault XML
3. DataWeave extracts faultcode, faultstring, and detail from the fault envelope
4. The response is returned as JSON with a 502 status

### Gotchas
- SOAP 1.1 uses `faultcode`/`faultstring`; SOAP 1.2 uses `Code`/`Reason` — check your WSDL version
- The fault payload structure varies by service — always inspect `error.errorMessage.payload` during development
- `WSC:CANNOT_DISPATCH` means the service is unreachable (network error), not a SOAP fault

### Related
- [Upstream Error Passthrough](../upstream-error-passthrough/) — enriching downstream errors
- [Status Code Mapper](../status-code-mapper/) — mapping to HTTP codes
