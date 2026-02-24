## RTF on Amazon EKS
> Deploy Runtime Fabric agent on Amazon EKS with Helm and IAM roles

### When to Use
- You run Kubernetes on AWS EKS and want to use RTF for Mule deployments
- You need IAM Roles for Service Accounts (IRSA) for secure AWS integration
- You want a production-ready EKS cluster sized for Mule workloads

### Configuration

**eksctl cluster config (eks-cluster.yaml)**
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: mulesoft-rtf
  region: us-east-2
  version: "1.29"

iam:
  withOIDC: true

managedNodeGroups:
  - name: rtf-controllers
    instanceType: m6i.xlarge
    desiredCapacity: 2
    minSize: 2
    maxSize: 3
    labels:
      node-role: rtf-controller
    taints:
      - key: rtf-controller
        value: "true"
        effect: NoSchedule
    volumeSize: 100
    volumeType: gp3
    iam:
      withAddonPolicies:
        ebs: true
        efs: true

  - name: rtf-workers
    instanceType: m6i.2xlarge
    desiredCapacity: 3
    minSize: 2
    maxSize: 10
    labels:
      node-role: rtf-worker
    volumeSize: 200
    volumeType: gp3
    iam:
      withAddonPolicies:
        ebs: true

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
```

**rtf-values-eks.yaml — Helm values for EKS**
```yaml
global:
  organizationId: "${ANYPOINT_ORG_ID}"
  activationData: ""  # Injected at install time

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
    node-role: rtf-controller
  tolerations:
    - key: "rtf-controller"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

persistence:
  enabled: true
  storageClass: "gp3"
  size: 50Gi

ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "${ACM_CERT_ARN}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: /healthz

workerDefaults:
  nodeSelector:
    node-role: rtf-worker
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

**deploy-rtf-eks.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="mulesoft-rtf"
REGION="us-east-2"
RTF_NAMESPACE="rtf"

echo "=== Deploying RTF on EKS ==="

# Step 1: Create EKS cluster (if not exists)
if ! eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null; then
    echo "Creating EKS cluster..."
    eksctl create cluster -f eks-cluster.yaml
fi

# Step 2: Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName="$CLUSTER_NAME" \
    --set serviceAccount.create=true

# Step 3: Install EBS CSI driver StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF

# Step 4: Install RTF
helm repo add rtf https://anypoint.mulesoft.com/accounts/api/v2/helm
helm repo update

kubectl create namespace "$RTF_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm install rtf rtf/rtf-agent \
    --namespace "$RTF_NAMESPACE" \
    --values rtf-values-eks.yaml \
    --set global.muleLicense="$(base64 -w0 license.lic)" \
    --set global.activationData="$RTF_ACTIVATION_DATA" \
    --wait --timeout 15m

echo "RTF deployed on EKS. Verifying..."
kubectl get pods -n "$RTF_NAMESPACE"
```

### How It Works
1. EKS cluster uses managed node groups: controllers for RTF agent, workers for Mule apps
2. Controller nodes are tainted to prevent Mule workloads from running on them
3. AWS ALB Ingress Controller provides internet-facing load balancing with ACM certificates
4. GP3 StorageClass provides persistent storage for the RTF agent
5. IRSA (IAM Roles for Service Accounts) eliminates the need for static AWS credentials

### Gotchas
- RTF requires at minimum 2 controller nodes (4 vCPU, 8GB each) and 1 worker node
- EKS managed node groups handle OS patching; use Launch Templates for custom AMIs
- The ALB Ingress Controller must be installed before RTF for ingress to work
- RTF activation data expires after 24 hours; generate it just before installation
- EBS volumes are AZ-specific; PVCs can only be used by pods in the same AZ

### Related
- [rtf-on-aks](../rtf-on-aks/) — Azure AKS equivalent
- [rtf-on-gke](../rtf-on-gke/) — Google GKE equivalent
- [rtf-resource-sizing](../rtf-resource-sizing/) — Sizing guide
- [helm-rtf](../../infrastructure/helm-rtf/) — Helm values reference
