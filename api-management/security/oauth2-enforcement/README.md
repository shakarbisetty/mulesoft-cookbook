## OAuth 2.0 Token Enforcement
> Validate OAuth 2.0 access tokens at the gateway using Anypoint Platform as the provider.

### When to Use
- Securing APIs with OAuth 2.0 bearer tokens
- Centralized token validation via Anypoint Platform
- Extracting client and user context from tokens

### Configuration / Code

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
    <logger message="Client: #[attributes.headers.x-client-id] | Scopes: #[attributes.headers.x-scopes]"/>
    <set-payload value="#[output application/json --- {data: protected
