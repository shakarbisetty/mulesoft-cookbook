## CloudHub to Runtime Fabric Migration
> Migrate Mule applications from CloudHub to Anypoint Runtime Fabric for self-managed Kubernetes

### When to Use
- Need to run Mule runtime on your own Kubernetes cluster
- Data residency requirements prevent using MuleSoft-managed infrastructure
- Want full control over infrastructure while keeping Anypoint Platform management
- Running on AWS EKS, Azure AKS, or Google GKE

### Configuration / Code

#### 1. Install Runtime Fabric

```bash
# Install RTF controller on Kubernetes cluster
# Download activation script from Anypoint Platform > Runtime Manager > Runtime Fabric

# Prerequisites check
kubectl version --client
helm version

# Install via Helm
helm repo add rtf https://anypoint.mulesoft.com/runtimefabric/helm
helm repo update

helm install runtime-fabric rtf/rtf-agent \
    --namespace rtf \
    --create-namespace \
    --set activationData="${RTF_ACTIVATION_DATA}" \
    --set muleLicense="${MULE_LICENSE_KEY}"
```

#### 2. Deploy Application to RTF

```xml
<!-- pom.xml RTF deployment -->
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.1.1</version>
    <configuration>
        <runtimeFabricDeployment>
            <uri>https://anypoint.mulesoft.com</uri>
            <muleVersion>4.6.0</muleVersion>
            <target>my-rtf-cluster</target>
            <environment>Production</environment>
            <replicas>2</replicas>
            <publicUrl>my-api.example.com</publicUrl>
            <provider>MC</provider>
            <applicationName>my-api</applicationName>
            <connectedAppClientId>${AP_CLIENT_ID}</connectedAppClientId>
            <connectedAppClientSecret>${AP_CLIENT_SECRET}</connectedAppClientSecret>
            <connectedAppGrantType>client_credentials</connectedAppGrantType>
            <deploymentSettings>
                <cpuReserved>500m</cpuReserved>
                <cpuMax>1000m</cpuMax>
                <memoryReserved>1500Mi</memoryReserved>
                <memoryMax>2000Mi</memoryMax>
                <enforceDeployingReplicasAcrossNodes>true</enforceDeployingReplicasAcrossNodes>
            </deploymentSettings>
        </runtimeFabricDeployment>
    </configuration>
</plugin>
```

#### 3. CLI Deployment

```bash
anypoint-cli-v4 runtime-mgr app deploy \
    --name "my-api" \
    --target "my-rtf-cluster" \
    --runtime-version "4.6.0" \
    --replicas 2 \
    --cpu-reserved 500m \
    --cpu-limit 1000m \
    --memory-reserved 1500Mi \
    --memory-limit 2000Mi \
    --artifact ./target/my-api-1.0.0-mule-application.jar \
    --environment "Production"
```

#### 4. Ingress Configuration

```yaml
# Kubernetes ingress for RTF apps
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api-ingress
  namespace: rtf
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - my-api.example.com
      secretName: my-api-tls
  rules:
    - host: my-api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-api
                port:
                  number: 8081
```

### How It Works
1. Runtime Fabric installs an agent on your Kubernetes cluster that communicates with Anypoint Platform
2. Applications are deployed as Kubernetes pods managed by the RTF controller
3. You manage the infrastructure (Kubernetes cluster); MuleSoft manages the Mule runtime lifecycle
4. Ingress, TLS, and networking are handled by your Kubernetes infrastructure

### Migration Checklist
- [ ] Set up Kubernetes cluster (EKS, AKS, GKE, or on-prem)
- [ ] Install Runtime Fabric controller via Helm
- [ ] Configure ingress controller (NGINX, ALB, etc.)
- [ ] Map CloudHub worker sizes to Kubernetes resource requests/limits
- [ ] Update POM deployment configuration for RTF
- [ ] Migrate properties and secure properties
- [ ] Deploy to RTF staging environment
- [ ] Configure TLS certificates
- [ ] Test end-to-end connectivity
- [ ] Update DNS to point to new ingress

### Gotchas
- RTF requires a valid Mule Enterprise license
- Kubernetes cluster must meet minimum resource requirements (check MuleSoft docs)
- RTF controller needs outbound internet access to Anypoint Platform (or Anypoint Private Cloud)
- CloudHub DLB features must be replicated with Kubernetes ingress
- Object Store is available but backed by RTF infrastructure — ensure persistent volumes
- RTF upgrade cycle is separate from CloudHub — you manage controller updates

### Related
- [ch1-app-to-ch2](../ch1-app-to-ch2/) — CloudHub 2.0 alternative
- [on-prem-to-ch2](../on-prem-to-ch2/) — On-prem cloud migration
- [hybrid-to-unified](../hybrid-to-unified/) — Unified agent approach
