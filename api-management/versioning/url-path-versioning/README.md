## URL Path Versioning
> Version APIs using the URL path (e.g., /api/v1/orders, /api/v2/orders).

### When to Use
- Most common API versioning strategy
- Clear version visibility in URLs
- Multiple versions running simultaneously

### Configuration / Code

```xml
<!-- Version 1 -->
<flow name="orders-v1">
    <http:listener config-ref="HTTP_Listener" path="/api/v1/orders"/>
    <flow-ref name="orders-v1-logic"/>
</flow>

<!-- Version 2 -->
<flow name="orders-v2">
    <http:listener config-ref="HTTP_Listener" path="/api/v2/orders"/>
    <flow-ref name="orders-v2-logic"/>
</flow>
```

**API Manager routing:**
```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: orders-api-v1
spec:
  address: http://0.0.0.0:8081
  services:
    orders-v1:
      address: http://orders-v1-service:8080
      routes:
      - rules:
        - path: /api/v1/orders(/.*)?
    orders-v2:
      address: http://orders-v2-service:8080
      routes:
      - rules:
        - path: /api/v2/orders(/.*)?
```

### How It Works
1. Each version has its own URL path prefix (/v1, /v2)
2. Gateway or router directs traffic to the correct backend version
3. Both versions can run simultaneously during migration
4. Clients explicitly choose which version to call

### Gotchas
- URL versioning breaks REST purists (version is not part of the resource identity)
- Maintaining multiple versions increases operational burden
- Limit to 2-3 active versions maximum — deprecate aggressively
- Version numbers should be integers (v1, v2) not semver (v1.2.3)

### Related
- [Header Versioning](../header-versioning/) — version via headers
- [Deprecation Sunset](../deprecation-sunset/) — version retirement
