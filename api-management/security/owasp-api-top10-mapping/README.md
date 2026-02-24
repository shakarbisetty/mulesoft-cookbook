## OWASP API Security Top 10 Mapping
> Map every OWASP API Security Top 10 risk to its MuleSoft mitigation with concrete policy configurations.

### When to Use
- Starting a new API security review and need a checklist of controls
- Building a security compliance matrix for audit or governance reporting
- Onboarding a team to API security best practices in MuleSoft
- Evaluating which Anypoint Platform policies cover which threat categories

### OWASP API Security Top 10 — MuleSoft Mitigation Matrix

| # | OWASP Risk | MuleSoft Policy / Feature | Configuration |
|---|-----------|--------------------------|---------------|
| API1 | **Broken Object Level Authorization (BOLA)** | Custom policy + DataWeave authorization logic | Validate resource ownership in each flow before returning data |
| API2 | **Broken Authentication** | OAuth 2.0 / OpenID Connect / JWT Validation policy | JWKS endpoint, token expiry, rate limiting on auth endpoints |
| API3 | **Broken Object Property Level Authorization** | Response filtering policy + DataWeave field masking | Strip fields based on client scope / role claims |
| API4 | **Unrestricted Resource Consumption** | Rate Limiting / Spike Control / SLA-based policies | Tiered rate limits per client ID, payload size limits |
| API5 | **Broken Function Level Authorization (BFLA)** | Resource-level policy + method-level access control | Apply policies per resource/method, RBAC via scopes |
| API6 | **Unrestricted Access to Sensitive Business Flows** | Rate limiting + CAPTCHA integration + bot detection | Throttle sensitive endpoints (account creation, purchase) |
| API7 | **Server Side Request Forgery (SSRF)** | HTTP Requester URL allowlist + input validation | Restrict outbound URLs to known hosts, block private IP ranges |
| API8 | **Security Misconfiguration** | API Manager automated policies + Anypoint Security | TLS enforcement, CORS lockdown, remove debug headers |
| API9 | **Improper Inventory Management** | API Manager + Exchange + API Catalog CLI | Discover and catalog all APIs, flag shadow/zombie APIs |
| API10 | **Unsafe Consumption of APIs** | Outbound mTLS + certificate pinning + response validation | Validate upstream responses, enforce TLS 1.2+ outbound |

### Configuration / Code

#### API1 — BOLA Prevention (Object-Level Authorization)

The platform cannot enforce BOLA protection via policy alone. You must add authorization logic in each flow that verifies the requesting user owns the resource.

```xml
<flow name="get-order-by-id">
    <http:listener config-ref="api-httpListenerConfig" path="/orders/{orderId}" method="GET"/>

    <!-- Extract authenticated user from JWT -->
    <set-variable variableName="authenticatedUserId"
                  value="#[attributes.headers.authorization
                    replace /^Bearer\s+/ with ''
                    then payload.sub]"/>

    <!-- Fetch the order -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT * FROM orders WHERE order_id = :orderId</db:sql>
        <db:input-parameters><![CDATA[#[{ orderId: attributes.uriParams.orderId }]]]></db:input-parameters>
    </db:select>

    <!-- Enforce ownership -->
    <choice>
        <when expression="#[payload[0].user_id != vars.authenticatedUserId]">
            <raise-error type="SECURITY:UNAUTHORIZED"
                         description="User does not own this resource"/>
        </when>
    </choice>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload[0]]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### API2 — Broken Authentication (JWT + Rate Limiting)

Apply JWT validation with JWKS rotation and rate-limit login endpoints to prevent brute force.

```xml
<!-- JWT Validation policy applied via API Manager or inline -->
<mule-xml-proxy:validate-jwt
    config-ref="JWT_Config"
    jwksUrl="https://auth.example.com/.well-known/jwks.json"
    expectedAudience="https://api.example.com"
    expectedIssuer="https://auth.example.com"
    cacheTtl="300"
    cacheTtlUnit="SECONDS"/>
```

Rate Limiting policy (applied via API Manager to `/login` resource):

```yaml
# Anypoint Platform - Rate Limiting Policy
rateLimiting:
  maximumRequests: 5
  timePeriodInMilliseconds: 60000
  clusterizable: true
  exposeHeaders: true
  pointcutData:
    - methodRegex: POST
      uriTemplateRegex: /login
```

#### API4 — Unrestricted Resource Consumption

```yaml
# SLA-based Rate Limiting policy
slaBasedRateLimiting:
  tiers:
    - name: Free
      limits:
        - maximumRequests: 100
          timePeriodInMilliseconds: 3600000
    - name: Premium
      limits:
        - maximumRequests: 10000
          timePeriodInMilliseconds: 3600000
  # Payload size limit via HTTP listener
  maxPayloadSize: 1048576  # 1 MB
```

### How It Works
1. **Identify applicable risks** — review each API endpoint against the Top 10 list
2. **Layer platform policies** — apply rate limiting, JWT validation, and CORS via API Manager
3. **Add application-level controls** — BOLA checks, field filtering, and input validation in Mule flows
4. **Enforce outbound security** — mTLS and URL allowlists for upstream API consumption
5. **Catalog and monitor** — use API Manager and Exchange to track all API inventory and flag unmanaged endpoints
6. **Audit regularly** — map policy coverage back to this matrix during security reviews

### Gotchas
- **Policies alone do not solve design flaws** — BOLA and BFLA require application-level logic; no policy can automatically verify resource ownership
- **Layered defense is required** — a single policy rarely covers a full OWASP risk; combine platform policies with flow-level controls
- **API9 (Improper Inventory)** is organizational, not technical — you need process and tooling to discover shadow APIs
- **Policy ordering matters** — authentication must run before authorization; rate limiting should run early to protect downstream processing
- **Testing gaps** — security scanning tools may not understand Mule-specific policy configurations; supplement with manual penetration testing

### Related
- [JWT Validation with JWKS](../jwt-validation-jwks/)
- [OAuth 2.0 Enforcement](../oauth2-enforcement/)
- [Broken Authentication Prevention](../broken-authentication-prevention/)
- [Excessive Data Exposure](../excessive-data-exposure/)
- [Injection Prevention](../injection-prevention/)
- [Zero Trust with Flex Gateway](../zero-trust-flex-gateway/)
- [CORS Configuration](../cors-config/)
