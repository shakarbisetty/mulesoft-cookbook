## OAuth 2.0 Token Enforcement
> Validate OAuth 2.0 access tokens at the gateway using Anypoint Platform as the provider.

### When to Use
- Securing APIs with OAuth 2.0 bearer tokens
- Centralized token validation via Anypoint Platform
- Extracting client and user context from tokens

### Configuration / Code

**Flex Gateway policy (YAML):**
```yaml
policyRef:
  name: oauth2-access-token-enforcement
configuration:
  scopes: "read write"
  scopeValidationCriteria: "AND"
  exposeHeaders: true
  tokenUrl: "https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token"
```

**Mule 4 flow receiving validated token info:**
```xml
<flow name="protected-api">
    <http:listener config-ref="HTTP_Listener" path="/api/resources"/>
    <!-- Token already validated by gateway policy -->
    <logger message="#['Client: ' ++ attributes.headers.'x-client-id' ++ ' | Scopes: ' ++ attributes.headers.'x-scopes']"/>
    <set-payload value='#[output application/json --- {
        data: "protected resource content",
        client: attributes.headers."x-client-id",
        scopes: attributes.headers."x-scopes" splitBy " "
    }]'/>
</flow>
```

**Custom scope enforcement within the flow:**
```xml
<sub-flow name="enforce-write-scope">
    <choice>
        <when expression="#[attributes.headers.'x-scopes' contains 'write']">
            <logger message="Write access granted" level="DEBUG"/>
        </when>
        <otherwise>
            <raise-error type="APP:FORBIDDEN" description="Insufficient scope: 'write' required"/>
        </otherwise>
    </choice>
</sub-flow>
```

### How It Works
1. Flex Gateway applies the `oauth2-access-token-enforcement` policy before the request reaches Mule
2. The policy validates the bearer token against the configured token URL
3. `scopeValidationCriteria: "AND"` requires ALL listed scopes to be present
4. When `exposeHeaders: true`, gateway injects `x-client-id`, `x-scopes`, and `x-user-id` headers
5. The Mule flow receives pre-validated requests with client context in headers
6. Custom scope enforcement can add fine-grained checks within specific sub-flows
7. Invalid tokens receive 401 from the gateway — the Mule app never sees them

### Gotchas
- Use `AND` for scope criteria when the API requires multiple permissions simultaneously
- `exposeHeaders: true` adds latency (~5ms) but provides critical client context
- Token validation adds one round-trip to the provider — cache tokens at the gateway to reduce this
- Anypoint Platform token URL differs by region — use the correct URL for EU/US
- Test with expired, revoked, and malformed tokens — not just valid ones

### Related
- [JWT Validation with JWKS](../jwt-validation-jwks/) — local JWT validation without provider round-trip
- [mTLS Client Certificate](../mtls-client-cert/) — certificate-based authentication
- [OpenID Connect](../openid-connect/) — extending OAuth with identity claims
