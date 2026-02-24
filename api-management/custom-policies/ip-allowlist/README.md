## IP Allowlist Policy
> Restrict API access to specific IP addresses or CIDR ranges.

### When to Use
- Backend APIs that should only accept traffic from known sources
- Partner integrations with fixed IP ranges
- Defense in depth alongside authentication

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: ip-allowlist
spec:
  targetRef:
    name: internal-api
  policyRef:
    name: ip-allowlist
  config:
    ips:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.1.100
    rejectMessage: "Access denied: IP not in allowlist"
    rejectStatusCode: 403
```

### How It Works
1. Gateway extracts the client IP from the request
2. IP is checked against the allowlist (exact match or CIDR range)
3. Matching IPs pass through; non-matching get 403 Forbidden
4. CIDR notation allows entire subnets

### Gotchas
- Behind a load balancer, use `X-Forwarded-For` header instead of direct IP
- IPv6 addresses need separate CIDR entries
- Allowlist changes require policy redeployment (or config reload in local mode)
- Do not rely solely on IP filtering for security — combine with authentication

### Related
- [JWT Custom Claims](../jwt-custom-claims/) — token-based access control
- [mTLS Client Cert](../../security/mtls-client-cert/) — certificate-based auth
