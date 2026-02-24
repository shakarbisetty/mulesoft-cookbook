## JWT Validation with JWKS
> Validate JWT tokens using a JSON Web Key Set endpoint for signature verification.

### When to Use
- APIs secured with JWTs from external identity providers (Okta, Auth0, Azure AD)
- Stateless token validation without calling the auth server per request
- Multi-provider setups where different APIs trust different issuers

### Configuration / Code

```yaml
policyRef:
  name: jwt-validation
configuration:
  jwksUrl: "https://login.microsoftonline.com/{tenantId}/discovery/v2.0/keys"
  issuer: "https://login.microsoftonline.com/{tenantId}/v2.0"
  audience: "api://my-api"
  skipClientIdValidation: true
  jwksCachingTtlInMinutes: 60
```

### How It Works
1. Gateway fetches the JWKS (public keys) from the configured URL
2. JWT signature is verified against the matching key (kid header)
3. Claims (iss, aud, exp, nbf) are validated per configuration
4. JWKS keys are cached to avoid per-request HTTP calls

### Gotchas
- JWKS URL must be accessible from the gateway — firewall rules needed for external IdPs
- Key rotation: when the IdP rotates keys, the gateway must refresh its cache
- `jwksCachingTtlInMinutes` controls cache duration — shorter = more IdP calls
- Clock skew tolerance is typically 30-60 seconds — some IdPs allow configuration

### Related
- [JWT Custom Claims](../custom-policies/jwt-custom-claims/) — custom claim validation
- [OAuth2 Enforcement](../oauth2-enforcement/) — OAuth2 token enforcement
