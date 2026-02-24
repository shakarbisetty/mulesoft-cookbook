## Flex Gateway as Sidecar
> Deploy Flex Gateway as a sidecar container in each pod for per-service policy enforcement.

### When to Use
- Per-service mTLS and policy enforcement
- Service mesh alternative with MuleSoft governance
- Isolating gateway failures to individual services

### Configuration / Code

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-service
spec:
  template:
    spec:
      containers:
      - name: app
        image: orders-service:1.0
        ports:
        - containerPort: 8080
      - name: flex-gateway
        image: mulesoft/flex-gateway:1.6
        env:
        - name: FLEX_RTM_ARM_AUTH_TOKEN
          valueFrom:
            secretKeyRef:
              name: flex-credentials
              key: token
        ports:
        - containerPort: 8081
```

### How It Works
1. Flex Gateway runs alongside the app container in the same pod
2. Traffic enters through the sidecar port (8081), policies are applied, then forwarded to app (8080)
3. Each pod gets independent policy enforcement
4. Sidecar shares the pod network namespace — localhost communication

### Gotchas
- Doubles resource consumption per pod (CPU/memory for sidecar)
- Each sidecar needs its own registration — use automation
- Health checks must account for sidecar readiness
- Sidecar restarts do not restart the app container (and vice versa)

### Related
- [K8s Ingress](../k8s-ingress/) — centralized ingress approach
- [HA Cluster](../ha-cluster/) — high availability setup
