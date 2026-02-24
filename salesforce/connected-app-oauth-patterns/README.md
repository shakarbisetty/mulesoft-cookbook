## Connected App OAuth Patterns
> OAuth 2.0 flows for Salesforce: Client Credentials, JWT Bearer, and refresh token rotation

### When to Use
- Connecting Mule applications to Salesforce using secure, token-based authentication
- Server-to-server integrations (no user present) requiring Client Credentials or JWT Bearer
- User-facing integrations needing refresh token management
- Migrating from username-password authentication to OAuth (Salesforce is deprecating password-based flows)

### Configuration / Code

**Pattern 1: Client Credentials Flow (Server-to-Server)**

Best for: Headless integrations, batch jobs, system-to-system.

```xml
<!-- Salesforce Connector Configuration: Client Credentials -->
<salesforce:sfdc-config name="Salesforce_Client_Credentials"
    doc:name="Salesforce - Client Credentials">
    <salesforce:oauth-client-credentials-connection
        consumerKey="${sf.consumer.key}"
        consumerSecret="${sf.consumer.secret}"
        tokenUrl="${sf.token.url}">
        <!-- Production: https://login.salesforce.com/services/oauth2/token -->
        <!-- Sandbox:    https://test.salesforce.com/services/oauth2/token -->
    </salesforce:oauth-client-credentials-connection>
</salesforce:sfdc-config>
```

