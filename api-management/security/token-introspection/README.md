## Token Introspection (Opaque Tokens)
> Validate opaque (non-JWT) tokens by calling the authorization server introspection endpoint.

### When to Use
- Authorization server issues opaque tokens (not self-contained JWTs)
- You need real-time token validity checks (immediate revocation support)
- Legacy OAuth implementations using reference tokens

### Configuration / Code

```yaml
policyRef:
  name: token-introspection
configuration:
  introspectionUrl: "https://auth.example.com/oauth2/introspect"
  clientId: "${introspection.client_id}"
  clientSecret: "${introspection.client_secret}"
  tokenCaching:
    enabled: true
    ttl: 30
```

### How It Works
1. Client sends an opaque token in the Authorization header
2. Gateway calls the introspection endpoint to validate the token
3. Introspection response includes active status, scopes, and claims
4. Caching reduces introspection calls (at the cost of delayed revocation)

### Gotchas
- Every request triggers an introspection call (without caching) — significant latency
- Introspection endpoint is a single point of failure — ensure high availability
- Cache TTL must balance performance vs. revocation responsiveness
- Introspection credentials must be stored securely (not in policy YAML)

### Related
- [OAuth2 Enforcement](../oauth2-enforcement/) — self-contained token validation
- [OpenID Connect](../openid-connect/) — OIDC integration
