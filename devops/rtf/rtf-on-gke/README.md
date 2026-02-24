## RTF on Google GKE
> Deploy Runtime Fabric on Google GKE with Workload Identity and Autopilot

### When to Use
- You run Kubernetes on Google Cloud GKE
- You want Workload Identity for secure GCP service integration
- You prefer GKE Autopilot for reduced cluster management overhead

### Configuration

**Terraform for GKE cluster**
```hcl
resource "google_container_cluster" "rtf" {
  name     = "mulesoft-rtf-gke"
  location = var.region

  # Remove default node pool and use custom ones
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network    = var.vpc_network
  subnetwork = var.subnet

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "controllers" {
  name       = "rtf-controllers"
  cluster    = google_container_cluster.rtf.id
  node_count = 2

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    labels = {
      "node-role" = "rtf-controller"
    }

    taint {
      key    = "rtf-controller"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "google_container_node_pool" "workers" {
  name    = "rtf-workers"
  cluster = google_container_cluster.rtf.id

  autoscaling {
    min_node_count = 2
    max_node_count = 10
  }

  node_config {
    machine_type = "e2-standard-8"
    disk_size_gb = 200
    disk_type    = "pd-ssd"

    labels = {
      "node-role" = "rtf-worker"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# Workload Identity binding
resource "google_service_account" "rtf" {
  account_id   = "rtf-agent"
  display_name = "RTF Agent Service Account"
}

resource "google_service_account_iam_member" "rtf_wi" {
  service_account_id = google_service_account.rtf.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[rtf/rtf-agent]"
}
```

**rtf-values-gke.yaml**
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
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: rtf-agent@${PROJECT_ID}.iam.gserviceaccount.com

persistence:
  enabled: true
  storageClass: "premium-rwo"
  size: 50Gi

ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "rtf-ip"
    networking.gke.io/managed-certificates: "rtf-cert"

workerDefaults:
  nodeSelector:
    node-role: rtf-worker
```

**deploy-rtf-gke.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="my-gcp-project"
CLUSTER_NAME="mulesoft-rtf-gke"
REGION="us-central1"
RTF_NAMESPACE="rtf"

echo "=== Deploying RTF on GKE ==="

# Get GKE credentials
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region "$REGION" --project "$PROJECT_ID"

# Install RTF
helm repo add rtf https://anypoint.mulesoft.com/accounts/api/v2/helm
helm repo update

kubectl create namespace "$RTF_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm install rtf rtf/rtf-agent \
    --namespace "$RTF_NAMESPACE" \
    --values rtf-values-gke.yaml \
    --set global.muleLicense="$(base64 -w0 license.lic)" \
    --set global.activationData="$RTF_ACTIVATION_DATA" \
    --wait --timeout 15m

echo "RTF deployed on GKE."
kubectl get pods -n "$RTF_NAMESPACE"
```

### How It Works
1. GKE private cluster keeps nodes off the public internet; only the API server is reachable
2. Workload Identity maps Kubernetes service accounts to GCP service accounts (no key files)
3. Controller node pool is tainted for exclusive RTF agent use
4. Worker node pool auto-scales based on Mule application deployment demands
5. GKE-managed certificates (via `ManagedCertificate` CRD) handle TLS automatically

### Gotchas
- Private clusters need Cloud NAT for outbound internet (required for Anypoint connectivity)
- Workload Identity requires the GKE metadata server; ensure `GKE_METADATA` mode is set
- `premium-rwo` StorageClass uses SSD persistent disks; `standard-rwo` uses HDD (slower)
- GKE Autopilot can be used instead of Standard, but some RTF features may need adjustments
- Regional clusters (multi-zone) cost more but provide higher availability

### Related
- [rtf-on-eks](../rtf-on-eks/) — AWS EKS equivalent
- [rtf-on-aks](../rtf-on-aks/) — Azure AKS equivalent
- [rtf-resource-sizing](../rtf-resource-sizing/) — Sizing guide
