## Deployment Failure Common Causes
> The 15 most common deployment failures and fixes for CloudHub 1.0, CloudHub 2.0, and on-prem

### When to Use
- Deployment stuck in "Deploying" or "Starting" state
- Deployment fails with an error in Runtime Manager
- Application deploys successfully but immediately crashes
- Migrating from CloudHub 1.0 to 2.0 and deployments that worked before now fail
- Need a checklist before deploying to production

### The Problem

Deployment failures block releases and cause outages when the previous version was already undeployed. Each failure has a specific root cause, but the error messages are often generic ("Deployment failed"). This recipe catalogs the 15 most common causes with their exact error messages and fixes.

### Cause 1: Insufficient vCore Allocation

**Error:**
```
Error deploying application: Insufficient resources. Required vCores: 0.2, Available: 0
```

**Diagnosis:**
```bash
anypoint-cli runtime-mgr:application:describe <app-name> | grep vCores
anypoint-cli account:environment:usage
```

**Fix:** Free up vCores by stopping unused applications or purchase additional capacity.

---

### Cause 2: Application Package Too Large

**Error:**
```
Error: Application archive exceeds maximum size (200 MB for CloudHub 1.0, 300 MB for CH2)
```

**Diagnosis:**
```bash
ls -la target/*.jar
# Check what's taking space
jar tf target/my-app-1.0.0-mule-application.jar | awk -F/ '{print $1"/"$2}' | sort -u
```

**Fix:**
```xml
<!-- Exclude unnecessary dependencies in pom.xml -->
<dependency>
    <groupId>com.example</groupId>
    <artifactId>large-library</artifactId>
    <scope>provided</scope> <!-- Don't include in package -->
</dependency>

<!-- Or use shared libraries on CloudHub -->
```

---

### Cause 3: Mule Runtime Version Mismatch

**Error:**
```
Unsupported Mule Runtime version: 4.4.0
```

**Diagnosis:**
```bash
# Check available runtimes
anypoint-cli runtime-mgr:runtime:list

# Check app's required runtime
grep "minMuleVersion" mule-artifact.json
```

**Fix:** Update `mule-artifact.json` to a supported runtime version, or select the correct runtime in deployment settings.

---

### Cause 4: Port Conflict

**Error:**
```
Address already in use: bind 0.0.0.0:8081
```

**Diagnosis:** On CloudHub, this happens when deploying the same app name while the previous instance hasn't fully stopped.

**Fix:**
```bash
# Wait for previous deployment to fully stop
anypoint-cli runtime-mgr:application:describe <app-name> | grep status
# If stuck in "Stopping", force delete:
anypoint-cli runtime-mgr:application:delete <app-name>
# Then redeploy
```

---

### Cause 5: Invalid or Missing Properties

**Error:**
```
Could not resolve placeholder '${db.host}' in value "${db.host}"
org.mule.runtime.api.lifecycle.LifecycleException: Could not start application
```

**Diagnosis:**
```bash
# List configured properties
anypoint-cli runtime-mgr:application:describe <app-name> --output json | jq '.properties'
```

**Fix:** Ensure all `${property}` placeholders have values in either:
- Runtime Manager > Application > Settings > Properties
- `src/main/resources/config-<env>.yaml`
- Secure properties file

---

### Cause 6: Maven Dependency Resolution Failure

**Error:**
```
Could not resolve dependencies for project com.mycompany:my-app:jar:1.0.0
```

**Diagnosis:**
```bash
# Build locally first to verify
mvn clean package -DskipTests

# Check for Exchange/private repository dependencies
mvn dependency:tree | grep -i "SNAPSHOT\|FAILURE"
```

**Fix:** Ensure your `settings.xml` has the correct Exchange credentials and repository URLs. For private Exchange assets, configure server credentials.

---

### Cause 7: Incompatible Connector Version

**Error:**
```
Unsatisfied dependency: connector 'http' version 1.7.3 requires runtime 4.5+
```

**Diagnosis:**
```bash
grep -r "mule-http-connector" pom.xml
```

**Fix:** Either upgrade the runtime or downgrade the connector to a compatible version.

---

### Cause 8: TLS/Keystore Configuration Error

**Error:**
```
java.security.KeyStoreException: Keystore was tampered with, or password was incorrect
java.io.FileNotFoundException: keystore.jks (No such file or directory)
```

**Diagnosis:**
```bash
# Verify keystore exists in the package
jar tf target/my-app.jar | grep -i keystore

# Verify keystore password
keytool -list -keystore src/main/resources/keystore.jks -storepass <password>
```

**Fix:** Ensure the keystore file is in `src/main/resources/` and the password is correct in properties.

---

### Cause 9: DataWeave Compilation Error

**Error:**
```
org.mule.weave.v2.exception.WeaveCompilationException: Unable to compile DataWeave expression
```

**Diagnosis:** This means a DataWeave script has a syntax error that wasn't caught during local testing (possible if using dynamic scripts or different runtime versions).

