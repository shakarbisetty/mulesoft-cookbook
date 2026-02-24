## Flex Gateway HA Cluster
> Deploy multiple Flex Gateway replicas for high availability and load distribution.

### When to Use
- Production environments requiring zero-downtime
- High-throughput APIs needing horizontal scaling
- Fault tolerance — surviving individual gateway failures

### Configuration / Code

**Kubernetes (ReplicaSet):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flex-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flex-gateway
  template:
    metadata:
      labels:
        app: flex-gateway
    spec:
      containers:
      - name: flex-gateway
        image: mulesoft/flex-gateway:1.6
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: "1"
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: flex-gateway
spec:
  type: LoadBalancer
  selector:
    app: flex-gateway
  ports:
  - port: 443
    targetPort: 8081
```

### How It Works
1. Multiple gateway replicas register with the same Anypoint organization
2. Kubernetes Service load-balances across replicas
3. Each replica independently enforces policies
4. If one replica fails, traffic routes to healthy replicas

### Gotchas
- Rate limiting with multiple replicas requires distributed counters (Redis or shared storage)
- All replicas must run the same gateway version during rolling updates
- Pod anti-affinity rules prevent co-locating replicas on the same node
- Session affinity (sticky sessions) conflicts with even load distribution

### Related
- [K8s Ingress](../k8s-ingress/) — ingress controller setup
- [Distributed Redis Rate Limiting](../../rate-limiting/distributed-redis/) — distributed counters
