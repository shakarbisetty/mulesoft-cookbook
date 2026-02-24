## Mutual TLS (mTLS) Client Certificate Authentication
> Require client certificates for API access with certificate pinning.

### When to Use
- B2B integrations requiring mutual authentication
- Zero-trust network environments
- Replacing or supplementing API keys with certificates

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: mtls-policy
spec:
  targetRef:
    name: partner-api
  policyRef:
    name: tls-inbound
  config:
    requireClientCertificate: true
    trustedCA: /etc/ssl/certs/partner-ca.pem
    certificateValidation: CHAIN
    extractClientDN: true
```

**Flex Gateway TLS config:**
```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: partner-api
spec:
  address: https://0.0.0.0:8443
  tls:
    certificate:
      key: /etc/ssl/private/server.key
      crt: /etc/ssl/certs/server.crt
    clientCertificate:
      ca: /etc/ssl/certs/partner-ca.pem
```

### How It Works
1. Server presents its certificate to the client (standard TLS)
2. Client presents its certificate to the server (mutual TLS)
3. Gateway validates the client cert against the trusted CA
4. Client DN is extracted and available for authorization decisions

### Gotchas
- Certificate management is complex — automate rotation with cert-manager
- Expired client certs cause connection failures, not 401 errors (TLS handshake fails)
- CRL (Certificate Revocation List) checking adds latency — use OCSP stapling
- Load balancers may terminate TLS — configure TLS passthrough mode

### Related
- [OAuth2 Enforcement](../oauth2-enforcement/) — token-based auth
- [API Key Management](../api-key-management/) — simpler auth mechanism
