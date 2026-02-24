## Deployment Failure Flowchart
> Systematic diagnosis of CloudHub 2.0 deployment failures with Anypoint CLI commands at each step

### When to Use
- CloudHub 2.0 deployment fails with a vague error in Runtime Manager
- Deployment stays in "Deploying" status for more than 10 minutes
- Application deploys but immediately goes to "Failed" status
- Migration from CloudHub 1.0 to 2.0 and deployments that worked before now fail
- CI/CD pipeline deployment step fails

### Diagnosis Steps

Follow this flowchart top-to-bottom. Stop at the first match.

```
DEPLOYMENT FAILED
│
├─ Step 1: Check permissions
│   └─ Can your user/connected-app deploy to the target?
│       ├─ NO → Fix RBAC permissions (see Step 1 details)
│       └─ YES ↓
│
├─ Step 2: Check target configuration
│   └─ Does the target (private space / shared space) exist?
│       ├─ NO → Create the target or fix the target name
│       └─ YES ↓
│
├─ Step 3: Check resource availability
│   └─ Are there enough vCores available?
│       ├─ NO → Free up vCores or request quota increase
│       └─ YES ↓
│
├─ Step 4: Check application configuration
│   └─ Are all properties resolved?
│       ├─ NO → Add missing properties to the target config
│       └─ YES ↓
│
├─ Step 5: Check dependencies
│   └─ Are all connectors/modules available for the target runtime?
│       ├─ NO → Update connector versions or runtime version
│       └─ YES ↓
│
├─ Step 6: Check TLS / certificates
│   └─ Are custom TLS contexts configured correctly?
│       ├─ NO → Fix certificate chain, keystore format, or trust store
│       └─ YES ↓
│
├─ Step 7: Check network
│   └─ Can the target reach required external services?
│       ├─ NO → Configure private space network rules, DNS, proxy
│       └─ YES ↓
│
└─ Step 8: Check application startup
    └─ Does the app start but then crash?
        ├─ YES → Check application logs for startup errors
        └─ NO → Contact MuleSoft support with deployment ID
```

---

#### Step 1: Check Permissions

```bash
# List your current user's roles and permissions
anypoint-cli account:user:describe

# Check the connected app's scopes (if using CI/CD)
anypoint-cli connected-app:describe <client-id>

# Required permissions for CH2 deployment:
# - Cloudhub Network Viewer (to see private spaces)
# - Cloudhub Developer (to deploy)
# - Exchange Viewer (to pull dependencies)
```

**Common permission errors:**
```
Access denied: user does not have required permission to deploy to environment 'Production'
```
Fix: Grant the "CloudHub Developer" role for the specific environment in Access Management.

```
Insufficient privileges to access organization
```
Fix: The connected app needs the `Organization Administrator` or `CloudHub Developer` scope.

#### Step 2: Check Target Configuration

```bash
# List available targets (private spaces and shared spaces)
anypoint-cli runtime-mgr:cloudhub2:target:list

# Describe a specific private space
anypoint-cli runtime-mgr:cloudhub2:private-space:describe <private-space-name>

# Check the target in your deployment descriptor
# In pom.xml (Mule Maven Plugin):
```
```xml
<cloudHubDeployment>
    <uri>https://anypoint.mulesoft.com</uri>
    <provider>MC</provider>
    <environment>Production</environment>
    <target>my-private-space</target>  <!-- MUST match exactly -->
    <muleVersion>4.6.0</muleVersion>
    <replicas>1</replicas>
    <vCores>0.1</vCores>
</cloudHubDeployment>
```

**Common target errors:**
```
Target 'my-private-space' not found in environment 'Production'
```
Fix: Verify the private space name (case-sensitive) and that it's associated with the correct environment.

#### Step 3: Check Resource Availability

```bash
# Check vCore usage for your organization
anypoint-cli runtime-mgr:cloudhub2:resource:describe

# List all deployed applications and their vCore allocation
anypoint-cli runtime-mgr:cloudhub2:application:list
```

**Common resource errors:**
```
Insufficient vCores: requested 0.2 but only 0.0 available
```
Fix: Stop unused applications to free vCores, or contact your Anypoint admin to increase the subscription quota.

**vCore math:**
```
Total vCores used = SUM(replicas × vCores per replica) for all apps
Available = Subscription limit - Total used
```

#### Step 4: Check Application Configuration

```bash
# List properties configured for the target
anypoint-cli runtime-mgr:cloudhub2:application:describe <app-name>

# Check for unresolved property placeholders in your config
# Look for ${property.name} that aren't set in:
# 1. Runtime Manager Properties tab
# 2. Secure properties in the deployment descriptor
# 3. Connected property providers (Vault, etc.)
```

**Common property errors:**
```
Could not resolve placeholder 'db.host' in value "${db.host}"
```
Fix: Add the property in Runtime Manager → Application → Settings → Properties, or in your deployment configuration.

