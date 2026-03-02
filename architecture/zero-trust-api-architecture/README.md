## Zero-Trust API Architecture
> mTLS everywhere, token validation chains, and least-privilege access for MuleSoft APIs

### When to Use
- Your APIs handle sensitive data (PII, financial, health) and "trust the network" is not acceptable
- You are deploying APIs across multiple environments (CloudHub, on-prem, partner networks) with no trusted perimeter
- Regulatory requirements (PCI-DSS, HIPAA, SOX) mandate encryption in transit and strong authentication at every hop
- You want to prevent lateral movement if one component in your integration is compromised

### The Problem

Traditional API security relies on perimeter defense: once traffic crosses the firewall or VPN, internal APIs trust it. This model fails when a single compromised service can access every internal API without authentication. In a MuleSoft API-led architecture with 50+ APIs, a compromised process API can call any system API in the network.

Zero trust means: verify every request at every layer, encrypt everything in transit, grant minimum required access, and assume every network is hostile — including internal networks.

### Configuration / Code

#### Zero-Trust Architecture Layers

```
┌──────────────────────────────────────────────────────────────────┐
│                     ZERO-TRUST API STACK                         │
│                                                                  │
│  Layer 5: AUDIT & MONITORING                                     │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Every request logged: who, what, when, from where          │  │
│  │ Anomaly detection on access patterns                       │  │
│  │ Real-time alerting on policy violations                    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 4: AUTHORIZATION (what can you do?)                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ OAuth 2.0 scopes per API endpoint                          │  │
│  │ RBAC: role-based access to API operations                  │  │
│  │ ABAC: attribute-based rules (department, region, time)     │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 3: AUTHENTICATION (who are you?)                          │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ JWT validation at EVERY API (not just the gateway)         │  │
│  │ Token introspection for opaque tokens                      │  │
│  │ Client certificate validation (mTLS)                       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 2: TRANSPORT ENCRYPTION                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ TLS 1.3 for all external communication                     │  │
│  │ mTLS for all internal API-to-API communication             │  │
│  │ Certificate rotation every 90 days                         │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Layer 1: NETWORK SEGMENTATION                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ VPC per environment (dev, staging, prod)                   │  │
│  │ Security groups: explicit allow-lists per API              │  │
│  │ No default "allow all internal" rules                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

#### mTLS Between API Layers

```
Traditional (TLS only — server authenticates to client):
  Client ──TLS──► Server
  Client identity: NOT verified by server (anyone can call)

Zero-Trust (mTLS — both sides authenticate):
  Client ──mTLS──► Server
  Client presents certificate ──► Server validates client cert
  Server presents certificate ──► Client validates server cert
  BOTH identities verified before data exchange
```

```
API-Led with mTLS at every hop:

  Consumer ──mTLS──► Experience API ──mTLS──► Process API ──mTLS──► System API
       │                    │                      │                    │
       │ Client cert:       │ Client cert:         │ Client cert:      │
       │ consumer-app.pem   │ exp-orders.pem       │ prc-orders.pem    │
       │                    │                      │                    │
       │ Each API validates │ Each API validates   │ Each API validates│
       │ the caller's cert  │ the caller's cert    │ the caller's cert │
       │ against its trust  │ against its trust    │ against its trust │
       │ store              │ store                │ store             │
```

#### mTLS Configuration in Mule

```xml
<!-- Server-side: require client certificate -->
<tls:context name="TLS_Server_mTLS">
    <tls:trust-store path="truststore.jks"
                     password="${tls.truststore.password}"
                     type="JKS" />
    <tls:key-store path="server-keystore.jks"
                   password="${tls.keystore.password}"
                   keyPassword="${tls.key.password}"
                   type="JKS" />
</tls:context>

<http:listener-config name="HTTPS_mTLS_Listener">
    <http:listener-connection host="0.0.0.0" port="8443"
                              tlsContext="TLS_Server_mTLS"
                              protocol="HTTPS" />
    <!-- useTls="true" is implicit with HTTPS protocol -->
</http:listener-config>

<!-- Client-side: present client certificate when calling other APIs -->
<tls:context name="TLS_Client_mTLS">
    <tls:trust-store path="truststore.jks"
                     password="${tls.truststore.password}"
                     type="JKS" />
    <tls:key-store path="client-keystore.jks"
                   password="${tls.client.keystore.password}"
                   keyPassword="${tls.client.key.password}"
                   type="JKS" />
