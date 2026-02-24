## Flex Gateway as Kubernetes Ingress Controller
> Deploy Flex Gateway as a K8s Ingress controller to manage API traffic natively.

### When to Use
- Kubernetes-native API management without external load balancers
- Applying MuleSoft policies to K8s services
- Unified ingress with API governance

### Configuration / Code

**Helm install:**
```bash
helm repo add flex-gateway https://flex-packages.anypoint.mulesoft.com/helm
helm install my-gateway flex-gateway/flex-gateway \
  --set registration.token=$REGISTRATION_TOKEN \
  --set registeredName=my-flex-gw \
  --namespace api-gateway --create-namespace
```

**Ingress resource:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-api
  annotations:
    kubernetes.io/ingress.class: flex-gateway
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /api/orders
        pathType: Prefix
        backend:
          service:
            name: orders-service
            port:
              number: 8080
```

### How It Works
1. Flex Gateway registers with Anypoint Platform on startup
2. Ingress resources route traffic to backend K8s services
3. API Manager policies are applied at the gateway level
4. TLS termination happens at the ingress controller

### Gotchas
- Registration token expires — generate a fresh one for each install
- Flex Gateway needs outbound connectivity to Anypoint control plane
- `pathType: Prefix` matches all sub-paths — use `Exact` for strict matching
- Resource limits on the gateway pod affect throughput

### Related
- [Sidecar Pod](../sidecar-pod/) — per-pod gateway deployment
- [Docker Standalone](../docker-standalone/) — non-K8s deployment
