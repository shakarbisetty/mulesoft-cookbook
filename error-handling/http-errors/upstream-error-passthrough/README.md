## Upstream Error Passthrough
> Capture downstream HTTP error responses and enrich them before returning upstream.

### When to Use
- Your API proxies or orchestrates calls to downstream services
- You need to pass through meaningful error details from backends
- You want to add context (which service failed, correlation ID) to downstream errors

### Configuration / Code

```xml
<flow name="order-orchestration-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>

    <http:request config-ref="Order_Service" path="/orders" method="POST"/>

    <error-handler>
        <on-error-propagate type="HTTP:BAD_REQUEST, HTTP:UNAUTHORIZED, HTTP:NOT_FOUND, HTTP:INTERNAL_SERVER_ERROR">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
var downstreamBody = error.errorMessage.payload
var downstreamStatus = error.errorMessage.attributes.statusCode
---
{
    error: "DOWNSTREAM_ERROR",
    source: "Order Service",
    downstreamStatus: downstreamStatus,
    downstreamMessage: if (downstreamBody is Object) downstreamBody
                       else {raw: downstreamBody as String default "No body"},
    correlationId: correlationId,
    timestamp: now()
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
            <set-variable variableName="httpStatus"
                          value="#[error.errorMessage.attributes.statusCode as String default '502']"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. When `http:request` gets a non-2xx response, it throws an HTTP error
2. `error.errorMessage.payload` contains the downstream response body
3. `error.errorMessage.attributes.statusCode` has the downstream HTTP status
4. DataWeave enriches the error with the source service name and correlation ID
5. The downstream status code is passed through (or defaulted to 502)

### Gotchas
- `error.errorMessage.payload` is a stream — read it only once or enable repeatable streaming
- If the downstream returns HTML (e.g., a load balancer error page), parsing as JSON will fail
- Some errors (HTTP:TIMEOUT, HTTP:CONNECTIVITY) have no response body — guard with `default`
- Status code passthrough may not always be appropriate — a downstream 500 might warrant a 502 from your API

### Related
- [HTTP Timeout Fallback](../../connector-errors/http-timeout-fallback/) — handling timeout specifically
- [Status Code Mapper](../status-code-mapper/) — comprehensive status mapping
- [Fallback Service Routing](../../recovery/fallback-service-routing/) — primary/secondary pattern
