## CORS Configuration
> Configure Cross-Origin Resource Sharing for browser-based API consumers.

### When to Use
- SPAs or web apps calling APIs from a different domain
- Preflight requests (OPTIONS) need handling at the gateway
- Restricting which origins can access your API

### Configuration / Code

```yaml
policyRef:
  name: cors
configuration:
  allowedOrigins:
  - "https://app.example.com"
  - "https://staging.example.com"
  allowedMethods: ["GET", "POST", "PUT", "DELETE"]
  allowedHeaders: ["Content-Type", "Authorization", "X-Correlation-ID"]
  exposedHeaders: ["X-RateLimit-Remaining"]
  maxAge: 86400
  allowCredentials: true
```

### How It Works
1. Browser sends preflight OPTIONS request for cross-origin calls
2. Gateway responds with allowed origins, methods, and headers
3. If the origin matches, the browser proceeds with the actual request
4. `maxAge` caches preflight responses to reduce OPTIONS calls

### Gotchas
- `allowedOrigins: ["*"]` with `allowCredentials: true` is invalid per spec
- Missing CORS headers cause opaque browser errors — check network tab
- OPTIONS requests count toward rate limits — consider excluding them
- Mobile apps and server-to-server calls do not need CORS

### Related
- [Header Injection](../custom-policies/header-injection/) — custom header management
- [OAuth2 Enforcement](../oauth2-enforcement/) — auth with CORS
