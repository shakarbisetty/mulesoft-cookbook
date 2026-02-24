## RTF on Azure AKS
> Deploy Runtime Fabric on Azure AKS with managed identity and Azure CNI

### When to Use
- You run Kubernetes on Azure AKS and want MuleSoft RTF
- You need Azure Managed Identity integration for zero-credential operations
- You want Azure-native networking (Azure CNI) for pod-level VNet integration

### Configuration

**Terraform for AKS cluster (main.tf)**
```hcl
resource "azurerm_kubernetes_cluster" "rtf" {
  name                = "mulesoft-rtf-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "mulesoft-rtf"
  kubernetes_version  = "1.29"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "controllers"
    vm_size             = "Standard_D4s_v5"
    node_count          = 2
    min_count           = 2
    max_count           = 3
    enable_auto_scaling = true
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
    vnet_subnet_id      = var.subnet_id

    node_labels = {
      "node-role" = "rtf-controller"
    }

    node_taints = [
      "rtf-controller=true:NoSchedule"
    ]
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_id
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.rtf.id
  vm_size               = "Standard_D8s_v5"
  node_count            = 3
  min_count             = 2
  max_count             = 10
  enable_auto_scaling   = true
  os_disk_size_gb       = 200
  vnet_subnet_id        = var.subnet_id

  node_labels = {
    "node-role" = "rtf-worker"
  }
}

resource "azurerm_user_assigned_identity" "rtf" {
  name                = "rtf-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}
```

**rtf-values-aks.yaml**
```yaml
global:
  organizationId: "${ANYPOINT_ORG_ID}"

agent:
  replicas: 2
  nodeSelector:
    node-role: rtf-controller
  tolerations:
    - key: "rtf-controller"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

persistence:
  enabled: true
  storageClass: "managed-premium"
  size: 50Gi

ingress:
  enabled: true
  className: "azure-application-gateway"
  annotations:
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/health-probe-path: /healthz
    appgw.ingress.kubernetes.io/backend-protocol: "http"

workerDefaults:
  nodeSelector:
    node-role: rtf-worker
```

**deploy-rtf-aks.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="mulesoft-rg"
CLUSTER_NAME="mulesoft-rtf-aks"
RTF_NAMESPACE="rtf"

echo "=== Deploying RTF on AKS ==="

# Get AKS credentials
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"

# Install AGIC (Application Gateway Ingress Controller) if needed
helm repo add application-gateway-kubernetes-ingress \
    https://appgwithub.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# Install RTF
helm repo add rtf https://anypoint.mulesoft.com/accounts/api/v2/helm
helm repo update

kubectl create namespace "$RTF_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm install rtf rtf/rtf-agent \
    --namespace "$RTF_NAMESPACE" \
    --values rtf-values-aks.yaml \
    --set global.muleLicense="$(base64 -w0 license.lic)" \
    --set global.activationData="$RTF_ACTIVATION_DATA" \
    --wait --timeout 15m

echo "RTF deployed on AKS."
kubectl get pods -n "$RTF_NAMESPACE"
```

### How It Works
1. AKS cluster uses Azure CNI for direct VNet integration — pods get IPs from the VNet subnet
2. Managed Identity eliminates Azure credential management for the cluster
3. Controller node pool is tainted to reserve nodes exclusively for the RTF agent
4. Worker node pool auto-scales based on Mule application demand
5. Azure Application Gateway Ingress Controller (AGIC) provides Layer 7 load balancing with WAF

### Gotchas
- Azure CNI requires a large enough subnet — each pod consumes a VNet IP address
- Managed Premium storage is required for production; Standard LRS may cause I/O issues
- AGIC requires a pre-provisioned Application Gateway resource in the same VNet
- AKS auto-scaling can take 3-5 minutes; set minimum node counts for baseline capacity
- RTF requires outbound internet access for Anypoint connectivity; configure NAT Gateway or Azure Firewall

### Related
- [rtf-on-eks](../rtf-on-eks/) — AWS EKS equivalent
- [rtf-on-gke](../rtf-on-gke/) — Google GKE equivalent
- [rtf-resource-sizing](../rtf-resource-sizing/) — Sizing guide
