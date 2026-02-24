## Broken Authentication Prevention
> Harden API authentication with JWT rotation, session management, brute-force protection, and token revocation.

### When to Use
- Implementing or hardening authentication for APIs exposed via Anypoint Platform
- Protecting login and token endpoints from brute-force and credential-stuffing attacks
- Setting up JWT key rotation with JWKS endpoints
- Adding token refresh flows with revocation list checks

### Configuration / Code

#### JWT Validation with JWKS Endpoint Rotation

The JWKS endpoint serves multiple keys identified by `kid`. Rotate keys by publishing a new key to JWKS before retiring the old one.

```xml
<flow name="jwt-validated-flow">
    <http:listener config-ref="api-httpListenerConfig" path="/api/v1/*" method="GET"/>

    <!-- Validate JWT with JWKS rotation support -->
    <http:request method="GET" config-ref="JWKS_Request_Config"
                  path="/.well-known/jwks.json"
                  target="jwksResponse"
                  targetValue="#[payload]"/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
import * from dw::core::Binaries
import * from dw::Crypto

var token = attributes.headers.authorization replace /^Bearer\s+/ with ''
var parts = token splitBy "."
var header = fromBase64(parts[0]) as String {encoding: "UTF-8"} read "application/json"
var tokenKid = header.kid

// Select the matching key from JWKS by kid
var matchingKey = (vars.jwksResponse.keys filter ($.kid == tokenKid))[0]
---
{
    kid: tokenKid,
    keyFound: matchingKey != null,
    algorithm: header.alg
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice>
        <when expression="#[!payload.keyFound]">
            <raise-error type="SECURITY:UNAUTHORIZED"
                         description="JWT kid not found in JWKS — key may have been rotated out"/>
        </when>
    </choice>

    <!-- Proceed with validated request -->
</flow>
```

#### JWKS Key Rotation Strategy

```
Timeline for safe JWKS key rotation:

Day 0:  Publish new key (kid=key-2) to JWKS alongside old key (kid=key-1)
Day 1:  Start issuing new tokens with kid=key-2
Day 7:  All tokens with kid=key-1 have expired (assuming 24h max token lifetime + buffer)
Day 8:  Remove kid=key-1 from JWKS endpoint

JWKS cache TTL on Mule side should be < token lifetime to pick up new keys promptly.
```

#### Rate Limiting on Login Endpoints (Brute-Force Protection)

```xml
<!-- Apply via API Manager or as a custom policy on /login and /token -->
<flow name="login-flow">
    <http:listener config-ref="api-httpListenerConfig" path="/login" method="POST"
                   allowedMethods="POST"/>

    <!-- Rate limit: 5 attempts per minute per client IP -->
    <os:retrieve key="#['login-attempts:' ++ attributes.remoteAddress]"
                 objectStore="rateLimitStore"
                 target="attemptCount">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <choice>
        <when expression="#[vars.attemptCount as Number >= 5]">
            <set-payload value='{"error": "Too many login attempts. Try again later."}'
                         mimeType="application/json"/>
            <set-variable variableName="httpStatus" value="429"/>
            <http:response statusCode="#[vars.httpStatus]">
                <http:headers><![CDATA[#[{
                    "Retry-After": "60",
                    "Content-Type": "application/json"
                }]]]></http:headers>
            </http:response>
        </when>
        <otherwise>
            <os:store key="#['login-attempts:' ++ attributes.remoteAddress]"
                      objectStore="rateLimitStore">
                <os:value>#[(vars.attemptCount as Number) + 1]</os:value>
            </os:store>
            <flow-ref name="authenticate-user"/>
        </otherwise>
    </choice>
</flow>

<!-- Object Store with TTL for sliding window -->
<os:object-store name="rateLimitStore"
                 entryTtl="60"
                 entryTtlUnit="SECONDS"
                 maxEntries="100000"
                 expirationInterval="30"
                 expirationIntervalUnit="SECONDS"/>
```

#### Token Refresh Flow with Revocation Check

