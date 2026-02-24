## Local Mode YAML Configuration
> Define APIs, policies, and routing entirely through declarative YAML CRDs.

### When to Use
- GitOps-driven API management
- Air-gapped or edge deployments without Anypoint connectivity
- CI/CD pipelines managing gateway configuration as code

### Configuration / Code

```yaml
# api-instance.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: products-api
spec:
  address: http://0.0.0.0:8081
  services:
    products:
      address: http://products-backend:8080
      routes:
        - rules:
          - path: /api/v1/products(/.*)?
            methods: [GET, POST, PUT, DELETE]
          config:
            destinationPath: /products

---
# rate-limit-policy.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: products-rate-limit
spec:
  targetRef:
    name: products-api
  policyRef:
    name: rate-limiting
  config:
    rateLimits:
    - maximumRequests: 100
      timePeriodInMilliseconds: 60000
```

### How It Works
1. YAML files are placed in the gateway config directory
2. Gateway watches for file changes and applies configs automatically
3. `ApiInstance` defines routing; `PolicyBinding` attaches policies
4. Multiple YAML files can reference the same ApiInstance

### Gotchas
- YAML schema validation errors cause the entire file to be rejected
- File naming does not matter — gateway reads all `.yaml` files in the config dir
- Removing a file removes the corresponding API/policy (declarative, not additive)
- Test YAML changes in a staging gateway before applying to production

### Related
- [Connected vs Local](../connected-vs-local/) — mode comparison
- [Custom Policies](../../custom-policies/rust-wasm-policy/) — custom WASM policies
