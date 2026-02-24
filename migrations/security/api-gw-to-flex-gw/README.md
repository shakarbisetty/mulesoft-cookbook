## Mule API Gateway to Flex Gateway
> Migrate from embedded Mule API Gateway to Anypoint Flex Gateway

### When to Use
- Consolidating API gateway to a lightweight, standalone gateway
- Need gateway for non-Mule backends (Node.js, Spring Boot, etc.)
- Want Kubernetes-native API gateway with Envoy
- Reducing Mule runtime overhead for simple proxy use cases

### Configuration / Code

#### 1. Install Flex Gateway

```bash
# Docker
docker pull mulesoft/flex-gateway:latest

# Register with Anypoint Platform
docker run --entrypoint flexctl \
    -v "$(pwd)":/registration mulesoft/flex-gateway \
    registration create --token=<registration-token> \
    --organization=<org-id> \
    --connected=true \
    --output-directory=/registration \
    my-flex-gateway

# Run in Connected mode
docker run -d \
    -v "$(pwd)":/usr/local/share/mulesoft/flex-gateway/conf.d \
    -p 8080:8080 \
    mulesoft/flex-gateway
```

#### 2. Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flex-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flex-gateway
  template:
    spec:
      containers:
        - name: flex-gateway
          image: mulesoft/flex-gateway:latest
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: config
              mountPath: /usr/local/share/mulesoft/flex-gateway/conf.d
      volumes:
        - name: config
          configMap:
            name: flex-gateway-config
```

#### 3. API Instance Configuration (YAML)

```yaml
# api-instance.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: customer-api
spec:
  address: http://0.0.0.0:8080
  services:
    upstream:
      address: https://backend.example.com
      protocol: https
  policies:
    - policyRef:
        name: rate-limiting
      config:
        rateLimits:
          - maximumRequests: 100
            timePeriodInMilliseconds: 60000
    - policyRef:
        name: http-basic-authentication
      config:
        username: admin
        password: "${secure::api.password}"
```

#### 4. Policy Mapping

| Mule Gateway Policy | Flex Gateway Equivalent |
|---|---|
| Client ID Enforcement | client-id-enforcement |
| Rate Limiting | rate-limiting / rate-limiting-sla |
| JWT Validation | jwt-validation |
| Basic Auth | http-basic-authentication |
| IP Allowlist | ip-allowlist |
| Header Injection | message-logging + custom |
| CORS | cors |

### How It Works
1. Flex Gateway is built on Envoy Proxy with MuleSoft management
2. It runs standalone (not embedded in Mule runtime)
3. Policies are applied via YAML configuration or API Manager
4. Connected mode syncs config from Anypoint Platform; Local mode uses local YAML

### Migration Checklist
- [ ] Inventory all APIs on Mule API Gateway
- [ ] Map applied policies to Flex Gateway equivalents
- [ ] Install and register Flex Gateway
- [ ] Create API instances for each migrating API
- [ ] Apply policies via YAML or API Manager
- [ ] Test all policy enforcement
- [ ] Update DNS/load balancer to point to Flex Gateway
- [ ] Decommission old Mule proxy applications

### Gotchas
- Custom Mule policies must be rewritten as Flex Gateway policies (different format)
- Flex Gateway does not execute Mule flows - it is a pure proxy/gateway
- Some advanced Mule policies have no Flex equivalent yet
- Connected mode requires outbound internet to Anypoint Platform

### Related
- [mule3-gateway-policies](../../runtime-upgrades/mule3-gateway-policies/) - Legacy policy migration
- [platform-permissions](../platform-permissions/) - Access control