Connected App setup for Client Credentials:
1. Setup > App Manager > New Connected App
2. Enable OAuth, add scopes: `api`, `refresh_token`
3. Under **Client Credentials Flow**, set the **Run As** user (this user's permissions apply)
4. Under **OAuth Policies**, set **Permitted Users** to "Admin approved users are pre-authorized"
5. Assign a Permission Set or Profile to the Connected App

**Pattern 2: JWT Bearer Token Flow (Certificate-Based)**

Best for: CI/CD pipelines, high-security environments, no secret rotation needed.

```xml
<!-- Salesforce Connector Configuration: JWT Bearer -->
<salesforce:sfdc-config name="Salesforce_JWT_Bearer"
    doc:name="Salesforce - JWT Bearer">
    <salesforce:oauth-jwt-connection
        consumerKey="${sf.consumer.key}"
        keyStorePath="${sf.keystore.path}"
        storePassword="${sf.keystore.password}"
        certificateAlias="${sf.cert.alias}"
        principal="${sf.username}"
        tokenUrl="${sf.token.url}"
        audienceUrl="${sf.audience.url}"/>
    <!-- audienceUrl: https://login.salesforce.com (prod) or https://test.salesforce.com (sandbox) -->
</salesforce:sfdc-config>
```

**Certificate Setup for JWT Bearer:**

```bash
# 1. Generate a private key and self-signed certificate
openssl req -x509 -sha256 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout server.key \
    -out server.crt \
    -subj "/CN=MuleSoftIntegration"

# 2. Create a Java keystore (JKS) from the key and cert
openssl pkcs12 -export \
    -in server.crt \
    -inkey server.key \
    -out keystore.p12 \
    -name mule-cert \
    -passout pass:changeit

keytool -importkeystore \
    -srckeystore keystore.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass changeit \
    -destkeystore keystore.jks \
    -deststoretype JKS \
    -deststorepass changeit

# 3. Upload server.crt to the Connected App in Salesforce
#    (Setup > App Manager > Edit Connected App > Use Digital Signatures)
```

Connected App setup for JWT:
1. Create Connected App with OAuth enabled
2. Check **Use Digital Signatures** and upload `server.crt`
3. Add scopes: `api`, `refresh_token`
4. Pre-authorize the user's profile
5. The Mule connector signs a JWT with the private key, Salesforce validates with the uploaded cert

**Pattern 3: Authorization Code with Refresh Token Rotation**

Best for: User-facing apps, interactive Salesforce access on behalf of a user.

```xml
<!-- Salesforce Connector Configuration: Auth Code + Refresh Token -->
<salesforce:sfdc-config name="Salesforce_Auth_Code"
    doc:name="Salesforce - Auth Code">
    <salesforce:oauth-user-pass-connection
        consumerKey="${sf.consumer.key}"
        consumerSecret="${sf.consumer.secret}"
        username="${sf.username}"
        password="${sf.password}"
        securityToken="${sf.security.token}"
        tokenUrl="${sf.token.url}"/>
</salesforce:sfdc-config>

<!-- Preferred: OAuth with automatic token management -->
<salesforce:sfdc-config name="Salesforce_Managed_Token"
    doc:name="Salesforce - Managed OAuth">
    <salesforce:cached-token-connection
        consumerKey="${sf.consumer.key}"
        consumerSecret="${sf.consumer.secret}"
        tokenUrl="${sf.token.url}"
        accessToken="${sf.access.token}"
        refreshToken="${sf.refresh.token}">
    </salesforce:cached-token-connection>
</salesforce:sfdc-config>
```

**Token Refresh Error Handling**

```xml
<flow name="sf-operation-with-token-refresh">
    <try>
        <salesforce:query config-ref="Salesforce_Managed_Token">
            <salesforce:salesforce-query>
                SELECT Id, Name FROM Account LIMIT 10
            </salesforce:salesforce-query>
        </salesforce:query>
    </try>
    <error-handler>
        <on-error-continue
            type="SALESFORCE:INVALID_SESSION"
            logException="true">
            <logger level="WARN"
                message="Session expired, connector will auto-refresh token"/>
            <!-- The Salesforce connector automatically refreshes the token.
                 If the refresh token itself is expired, this error propagates. -->
        </on-error-continue>
    </error-handler>
</flow>
```

**Property Configuration (Secure Properties)**

```yaml
# src/main/resources/config-prod.yaml
sf:
  consumer:
    key: "${secure::sf.consumer.key}"
    secret: "${secure::sf.consumer.secret}"
  token:
    url: "https://login.salesforce.com/services/oauth2/token"
  audience:
    url: "https://login.salesforce.com"
  keystore:
    path: "keystore.jks"
    password: "${secure::sf.keystore.password}"
  cert:
    alias: "mule-cert"
  username: "${secure::sf.username}"

# src/main/resources/config-sandbox.yaml
sf:
  token:
    url: "https://test.salesforce.com/services/oauth2/token"
  audience:
    url: "https://test.salesforce.com"
```

### How It Works

**Client Credentials Flow**
1. Mule sends `grant_type=client_credentials` with consumer key and secret to the token URL
2. Salesforce validates the credentials and returns an access token
3. The connector caches the token and auto-refreshes on expiry
4. All API calls run as the "Run As" user configured in the Connected App

**JWT Bearer Flow**
1. Mule builds a JWT with issuer (consumer key), subject (Salesforce username), and audience (login URL)
2. The JWT is signed with the private key from the keystore
3. Salesforce validates the signature using the certificate uploaded to the Connected App
4. If valid, Salesforce returns an access token (no refresh token, since a new JWT can be created anytime)
5. No secret is transmitted over the wire — only the signed assertion

**Refresh Token Flow**
1. The initial authorization code exchange produces an access token + refresh token
2. The Salesforce connector uses the access token for API calls
3. When the access token expires, the connector automatically uses the refresh token to obtain a new one
4. If refresh token rotation is enabled, each refresh returns a new refresh token (the old one is invalidated)

### Gotchas
- **JWT clock skew tolerance is 5 minutes**: The JWT `exp` and `iat` claims must be within 5 minutes of Salesforce server time. If your Mule server clock drifts, JWT auth fails with `invalid_grant`. Use NTP synchronization
- **Refresh token expiry**: Refresh tokens expire based on the Connected App's session policy (default: never expire, but can be set to hours/days). If expired, the user must re-authorize
- **Sandbox vs production URLs**: Using `login.salesforce.com` for a sandbox org or `test.salesforce.com` for production silently fails. Externalize the token URL in environment-specific properties
- **Client Credentials requires pre-authorization**: The "Run As" user must have a profile or permission set assigned to the Connected App. Without this, you get `invalid_grant` with no helpful error message
- **IP restrictions**: Connected Apps can be locked to IP ranges. If your Mule runtime's IP changes (e.g., CloudHub restart), authentication fails. Use "Relax IP restrictions" for CI/CD environments
- **Token storage in CloudHub**: Access tokens are cached in memory. On CloudHub worker restart, the token is lost and re-acquired automatically. With JWT, this is seamless. With refresh tokens, ensure the refresh token is persisted externally

### Related
- [Agentforce Mule Action Registration](../agentforce-mule-action-registration/)
- [Salesforce Invalid Session Recovery](../../error-handling/connector-errors/salesforce-invalid-session/)
- [Bidirectional Sync & Conflict Resolution](../bidirectional-sync-conflict-resolution/)
