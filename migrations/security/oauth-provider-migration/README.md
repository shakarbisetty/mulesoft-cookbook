## OAuth Provider Module Migration
> Migrate OAuth Provider configuration across Mule versions

### When to Use
- Upgrading Mule runtime with OAuth Provider module
- Moving OAuth token management to external IdP
- Need to support OAuth 2.0 with PKCE or other modern flows

### Configuration / Code

#### 1. Mule 4 OAuth Provider Configuration

```xml
<oauth2-provider:config name="OAuth2_Provider"
    listenerConfig="HTTP_Listener"
    resourceOwnerSecurityProvider="resourceOwnerProvider"
    clientSecurityProvider="clientProvider"
    supportedGrantTypes="AUTHORIZATION_CODE,CLIENT_CREDENTIALS"
    scopes="read,write,admin">
    <oauth2-provider:client-store>
        <oauth2-provider:client
            clientId="myapp"
            secret="${secure::oauth.client.secret}"
            type="CONFIDENTIAL"
            redirectUris="https://myapp.example.com/callback" />
    </oauth2-provider:client-store>
    <oauth2-provider:token-config
        path="/token"
        tokenStore="tokenObjectStore"
        tokenTtl="3600"
        tokenTtlTimeUnit="SECONDS" />
    <oauth2-provider:authorization-config
        path="/authorize"
        loginPage="login.html" />
</oauth2-provider:config>
```

#### 2. Migrate to External IdP (Recommended)

```xml
<!-- Replace embedded OAuth provider with external IdP validation -->
<http:request-config name="IdP_Config">
    <http:request-connection host="idp.example.com" port="443"
        protocol="HTTPS" />
</http:request-config>

<!-- Token introspection -->
<flow name="validateToken">
    <http:request config-ref="IdP_Config"
        method="POST" path="/oauth/introspect">
        <http:body>#[output application/x-www-form-urlencoded
            --- { token: attributes.headers.Authorization replace "Bearer " with "" }]
        </http:body>
        <http:headers>#[{
            'Authorization': 'Basic ' ++ (vars.clientId ++ ':' ++ vars.clientSecret)
                as Binary {encoding: "UTF-8"} as String {format: "base64"}
        }]</http:headers>
    </http:request>
</flow>
```

#### 3. JWT Validation Policy (API Manager)

```yaml
# Apply via API Manager instead of embedded provider
policyRef:
  name: jwt-validation
config:
  jwtOrigin: httpBearerAuthenticationHeader
  signingMethod: rsa
  signingKeyLength: 256
  jwtKeyOrigin: jwks
  jwksUrl: https://idp.example.com/.well-known/jwks.json
  jwksServiceConnectionTimeout: 10000
  skipClientIdValidation: false
  clientIdExpression: "#[vars.claimSet.client_id]"
  validateAudClaim: true
  mandatoryAudClaim: true
  supportedAudiences: "https://api.example.com"
```

### How It Works
1. Embedded OAuth providers are being replaced by external IdPs (Okta, Auth0, PingFederate)
2. APIs validate tokens via JWT validation or token introspection
3. API Manager policies handle token validation at the gateway level
4. External IdPs provide better scalability, SSO, and security features

### Migration Checklist
- [ ] Inventory all APIs using embedded OAuth provider
- [ ] Choose external IdP (Okta, Auth0, PingFederate, etc.)
- [ ] Register API clients in the external IdP
- [ ] Configure JWT validation or token introspection
- [ ] Update API consumers with new token endpoints
- [ ] Apply policies via API Manager
- [ ] Remove embedded OAuth provider module
- [ ] Test all OAuth flows

### Gotchas
- Existing access tokens become invalid after migration
- Client IDs and secrets must be recreated in the new IdP
- Redirect URIs must be re-registered
- Token format may change (opaque vs JWT)
- Scope names may need alignment between old and new systems

### Related
- [api-gw-to-flex-gw](../api-gw-to-flex-gw/) - Gateway migration
- [credentials-to-secure-props](../credentials-to-secure-props/) - Credential security
- [platform-permissions](../platform-permissions/) - Access control
