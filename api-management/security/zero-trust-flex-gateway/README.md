## Zero Trust with Flex Gateway
> Implement zero-trust API security with mTLS everywhere, service mesh authentication, and no implicit trust using Anypoint Flex Gateway.

### When to Use
- Deploying APIs in environments where the network perimeter cannot be trusted (cloud, hybrid, multi-cloud)
- Compliance requires mutual TLS for all service-to-service communication
- Migrating from perimeter-based security to zero-trust architecture
- Need both inbound mTLS (client certificate validation) and outbound mTLS (upstream service authentication)

### Configuration / Code

#### Flex Gateway — Inbound mTLS (Client Certificate Validation)

Clients must present a valid certificate signed by a trusted CA to access the API.

```yaml
# flex-gateway/inbound-mtls.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: orders-api
  namespace: production
spec:
  address: https://0.0.0.0:8443
  services:
    upstream:
      address: https://orders-service:8081
      tls:
        # Outbound mTLS to upstream (see outbound section below)
        certificate:
          secretName: upstream-client-cert
        trustedCA:
          secretName: upstream-ca-cert
  tls:
    # Inbound TLS — server certificate
    certificate:
      secretName: api-server-cert
    # Inbound mTLS — require client certificate
    clientValidation:
      mode: STRICT          # STRICT = reject if no valid client cert
      trustedCA:
        secretName: client-ca-cert
      # Optional: restrict to specific client cert subjects
      subjectAltNames:
        - "spiffe://cluster.local/ns/production/sa/mobile-app"
        - "spiffe://cluster.local/ns/production/sa/partner-service"
---
# TLS Secrets
apiVersion: v1
kind: Secret
metadata:
  name: api-server-cert
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-server-cert>
  tls.key: <base64-encoded-server-key>
---
apiVersion: v1
kind: Secret
metadata:
  name: client-ca-cert
  namespace: production
type: Opaque
data:
  ca.crt: <base64-encoded-client-ca-cert>
```

#### Flex Gateway — Outbound mTLS (Upstream Authentication)

Flex Gateway presents its own client certificate when connecting to upstream services.

```yaml
# flex-gateway/outbound-mtls.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: orders-api-outbound
  namespace: production
spec:
  address: https://0.0.0.0:8443
  services:
    upstream:
      address: https://backend-service.internal:8443
      tls:
        # Client certificate Flex Gateway presents to upstream
        certificate:
          secretName: upstream-client-cert
        # CA that signed the upstream server's certificate
        trustedCA:
          secretName: upstream-ca-cert
        # Enforce TLS 1.2+
        minVersion: "1.2"
        # Restrict cipher suites
        cipherSuites:
          - TLS_AES_256_GCM_SHA384
          - TLS_CHACHA20_POLY1305_SHA256
          - TLS_AES_128_GCM_SHA256
---
apiVersion: v1
kind: Secret
metadata:
  name: upstream-client-cert
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-flex-client-cert>
  tls.key: <base64-encoded-flex-client-key>
---
apiVersion: v1
kind: Secret
metadata:
  name: upstream-ca-cert
  namespace: production
type: Opaque
data:
  ca.crt: <base64-encoded-upstream-ca-cert>
```

#### Certificate Rotation Policy

```yaml
# flex-gateway/cert-rotation-policy.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: cert-rotation-monitoring
  namespace: production
spec:
  targetRef:
    kind: ApiInstance
    name: orders-api
  policyRef:
    name: tls-certificate-monitoring
  config:
    # Alert when certificates are within 30 days of expiry
    expiryWarningDays: 30
    # Logging for certificate events
    logLevel: INFO
    # Certificate metadata for tracking
    certificates:
      - name: api-server-cert
        type: server
        renewalMethod: cert-manager  # or manual
        rotationWindow: 30           # days before expiry to rotate
      - name: upstream-client-cert
        type: client
        renewalMethod: cert-manager
        rotationWindow: 30
      - name: client-ca-cert
        type: ca
        renewalMethod: manual
        rotationWindow: 90
```

#### Kubernetes cert-manager for Automated Rotation

```yaml
# cert-manager/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-server-cert
  namespace: production
spec:
  secretName: api-server-cert
  duration: 90d
  renewBefore: 30d
  isCA: false
  privateKey:
    algorithm: ECDSA
    size: 256
  usages:
    - server auth
  dnsNames:
    - api.example.com
    - "*.api.example.com"
  issuerRef:
    name: production-ca-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: upstream-client-cert
  namespace: production
spec:
  secretName: upstream-client-cert
  duration: 90d
  renewBefore: 30d
  isCA: false
  privateKey:
    algorithm: ECDSA
    size: 256
  usages:
    - client auth
  commonName: flex-gateway-client
  issuerRef:
    name: production-ca-issuer
    kind: ClusterIssuer
```

#### Zero Trust Network Policy (Kubernetes)

```yaml
# network-policy/deny-all-then-allow.yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Allow only Flex Gateway to reach backend services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-flex-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend-service
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: flex-gateway
      ports:
        - port: 8443
          protocol: TCP
---
# Allow Flex Gateway egress to backend and internet (for JWKS, etc.)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-flex-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: flex-gateway
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend-service
      ports:
        - port: 8443
          protocol: TCP
    - to:
        - namespaceSelector: {}  # Allow DNS resolution
      ports:
        - port: 53
          protocol: UDP
```

### How It Works
1. **Inbound mTLS** — Flex Gateway terminates TLS and validates the client certificate against a trusted CA; `mode: STRICT` rejects connections without a valid client cert
2. **Outbound mTLS** — Flex Gateway presents its own client certificate when connecting to upstream services, proving its identity to the backend
3. **Certificate management** — cert-manager automates issuance and rotation; certificates are renewed 30 days before expiry
4. **Network policies** — Kubernetes NetworkPolicy enforces that only Flex Gateway pods can reach backend services, even if mTLS is somehow bypassed
5. **No implicit trust** — every hop (client to gateway, gateway to backend) requires mutual authentication; network location alone grants no access

### Gotchas
- **Certificate expiry monitoring** — the most common zero-trust outage cause is an expired certificate; automate rotation and alert at least 30 days before expiry
- **Self-signed in dev vs CA-signed in prod** — never use self-signed certificates in production; in development, use a local CA (e.g., `mkcert` or cert-manager with a self-signed ClusterIssuer) to mirror production flows
- **CA pinning** — if you pin to a specific CA, rotating to a new CA requires coordinated updates across all services; prefer trusting an intermediate CA that can be re-issued under different roots
- **Certificate chain completeness** — clients and servers must send the full certificate chain (leaf + intermediates); missing intermediates cause "unknown authority" errors
- **Clock skew** — certificate validity depends on system clocks; ensure NTP is configured on all nodes, as even a few minutes of skew can cause certificate validation failures
- **Performance overhead** — mTLS adds a TLS handshake on every connection; use connection pooling and HTTP keep-alive to amortize the handshake cost
- **SPIFFE/SPIRE** — for large service meshes, consider SPIFFE identities instead of traditional X.509 certificates for more dynamic identity management

### Related
- [mTLS Client Certificate](../mtls-client-cert/)
- [JWT Validation with JWKS](../jwt-validation-jwks/)
- [WAF + Flex Gateway Integration](../waf-flex-gateway-integration/)
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
