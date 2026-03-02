## RTF Pod Failure Diagnosis
> Kubernetes-layer troubleshooting for Runtime Fabric — pod crashes, scheduling failures, and resource limits

### When to Use
- Application deployed on Anypoint Runtime Fabric (RTF) is not starting
- Pod shows CrashLoopBackOff, OOMKilled, or Pending status
- RTF deployment succeeds but application is unreachable
- Need to diagnose Kubernetes-level issues without deep K8s expertise
- Performance issues specific to the RTF container runtime

### The Problem

Runtime Fabric runs Mule applications in Kubernetes pods. When things go wrong at the Kubernetes layer, Mule logs are often empty or missing — the problem is below the JVM. Diagnosing requires Kubernetes commands and understanding of pod lifecycle, resource limits, and scheduling.

### RTF Architecture

```
+-----------------------------------------------------------------+
|                    Runtime Fabric Cluster                        |
|                                                                 |
|  +-------------------+  +-------------------+                   |
|  | Controller Node   |  | Worker Node       |                   |
|  | - API server      |  | - kubelet         |                   |
|  | - scheduler       |  | - container runtime|                  |
|  | - RTF agent       |  | +---------------+ |                   |
|  +-------------------+  | | Pod           | |                   |
|                          | | +-----------+ | |                   |
|                          | | |Mule App   | | |                   |
|                          | | |Container  | | |                   |
|                          | | +-----------+ | |                   |
|                          | +---------------+ |                   |
|                          +-------------------+                   |
+-----------------------------------------------------------------+
```

### Pod Status Reference

| Status | Meaning | Severity |
|--------|---------|----------|
| Pending | Pod accepted but no node can run it | High — scheduling failure |
| Running | At least one container is running | Normal |
| Succeeded | All containers completed successfully | Normal (for jobs) |
| Failed | All containers terminated, at least one failed | High |
| CrashLoopBackOff | Container keeps crashing and restarting | Critical |
| OOMKilled | Container exceeded memory limit | Critical |
| ImagePullBackOff | Cannot pull container image | High |
| ErrImagePull | Image pull failed | High |
| Evicted | Node ran out of resources | High |

### Diagnostic Steps

#### Step 1: Get Pod Status

```bash
# Connect to RTF cluster (requires kubectl access)
# RTF provides rtfctl for cluster operations

# List pods for your application
kubectl get pods -n <namespace> -l app=<app-name>

# Get detailed pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events (most useful for diagnosis)
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -30
```

#### Step 2: Diagnose by Status

##### CrashLoopBackOff

The container starts, crashes, Kubernetes restarts it, it crashes again.

```bash
# Check container exit code
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Last State"

# Exit code reference:
# 0   = Normal exit (shouldn't crash loop)
# 1   = Application error (check Mule logs)
# 137 = OOMKilled (SIGKILL from kernel)
# 143 = SIGTERM (graceful shutdown requested but failed)

# Get logs from the crashed container
kubectl logs <pod-name> -n <namespace> --previous

# If no logs available, check init containers
kubectl logs <pod-name> -n <namespace> -c init-container --previous
```

**Common causes and fixes:**

| Exit Code | Cause | Fix |
|-----------|-------|-----|
| 1 | Mule startup error (missing property, bad config) | Check `kubectl logs --previous` for stack trace |
| 137 | Container memory limit too low | Increase memory in RTF deployment config |
| 143 | Graceful shutdown timeout exceeded | Increase `terminationGracePeriodSeconds` |

##### Pending (Scheduling Failure)

```bash
# Check why the pod can't be scheduled
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events:"

# Common messages:
# "Insufficient cpu"     -> node doesn't have enough CPU
# "Insufficient memory"  -> node doesn't have enough memory
# "0/3 nodes are available" -> no node matches constraints
# "node(s) had taint"   -> node taints prevent scheduling
```

**Fix:**
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# If no nodes have capacity, scale up the cluster
rtfctl appliance status
```

##### OOMKilled

```bash
# Confirm OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep "OOMKilled"

# Check resource limits vs. actual usage
kubectl top pod <pod-name> -n <namespace>

# Check node memory pressure
kubectl describe node <node-name> | grep -A 3 "Conditions"
```

**Fix:**
```bash
# Increase memory limit in RTF deployment
# Via Runtime Manager > RTF > Application > Settings
# Or via rtfctl:
rtfctl apply application <app-name> --memory 2Gi --cpu 1000m
```

##### ImagePullBackOff

```bash
# Check the exact image pull error
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Events:" | grep -i "pull"

