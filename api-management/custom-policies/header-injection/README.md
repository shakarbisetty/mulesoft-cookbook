## Header Injection Policy
> Add, remove, or modify HTTP headers at the gateway layer.

### When to Use
- Adding correlation IDs to all requests
- Injecting authentication headers for backend services
- Removing sensitive headers before returning responses

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: header-injection
spec:
  targetRef:
    name: orders-api
  policyRef:
    name: header-injection
  config:
    inboundHeaders:
    - key: X-Correlation-ID
      value: "#[java.util.UUID.randomUUID()]"
    - key: X-Gateway-Timestamp
      value: "#[now()]"
    outboundHeaders:
    - key: X-Powered-By
      action: remove
    - key: X-Response-Time
      value: "#[attributes.headers.X-Gateway-Timestamp]"
```

### How It Works
1. `inboundHeaders` are added/modified on the request going to the backend
2. `outboundHeaders` are added/modified/removed on the response to the client
3. `action: remove` strips headers (useful for hiding server info)
4. Expressions can generate dynamic values (UUIDs, timestamps)

### Gotchas
- Header names are case-insensitive in HTTP/1.1 but case-sensitive in HTTP/2
- Removing `Server` and `X-Powered-By` headers is a security best practice
- Injected headers increase request size — keep it minimal
- Dynamic expressions add slight processing overhead

### Related
- [DataWeave Transform](../dataweave-transform/) — full body transformation
- [IP Allowlist](../ip-allowlist/) — access control