```xml
<flow name="token-refresh-flow">
    <http:listener config-ref="api-httpListenerConfig" path="/token/refresh" method="POST"/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    refreshToken: payload.refresh_token,
    grantType: payload.grant_type
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Check revocation list (Object Store or DB) -->
    <os:contains key="#[payload.refreshToken]"
                 objectStore="revokedTokensStore"
                 target="isRevoked"/>

    <choice>
        <when expression="#[vars.isRevoked]">
            <raise-error type="SECURITY:UNAUTHORIZED"
                         description="Refresh token has been revoked"/>
        </when>
    </choice>

    <!-- Validate refresh token and issue new access + refresh tokens -->
    <http:request method="POST" config-ref="OAuth_Provider_Config"
                  path="/oauth/token">
        <http:body><![CDATA[#[output application/x-www-form-urlencoded
---
{
    grant_type: "refresh_token",
    refresh_token: payload.refreshToken,
    client_id: p('oauth.clientId'),
    client_secret: p('oauth.clientSecret')
}]]]></http:body>
    </http:request>

    <!-- Revoke the old refresh token (one-time use) -->
    <os:store key="#[vars.originalRefreshToken]"
              objectStore="revokedTokensStore">
        <os:value>revoked</os:value>
    </os:store>
</flow>

<!-- Revoked tokens store — TTL matches refresh token max lifetime -->
<os:object-store name="revokedTokensStore"
                 entryTtl="30"
                 entryTtlUnit="DAYS"
                 persistent="true"/>
```

#### Token Revocation on Logout

```xml
<flow name="logout-flow">
    <http:listener config-ref="api-httpListenerConfig" path="/logout" method="POST"/>

    <!-- Extract token jti (JWT ID) claim -->
    <set-variable variableName="tokenJti"
                  value="#[payload.jti default attributes.headers.authorization
                    replace /^Bearer\s+/ with ''
                    then ($ splitBy '.')[1]
                    then fromBase64($) as String {encoding: 'UTF-8'}
                    then ($ read 'application/json').jti]"/>

    <!-- Add to revocation list -->
    <os:store key="#[vars.tokenJti]"
              objectStore="revokedTokensStore">
        <os:value>#[now() as String]</os:value>
    </os:store>

    <set-payload value='{"message": "Logged out successfully"}'
                 mimeType="application/json"/>
</flow>
```

### How It Works
1. **JWT validation** uses the JWKS endpoint to fetch public keys; the `kid` header in the JWT selects which key to verify with
2. **Key rotation** overlaps old and new keys in the JWKS response, giving existing tokens time to expire before removing the old key
3. **Brute-force protection** uses an Object Store with TTL as a sliding window counter per client IP; blocks after threshold
4. **Token refresh** validates the refresh token, checks a revocation store, then issues a new token pair and revokes the spent refresh token
5. **Revocation list** uses a persistent Object Store (or database) with TTL matching the token's maximum lifetime; checked on every protected request

### Gotchas
- **JWT `kid` rotation timing** — if you remove the old key from JWKS before all issued tokens expire, valid tokens will fail validation; always overlap keys for at least one full token lifetime
- **JWKS cache TTL** — Mule caches HTTP responses; set the cache TTL lower than your key rotation window so new keys are picked up promptly (300 seconds is a reasonable default)
- **Stateless vs stateful sessions** — JWTs are stateless by design; adding a revocation list introduces state, which must be replicated across cluster nodes (use persistent Object Store or external cache)
- **Object Store limits** — CloudHub Object Stores have size limits; for high-traffic APIs, consider an external Redis or database for revocation lists
- **Refresh token reuse detection** — if a refresh token is used twice, it may indicate token theft; consider revoking the entire token family
- **IP-based rate limiting** — can be bypassed with distributed botnets; supplement with account-level rate limiting and CAPTCHA for repeated failures

### Related
- [JWT Validation with JWKS](../jwt-validation-jwks/)
- [OAuth 2.0 Enforcement](../oauth2-enforcement/)
- [OpenID Connect](../openid-connect/)
- [Token Introspection](../token-introspection/)
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