**Fix:** Check the specific line number in the error. Test the script in the DataWeave Playground with the target runtime version.

---

### Cause 10: Insufficient Memory for Startup

**Error:**
```
java.lang.OutOfMemoryError: Java heap space (during startup)
```

**Diagnosis:** Application with many connectors and dependencies exceeds the heap available during class loading.

**Fix:** Increase vCore size. A 0.1 vCore worker with 10+ connectors will likely fail to start.

```
Connector count guidelines:
  0.1 vCore: 3-4 connectors max
  0.2 vCore: 5-7 connectors max
  0.5 vCore: 10-15 connectors max
  1.0 vCore: 20+ connectors
```

---

### Cause 11: CloudHub 2.0 — Container Image Build Failure

**Error:**
```
Error building container image: layer exceeds maximum size
```

**Diagnosis:** CloudHub 2.0 builds a container image from your application. If the image exceeds the size limit, the build fails.

**Fix:** Reduce application size (see Cause 2) or split into multiple applications.

---

### Cause 12: API Auto-Discovery ID Conflict

**Error:**
```
API auto-discovery: API instance not found for id: 12345
```

**Diagnosis:**
```bash
# Check autodiscovery configuration
grep -r "autodiscovery\|api-id" src/main/mule/
```

**Fix:** Verify the `apiId` in your `<api-gateway:autodiscovery>` configuration matches the API instance ID in API Manager for the target environment.

---

### Cause 13: Scheduler Configuration Syntax Error

**Error:**
```
Invalid cron expression: "0 */5 * * * *"
```

**Diagnosis:** Mule uses Quartz CRON format (with seconds field), not standard Unix CRON.

**Fix:**
```xml
<!-- Wrong (Unix cron, 5 fields): -->
<scheduler>
    <scheduling-strategy>
        <cron expression="*/5 * * * *"/>  <!-- WRONG -->
    </scheduling-strategy>
</scheduler>

<!-- Correct (Quartz cron, 6-7 fields): -->
<scheduler>
    <scheduling-strategy>
        <cron expression="0 */5 * * * ?"/>  <!-- CORRECT -->
    </scheduling-strategy>
</scheduler>
```

---

### Cause 14: Object Store Initialization Failure

**Error:**
```
Could not create ObjectStore: Object store partition limit exceeded
```

**Diagnosis:** CloudHub Object Store v2 has limits on partitions and entry size.

**Fix:** Reduce the number of Object Store configurations or use fewer partitions.

---

### Cause 15: Secure Properties Decryption Failure

**Error:**
```
org.mule.runtime.config.api.dsl.model.ConfigurationException:
  Unable to decrypt property 'db.password'
```

**Diagnosis:** The decryption key provided at deployment doesn't match the key used to encrypt the properties.

**Fix:**
```bash
# Verify the encryption key
# Re-encrypt properties with the correct key:
java -jar secure-properties-tool.jar string encrypt AES CBC <key> <value>

# Ensure the key is set in Runtime Manager > Settings > Properties:
# secure.key = <your-encryption-key>
```

### Pre-Deployment Checklist

```
[ ] Application builds successfully locally (mvn clean package)
[ ] All MUnit tests pass (mvn test)
[ ] All property placeholders have values for target environment
[ ] Runtime version matches target CloudHub version
[ ] vCore allocation is sufficient
[ ] Application package size is within limits
[ ] Keystores/truststores are included in the package
[ ] API auto-discovery ID matches target environment
[ ] Secure properties key is configured
[ ] Previous version is fully stopped (no port conflicts)
[ ] Connector versions are compatible with target runtime
[ ] DataWeave scripts compile against target runtime
[ ] Cron expressions use Quartz format (6+ fields)
[ ] Object Store configuration is within limits
[ ] Log4j2.xml is valid
```

### Gotchas
- **CloudHub 2.0 deployments are slower than 1.0** — CH2 builds a container image, which adds 2-5 minutes to deployment time. Don't assume it failed just because it's taking longer.
- **"Deploying" state for >15 minutes = stuck** — on CloudHub 1.0, if deployment is stuck, contact MuleSoft support. On CH2, check pod events for OOMKilled or CrashLoopBackOff.
- **Rollback is not automatic** — unlike some PaaS platforms, CloudHub does not automatically roll back to the previous version on failure. Keep a known-good package available for manual rollback.
- **Properties are environment-specific** — deploying the same package from sandbox to production often fails because property keys are different or missing.
- **mule-artifact.json is critical** — this file specifies the minimum runtime version and classifier. A wrong entry here causes deployment to fail silently or pick the wrong runtime.

### Related
- [Deployment Failure Flowchart](../deployment-failure-flowchart/) — visual decision tree for deployment issues
- [CloudHub 2.0 Migration Gotchas](../cloudhub2-migration-gotchas/) — CH1 to CH2 differences
- [CloudHub Log Analysis](../cloudhub-log-analysis/) — finding deployment errors in logs
- [Memory Budget Breakdown](../memory-budget-breakdown/) — vCore sizing for deployment