```bash
# Set properties via CLI
anypoint-cli runtime-mgr:cloudhub2:application:deploy <app-name> \
  --property "db.host:prod-db.example.com" \
  --property "db.port:3306"
```

#### Step 5: Check Dependencies

```bash
# Verify the Mule runtime version supports your connectors
# Check your pom.xml for connector versions
```
```xml
<!-- Common issue: connector requires Mule 4.4+ but deploying to 4.3 -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>10.18.0</version>  <!-- Check release notes for minimum runtime -->
    <classifier>mule-plugin</classifier>
</dependency>
```

**Common dependency errors:**
```
Failed to resolve component 'salesforce:query': Plugin 'mule-salesforce-connector' not found
```
Fix: Check that the connector version exists in Exchange and is compatible with your runtime version. Run `mvn dependency:tree` to identify conflicts.

#### Step 6: Check TLS / Certificates

```bash
# Verify keystore is valid
keytool -list -v -keystore keystore.jks -storepass <password>

# Verify the certificate chain is complete
openssl s_client -connect target-host:443 -showcerts

# Check certificate expiry
keytool -list -v -keystore keystore.jks -storepass <password> | grep "Valid from"
```

**Common TLS errors:**
```
PKIX path building failed: unable to find valid certification path
```
Fix: Import the target's CA certificate into your trust store. For CH2, upload the trust store in Runtime Manager.

```
Keystore was tampered with, or password was incorrect
```
Fix: Verify keystore password, ensure the keystore format matches config (JKS vs PKCS12).

#### Step 7: Check Network (Private Spaces)

```bash
# List private space network rules
anypoint-cli runtime-mgr:cloudhub2:private-space:describe <space-name>

# Test connectivity from within the private space
# Deploy a simple health-check app that calls your target services
```

**Common network errors:**
```
Connection refused: connect to db.internal.example.com:3306
```
Fix: Ensure the private space has a route to the target network (VPN, transit gateway, or peering). Check DNS resolution within the private space.

**Private space network checklist:**
- [ ] VPN tunnel is UP and routes are propagated
- [ ] DNS resolution works (add custom DNS servers if needed)
- [ ] Security group allows outbound traffic on required ports
- [ ] Target service firewall allows inbound from the private space CIDR

#### Step 8: Check Application Startup Logs

```bash
# Download application logs
anypoint-cli runtime-mgr:cloudhub2:application:download-logs <app-name>

# Or tail logs in real-time during deployment
anypoint-cli runtime-mgr:cloudhub2:application:tail-logs <app-name>
```

**Common startup errors in logs:**
```
org.mule.runtime.deployment.model.api.DeploymentStartException:
  Error creating bean with name 'httpListenerConfig': Port 8081 already in use
```
Fix: On CH2, the HTTP listener must use port `8081` (HTTP) or `8082` (HTTPS). Don't use other ports.

```
java.lang.OutOfMemoryError: Java heap space
```
Fix: Application needs more memory. Increase vCore size (0.1 → 0.2 or higher).

### How It Works
1. CloudHub 2.0 deployments go through: validation → scheduling → image build → container start → health check
2. The deployment is a Kubernetes pod under the hood — failed pods show in the deployment status
3. Properties are injected as environment variables into the container
4. The Mule runtime starts inside the container and initializes all flows — startup errors cause the pod to crash-loop
5. The health check (`/` on port 8081) must return within the configured timeout for the app to be marked "Running"

### Gotchas
- **CH2 vs CH1 configuration differences** — CH2 uses `target` (private/shared space name) instead of `region`. CH2 uses `replicas` + `vCores` instead of `workers` + `workerType`. Many CI/CD scripts built for CH1 will fail on CH2.
- **Private space network rules are NOT the same as VPC firewall rules** — CH2 private spaces use Kubernetes networking, not the old VPC model. Rules configured in CH1 VPCs don't carry over.
- **Deployment timeout** — if the app takes more than 10 minutes to start (loading large configs, slow DB initialization), CH2 marks it as failed. Add `readinessProbe` configuration.
- **Port restrictions** — CH2 only exposes ports 8081 (HTTP) and 8082 (HTTPS). Any other port configuration will fail silently.
- **Property names with dots** — CH2 converts property names to environment variables. Dots become underscores internally: `db.host` → `DB_HOST`. This can cause conflicts.
- **Anypoint CLI version** — ensure you're using `anypoint-cli-v4` for CH2 commands. The v3 CLI doesn't support CH2 targets.
- **Connected app vs user token** — CI/CD should use connected apps, not user tokens. User tokens expire; connected app credentials don't.

### Related
- [Common Error Messages Decoded](../common-error-messages-decoded/) — when deployment succeeds but runtime errors appear
- [Anypoint Monitoring vs OpenTelemetry](../anypoint-monitoring-vs-otel/) — monitoring after successful deployment
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — when the app deploys but connections fail
- [CloudHub vCore Sizing](../../performance/cloudhub/vcore-sizing-matrix/) — choosing the right vCore allocation