# Common causes:
# - Registry authentication failure
# - Image doesn't exist
# - Network connectivity to registry
```

**Fix:**
```bash
# Verify image exists
docker pull <image-url> 2>&1

# Check image pull secrets
kubectl get secrets -n <namespace> | grep docker
kubectl describe secret <pull-secret-name> -n <namespace>
```

#### Step 3: Check Resource Usage

```bash
# Pod resource usage
kubectl top pod -n <namespace> -l app=<app-name>

# Node resource usage
kubectl top nodes

# Resource requests vs. limits vs. actual
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Containers:" | grep -A 5 "Limits:"
```

**Resource sizing guide for Mule on RTF:**
```
+-----------+------------------+------------------+
| Workload  | CPU Request/Limit| Memory Req/Limit |
+-----------+------------------+------------------+
| Light API | 200m / 500m      | 512Mi / 1Gi      |
| Medium API| 500m / 1000m     | 1Gi / 2Gi        |
| Heavy API | 1000m / 2000m    | 2Gi / 4Gi        |
| Batch     | 500m / 2000m     | 2Gi / 4Gi        |
+-----------+------------------+------------------+

Rule: Request = 50% of Limit (allows burst)
Memory Limit should be ~1.5x JVM heap (-Xmx)
```

#### Step 4: Check Networking

```bash
# Check service and ingress
kubectl get svc -n <namespace> -l app=<app-name>
kubectl get ingress -n <namespace>

# Test pod connectivity
kubectl exec -it <pod-name> -n <namespace> -- curl -v http://localhost:8081/health

# Check DNS resolution inside the pod
kubectl exec -it <pod-name> -n <namespace> -- nslookup <downstream-host>

# Check network policies
kubectl get networkpolicy -n <namespace>
```

#### Step 5: Check Persistent Volumes (if used)

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# If PVC is Pending:
kubectl describe pvc <pvc-name> -n <namespace>

# Common issues:
# - StorageClass doesn't exist
# - No available PVs matching the claim
# - Node affinity prevents scheduling
```

### RTF-Specific Commands

```bash
# RTF cluster status
rtfctl status

# RTF appliance health
rtfctl appliance status

# List all RTF-managed applications
rtfctl get apps

# Get application details
rtfctl describe app <app-name>

# Force restart an application
rtfctl restart app <app-name>

# Check RTF agent logs
kubectl logs -n rtf -l app=rtf-agent --tail=100
```

### Liveness and Readiness Probes

RTF uses probes to determine pod health:

```yaml
# Default probe configuration (applied by RTF)
livenessProbe:
  httpGet:
    path: /
    port: 8081
  initialDelaySeconds: 120
  periodSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /
    port: 8081
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 3
```

**When probes cause issues:**
- Application takes >120s to start → liveness probe kills it → CrashLoopBackOff
- Custom health endpoint not on port 8081 → probe fails → pod marked as unhealthy

**Fix:** Configure custom probes via RTF settings or implement a health endpoint on the expected port:
```xml
<flow name="healthCheck">
    <http:listener config-ref="HTTP" path="/">
        <http:response statusCode="200"/>
    </http:listener>
    <set-payload value='{"status": "up"}'/>
</flow>
```

### Gotchas
- **RTF doesn't expose Kubernetes API directly** — you need cluster admin access or `rtfctl` tool. Standard `kubectl` works only if you have kubeconfig access to the RTF cluster.
- **Resource limits are hard limits** — unlike CloudHub where exceeding memory causes JVM OOM, RTF's Kubernetes kills the entire container at the cgroup limit. The JVM never gets a chance to dump heap.
- **Horizontal Pod Autoscaler may cause flapping** — if HPA is configured with aggressive thresholds, pods scale up/down rapidly, causing intermittent connectivity issues.
- **Node maintenance causes pod eviction** — when RTF nodes are upgraded or maintained, pods are evicted and rescheduled. Applications must handle graceful shutdown properly.
- **Init containers can fail silently** — RTF uses init containers for setup (license injection, etc.). If these fail, the main container never starts and logs show nothing useful.
- **Network policies can block inter-app communication** — RTF namespaces may have network policies that prevent pod-to-pod communication. Check with `kubectl get networkpolicy`.
- **PodDisruptionBudget** — configure PDB to ensure at least one replica stays running during voluntary disruptions (node drain, cluster upgrade).

### Related
- [CloudHub 2.0 Migration Gotchas](../cloudhub2-migration-gotchas/) — similar container-based issues
- [Memory Budget Breakdown](../memory-budget-breakdown/) — sizing memory for containers
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — OOM in containerized environments
- [Deployment Failure Common Causes](../deployment-failure-common-causes/) — deployment issues
