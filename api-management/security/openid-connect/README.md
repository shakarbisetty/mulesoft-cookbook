## OpenID Connect Integration
> Authenticate users via OIDC and extract identity claims at the gateway.

### When to Use
- User-facing APIs requiring user identity (not just client identity)
- SSO integration with enterprise identity providers
- Extracting user profile information from ID tokens

### Configuration / Code

```yaml
policyRef:
  name: openid-connect-access-token-enforcement
configuration:
  openIdProvider:
    issuer: "https://accounts.google.com"
    jwksUrl: "https://www.googleapis.com/oauth2/v3/certs"
    tokenEndpoint: "https://oauth2.googleapis.com/token"
    authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth"
  scopes: "openid profile email"
  tokenCaching: true
  cacheTtl: 300
```

### How It Works
1. Client authenticates with the OIDC provider and gets an ID token + access token
2. Request includes the access token in the Authorization header
3. Gateway validates the token using the OIDC provider JWKS
4. User claims (sub, email, name) are extracted and forwarded to the backend

### Gotchas
- OIDC discovery URL (`.well-known/openid-configuration`) must be accessible
- ID tokens and access tokens serve different purposes — validate the right one
- Token caching reduces IdP calls but delays revocation detection
- OIDC adds complexity over plain JWT — use only when you need user identity

### Related
- [JWT Validation JWKS](../jwt-validation-jwks/) — JWT validation
- [Token Introspection](../token-introspection/) — opaque token validation
