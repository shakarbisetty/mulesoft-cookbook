## JWT Custom Claims Validation
> Validate custom JWT claims beyond standard fields for fine-grained authorization.

### When to Use
- Role-based access control using JWT claims
- Multi-tenant APIs where the tenant ID is in the token
- Enforcing custom business rules at the gateway

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: jwt-claims-check
spec:
  targetRef:
    name: orders-api
  policyRef:
    name: jwt-validation
  config:
    jwksUrl: https://auth.example.com/.well-known/jwks.json
    claimValidations:
    - claim: roles
      values: ["admin", "order-manager"]
    - claim: tenant_id
      required: true
    - claim: aud
      values: ["orders-api"]
    skipClientIdValidation: false
```

### How It Works
1. Gateway validates the JWT signature using the JWKS endpoint
2. Standard claims (exp, iss, aud) are validated first
3. Custom claims (roles, tenant_id) are checked against the policy config
4. Missing or invalid claims result in 401 Unauthorized

### Gotchas
- JWKS endpoint must be accessible from the gateway — cache keys to avoid latency
- Array claims (roles) use "any match" logic — any listed value satisfies the check
- Clock skew between auth server and gateway can cause valid tokens to be rejected
- Custom claim names must exactly match the JWT field names (case-sensitive)

### Related
- [JWT Validation JWKS](../../security/jwt-validation-jwks/) — standard JWT validation
- [OAuth2 Enforcement](../../security/oauth2-enforcement/) — OAuth2 policy