</tls:context>

<http:request-config name="Process_API_Client">
    <http:request-connection host="prc-orders.cloudhub.io" port="443"
                             protocol="HTTPS"
                             tlsContext="TLS_Client_mTLS" />
</http:request-config>
```

#### JWT Validation at Every Layer

```xml
<!-- JWT validation policy — apply to EVERY API, not just the gateway -->
<flow name="orders-api-with-jwt">
    <http:listener config-ref="HTTPS_mTLS_Listener" path="/api/orders/*" />

    <!-- Validate JWT at THIS API (do not trust upstream validation) -->
    <flow-ref name="validate-jwt-token" />

    <!-- Check scopes for THIS specific operation -->
    <flow-ref name="check-authorization-scopes" />

    <apikit:router config-ref="orders-api-config" />
</flow>

<sub-flow name="validate-jwt-token">
    <!-- Extract token from Authorization header -->
    <set-variable variableName="authHeader"
                  value="#[attributes.headers.authorization default '']" />

    <choice>
        <when expression="#[vars.authHeader startsWith 'Bearer ']">
            <set-variable variableName="token"
                          value="#[vars.authHeader substringAfter 'Bearer ']" />

            <!-- Validate JWT signature, expiry, issuer, audience -->
            <http:request config-ref="OAuth_Provider"
                         path="/oauth/introspect"
                         method="POST">
                <http:body>#[%dw 2.0
output application/x-www-form-urlencoded
---
{ token: vars.token }]</http:body>
            </http:request>

            <choice>
                <when expression="#[payload.active != true]">
                    <raise-error type="APP:UNAUTHORIZED"
                                description="Invalid or expired token" />
                </when>
            </choice>

            <set-variable variableName="tokenClaims" value="#[payload]" />
        </when>
        <otherwise>
            <raise-error type="APP:UNAUTHORIZED"
                        description="Missing Authorization header" />
        </otherwise>
    </choice>
</sub-flow>

<sub-flow name="check-authorization-scopes">
    <!-- Check if token has required scope for this operation -->
    <set-variable variableName="requiredScope" value="#[%dw 2.0
output application/java
var method = attributes.method
var path = attributes.requestPath
---
if (method == 'GET') 'orders:read'
else if (method == 'POST') 'orders:write'
else if (method == 'DELETE') 'orders:admin'
else 'orders:read']" />

    <choice>
        <when expression="#[
            !(vars.tokenClaims.scope splitBy ' ' contains vars.requiredScope)
        ]">
            <raise-error type="APP:FORBIDDEN"
                        description="#['Insufficient scope. Required: ' ++
                        vars.requiredScope]" />
        </when>
    </choice>
</sub-flow>
```

#### Token Propagation Chain

```xml
<!-- When API A calls API B, propagate (or exchange) tokens -->
<sub-flow name="call-downstream-api-with-token">
    <!-- Option 1: Propagate the incoming token (if audience allows it) -->
    <http:request config-ref="Process_API_Client"
                 path="/api/inventory/#[vars.sku]"
                 method="GET">
        <http:headers>#[{
            'Authorization': 'Bearer ' ++ vars.token
        }]</http:headers>
    </http:request>

    <!-- Option 2: Exchange token for a new one with narrower scope (preferred) -->
    <!--
    <http:request config-ref="OAuth_Provider" path="/oauth/token" method="POST">
        <http:body>#[%dw 2.0
output application/x-www-form-urlencoded
- - -
{
    grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
    subject_token: vars.token,
    subject_token_type: "urn:ietf:params:oauth:token-type:access_token",
    scope: "inventory:read",
    audience: "sys-inventory-api"
}]</http:body>
    </http:request>
    -->
</sub-flow>
```

#### Least Privilege: Scope Matrix

| API | Read Scope | Write Scope | Admin Scope |
|-----|-----------|-------------|-------------|
| Experience - Orders | `orders:read` | `orders:write` | `orders:admin` |
| Process - Fulfillment | `fulfillment:execute` | - | `fulfillment:admin` |
| System - Inventory | `inventory:read` | `inventory:reserve` | `inventory:admin` |
| System - SAP | `sap:read` | `sap:write` | - |

```
Service-to-service scope assignments (least privilege):

  exp-orders (client) → scopes: orders:read, orders:write, fulfillment:execute
  prc-fulfillment (client) → scopes: inventory:read, inventory:reserve, sap:write
  sys-inventory (client) → scopes: (none — leaf node, does not call other APIs)

  An exp-orders client CANNOT call sys-inventory directly.
  It can only call prc-fulfillment, which then calls sys-inventory.
