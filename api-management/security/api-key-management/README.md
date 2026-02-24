## API Key Management
> Issue and validate API keys for simple client identification and rate limiting.

### When to Use
- Simple API access control without OAuth complexity
- Public APIs with usage tracking per consumer
- Internal APIs where key-based auth is sufficient

### Configuration / Code

```yaml
policyRef:
  name: client-id-enforcement
configuration:
  credentialsOrigin: customExpression
  clientIdExpression: "#[attributes.headers.x-api-key]"
  clientSecretExpression: "#[attributes.headers.x-api-secret]"
```

**Client registration in API Manager:**
```
1. Create an API instance in API Manager
2. Client requests access → receives client_id + client_secret
3. Client passes credentials in headers on every request
4. Gateway validates credentials against registered clients
```

### How It Works
1. Clients register through API Manager and receive credentials
2. Each request includes the API key in the configured header
3. Gateway validates the key against registered client applications
4. Invalid or missing keys return 401 Unauthorized

### Gotchas
- API keys are not encrypted in transit by default — always use HTTPS
- Keys should be rotated periodically — API Manager supports key regeneration
- API keys identify the client, not the user — do not use for user-level auth
- Rate limiting can be applied per API key using SLA tiers

### Related
- [OAuth2 Enforcement](../oauth2-enforcement/) — stronger authentication
- [SLA Tiers](../rate-limiting/sla-tiers/) — rate limiting per client
