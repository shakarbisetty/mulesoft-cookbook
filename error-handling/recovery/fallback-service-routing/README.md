## Fallback Service Routing
> Try the primary service endpoint; on failure, automatically route to a secondary/backup.

### When to Use
- You have a primary and secondary (DR) endpoint for a critical service
- Active-passive failover between data centers or cloud regions
- The backup service has the same API contract

### Configuration / Code

```xml
<flow name="resilient-api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/customers/{id}"/>
    <try>
        <http:request config-ref="Primary_Service" path="/customers/#[attributes.uriParams.id]" method="GET"
                      responseTimeout="3000"/>
        <error-handler>
            <on-error-continue type="HTTP:TIMEOUT, HTTP:CONNECTIVITY, HTTP:INTERNAL_SERVER_ERROR">
                <logger level="WARN" message="Primary service failed, trying secondary"/>
                <try>
                    <http:request config-ref="Secondary_Service" path="/customers/#[attributes.uriParams.id]" method="GET"
                                  responseTimeout="5000"/>
                    <error-handler>
                        <on-error-propagate type="ANY">
                            <logger level="ERROR" message="Both services failed"/>
                            <set-variable variableName="httpStatus" value="503"/>
                            <set-payload value='{"error":"All service endpoints unavailable"}' mimeType="application/json"/>
                        </on-error-propagate>
                    </error-handler>
                </try>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Try the primary endpoint with a tight timeout (3s)
2. On failure, fall back to the secondary endpoint with a longer timeout (5s)
3. If both fail, return 503

### Gotchas
- The secondary timeout should be longer than the primary (the primary may have failed due to timeout)
- Both services must have the same API contract for transparent failover
- Consider using circuit breaker on the primary to avoid wasting time on a known-down service
- Log which service was used for troubleshooting

### Related
- [Cached Fallback](../cached-fallback/) — cache-based fallback
- [Circuit Breaker](../../retry/circuit-breaker-object-store/) — skip primary when known-down