```

#### Security Headers

```xml
<!-- Add security headers to all responses -->
<sub-flow name="add-security-headers">
    <ee:transform>
        <ee:message>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
attributes ++ {
    headers: {
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Content-Security-Policy": "default-src 'none'",
        "Cache-Control": "no-store",
        "X-Request-Id": correlationId
    }
}]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</sub-flow>
```

#### Audit Logging

```xml
<!-- Log every API access for audit trail -->
<sub-flow name="audit-log-access">
    <logger level="INFO" message="#[%dw 2.0
output application/json
---
{
    event: 'API_ACCESS',
    timestamp: now(),
    requestId: correlationId,
    clientId: vars.tokenClaims.client_id default 'unknown',
    subject: vars.tokenClaims.sub default 'unknown',
    method: attributes.method,
    path: attributes.requestPath,
    sourceIp: attributes.remoteAddress,
    userAgent: attributes.headers.'user-agent' default 'unknown',
    responseStatus: attributes.statusCode default 200,
    scopes: vars.tokenClaims.scope default 'none'
}]" />
</sub-flow>
```

#### Zero-Trust Checklist

| Control | Implementation | Verify |
|---------|---------------|--------|
| Encrypt in transit | TLS 1.2+ on all listeners | `openssl s_client -connect` |
| Mutual authentication | mTLS between all API layers | Check `truststore.jks` includes only expected certs |
| Token validation | JWT validated at EVERY API, not just gateway | Disable gateway and test — API should still reject unauthenticated |
| Least privilege scopes | Each service has minimum required scopes | Audit token scope assignments quarterly |
| No implicit trust | Internal APIs require auth even on same VPC | Remove `Allow All` security group rules |
| Certificate rotation | Certs rotated every 90 days | Alerting on cert expiry (< 30 days) |
| Audit logging | Every access logged with identity, action, resource | Log shipped to SIEM, retention > 1 year |
| Secret management | No credentials in code or properties files | Use Anypoint Secure Properties or external vault |

### How It Works

1. **Network layer**: Segment APIs into VPCs with explicit security group rules. No "allow all internal."
2. **Transport layer**: Enable TLS on all listeners. Configure mTLS between API layers.
3. **Authentication layer**: Validate JWT/OAuth tokens at every API, not just the gateway.
4. **Authorization layer**: Check scopes per operation. Use least-privilege assignments.
5. **Audit layer**: Log every access with identity, action, resource, and outcome. Ship to SIEM.

### Gotchas

- **mTLS certificate management is operational overhead.** With 50 APIs, you have 50+ certificate pairs to manage, rotate, and distribute. Use a certificate management tool (HashiCorp Vault, AWS ACM) and automate rotation.
- **Token introspection adds latency.** Calling the OAuth provider on every request adds 10-50ms. Cache introspection results for short periods (30-60 seconds) using Object Store. Accept the trade-off between security and performance.
- **CloudHub DLB terminates TLS.** Traffic between the DLB and your Mule worker is HTTP (not HTTPS) inside the CloudHub VPC. If this is unacceptable, use RTF where you control the full network path.
- **API Manager policies are evaluated before your flow.** If you configure JWT validation both as an API Manager policy and in your flow, you validate twice. Choose one: policy for gateway-level validation, flow for zero-trust validation at every API.
- **Do not use API keys as the only authentication.** API keys are shared secrets that cannot be scoped, rotated easily, or tied to specific users. Use OAuth 2.0 client credentials for service-to-service and authorization code for user-facing flows.
- **Anypoint Secure Properties are decrypted at deploy time.** The decryption key must be stored securely (not in source control). In CloudHub, use the Secure Properties tab. In RTF, use Kubernetes secrets.

### Related

- [Rate Limiting Architecture](../rate-limiting-architecture/) — rate limiting as a security control
- [Multi-Region Active-Active Blueprint](../multi-region-active-active-blueprint/) — securing cross-region communication
- [Deployment Model Decision Matrix](../deployment-model-decision-matrix/) — security implications per deployment model
- [Circuit Breaker in MuleSoft](../circuit-breaker-mulesoft/) — fail-closed when auth services are down
