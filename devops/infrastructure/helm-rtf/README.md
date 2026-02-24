## Helm Values for RTF Agent
> Custom Helm values for deploying and configuring the RTF agent on Kubernetes

### When to Use
- You use Runtime Fabric (RTF) for container-based Mule deployments
- You need to customize resource limits, node affinity, or persistence for the RTF agent
- You want version-controlled Helm values for repeatable RTF installations

### Configuration

**rtf-values.yaml**
```yaml
# RTF Agent Helm Values
# Ref: https://docs.mulesoft.com/runtime-fabric/latest/install-rtf-helm

global:
  muleLicense: ""  # Base64-encoded Mule license key (inject via --set)
  organizationId: "your-org-id-here"
  activationData: ""  # RTF activation data from Anypoint (inject via --set)

agent:
  replicas: 2
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

  nodeSelector:
    node-role.kubernetes.io/rtf-agent: "true"

  tolerations:
    - key: "rtf-agent"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - rtf-agent
            topologyKey: kubernetes.io/hostname

persistence:
  enabled: true
  storageClass: "gp3"
  accessMode: ReadWriteOnce
  size: 50Gi

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: rtf-tls
      hosts:
        - mule.example.com

monitoring:
  enabled: true
  prometheus:
    enabled: true
    port: 9090
    path: /metrics
  serviceMonitor:
    enabled: true
    interval: 30s
    namespace: monitoring

resources:
  muleWorker:
    defaults:
      cpu: "500m"
      cpuLimit: "1000m"
      memory: "1Gi"
      memoryLimit: "2Gi"
    production:
      cpu: "1000m"
      cpuLimit: "2000m"
      memory: "2Gi"
      memoryLimit: "4Gi"
```

**Install command**
```bash
# Add the RTF Helm repo
helm repo add rtf https://anypoint.mulesoft.com/accounts/api/v2/helm
helm repo update

# Install with custom values
helm install rtf rtf/rtf-agent \
    --namespace rtf \
    --create-namespace \
    --values rtf-values.yaml \
    --set global.muleLicense="$(base64 -w0 license.lic)" \
    --set global.activationData="$RTF_ACTIVATION_DATA" \
    --wait \
    --timeout 10m

# Upgrade with new values
helm upgrade rtf rtf/rtf-agent \
    --namespace rtf \
    --values rtf-values.yaml \
    --set global.muleLicense="$(base64 -w0 license.lic)" \
    --set global.activationData="$RTF_ACTIVATION_DATA" \
    --wait
```

**Verify installation**
```bash
# Check agent pods
kubectl get pods -n rtf -l app=rtf-agent

# Check RTF status in Anypoint
kubectl logs -n rtf -l app=rtf-agent --tail=50

# Verify persistence
kubectl get pvc -n rtf
```

### How It Works
1. The RTF Helm chart installs the agent that connects your K8s cluster to Anypoint Platform
2. Custom values control resource limits, node placement, and storage for the agent
3. Mule license and activation data are injected at install time (not stored in values file)
4. Pod anti-affinity spreads agent replicas across nodes for high availability
5. Prometheus ServiceMonitor enables metrics collection from the RTF agent

### Gotchas
- The activation data is a one-time token generated in Anypoint; store it securely
- RTF requires a minimum of 3 worker nodes (2 for HA, 1 for controller)
- Storage class must support `ReadWriteOnce`; network storage (EFS/NFS) can cause issues
- The Mule license must be Base64-encoded without line breaks (`base64 -w0`)
- RTF agent version must be compatible with your Anypoint org region (US, EU, or Gov)

### Related
- [rtf-on-eks](../../rtf/rtf-on-eks/) — RTF on Amazon EKS
- [rtf-on-aks](../../rtf/rtf-on-aks/) — RTF on Azure AKS
- [rtf-resource-sizing](../../rtf/rtf-resource-sizing/) — Sizing guide
