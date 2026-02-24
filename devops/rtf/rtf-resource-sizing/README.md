## RTF Resource Sizing Guide
> CPU, memory, and replica sizing recommendations for Runtime Fabric workloads

### When to Use
- You are planning RTF cluster capacity for a new deployment
- You need to right-size Mule application resources to optimize cost and performance
- You want guidelines for scaling replicas based on traffic patterns

### Configuration

**Sizing reference table**

| Workload Type | vCores (Request) | vCores (Limit) | Memory (Request) | Memory (Limit) | Replicas |
|---|---|---|---|---|---|
| Lightweight API proxy | 0.1 | 0.5 | 512Mi | 1Gi | 2 |
| Standard API (CRUD) | 0.5 | 1.0 | 1Gi | 2Gi | 2-3 |
| Heavy integration (batch) | 1.0 | 2.0 | 2Gi | 4Gi | 2 |
| High-throughput API | 0.5 | 2.0 | 1Gi | 2Gi | 3-5 |
| Batch processing | 2.0 | 4.0 | 4Gi | 8Gi | 1 |

**Node sizing reference**

| Node Role | Instance Type (AWS) | Instance Type (Azure) | Instance Type (GCP) | Count |
|---|---|---|---|---|
| RTF Controller | m6i.xlarge (4 vCPU, 16GB) | Standard_D4s_v5 | e2-standard-4 | 2 (min) |
| RTF Worker (standard) | m6i.2xlarge (8 vCPU, 32GB) | Standard_D8s_v5 | e2-standard-8 | 3+ |
| RTF Worker (heavy) | m6i.4xlarge (16 vCPU, 64GB) | Standard_D16s_v5 | e2-standard-16 | 2+ |

**Kubernetes resource manifest for a standard API**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: mule-apps
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: mule
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
          readinessProbe:
            httpGet:
              path: /health
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: 8081
            initialDelaySeconds: 60
            periodSeconds: 15
            failureThreshold: 5
          startupProbe:
            httpGet:
              path: /health
              port: 8081
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 30  # 150s max startup
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: order-api
```

**HorizontalPodAutoscaler for traffic-based scaling**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-api-hpa
  namespace: mule-apps
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 120
```

**Capacity planning formula**
```
Total worker vCPUs needed = SUM(app_vcores_limit * app_replicas) * 1.3 (30% headroom)
Total worker memory needed = SUM(app_memory_limit * app_replicas) * 1.3

Example:
  5 APIs × 1.0 vCores × 3 replicas = 15 vCPUs
  15 vCPUs × 1.3 headroom = 19.5 vCPUs → 3 × m6i.2xlarge (8 vCPU each = 24 vCPUs)

  5 APIs × 2Gi × 3 replicas = 30Gi
  30Gi × 1.3 headroom = 39Gi → 3 × m6i.2xlarge (32GB each = 96GB available)
```

### How It Works
1. **Requests** guarantee minimum resources; the scheduler uses requests for placement decisions
2. **Limits** cap maximum resources; exceeding CPU limits causes throttling, memory limits cause OOM kills
3. **Replicas** provide horizontal scaling and redundancy; minimum 2 for production
4. **HPA** scales replicas based on CPU/memory utilization with controlled scale-up/down behavior
5. **Topology spread** ensures replicas are distributed across nodes for fault tolerance
6. **30% headroom** accounts for JVM garbage collection overhead and traffic spikes

### Gotchas
- Setting CPU limits too low causes throttling and increased latency; monitor `container_cpu_cfs_throttled_seconds_total`
- Memory limits must account for JVM metaspace (~200MB) on top of heap
- Mule apps have slow startup (30-60s); set `startupProbe` to avoid premature kills
- HPA scale-down is intentionally slow (5 min stabilization) to prevent thrashing
- Do not over-provision: unused resources waste money; under-provision: apps get OOM killed
- RTF controller nodes should NOT run Mule apps — use taints and node selectors

### Related
- [rtf-on-eks](../rtf-on-eks/) — EKS deployment
- [rtf-on-aks](../rtf-on-aks/) — AKS deployment
- [rtf-on-gke](../rtf-on-gke/) — GKE deployment
- [custom-metrics-micrometer](../../observability/custom-metrics-micrometer/) — Custom metrics for HPA
