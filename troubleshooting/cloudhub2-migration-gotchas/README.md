## CloudHub 2.0 Migration Gotchas
> Breaking changes from CloudHub 1.0 to 2.0 that will bite you in production

### When to Use
- Planning or executing migration from CloudHub 1.0 to CloudHub 2.0
- Application works on CH1 but fails on CH2
- Need a checklist of breaking changes before migration
- Troubleshooting post-migration issues

### The Problem

CloudHub 2.0 is a fundamentally different platform built on Kubernetes. Many assumptions from CloudHub 1.0 no longer hold: persistent local storage is gone, networking changes, log behavior differs, and some operational workflows are completely different. Applications that ran fine on CH1 can fail on CH2 in subtle ways.

### Architecture Differences

```
CloudHub 1.0                          CloudHub 2.0
+---------------------+              +---------------------+
| Virtual Machine     |              | Kubernetes Pod      |
| - Persistent disk   |              | - Ephemeral storage |
| - Static IP (VPC)   |              | - Dynamic IP        |
| - mule_ee.log file  |              | - stdout/stderr     |
| - Direct SSH (debug)|              | - No SSH access     |
| - Warm restart      |              | - Cold restart      |
| - Worker threads    |              | - Container limits  |
+---------------------+              +---------------------+
```

### Gotcha 1: No Persistent Local Storage

**CH1 behavior:** Files written to the filesystem persist across restarts.
**CH2 behavior:** Pod restarts destroy all local files.

**What breaks:**
- Applications writing to `/tmp` and expecting files to survive restarts
- File-based caches
- SQLite databases stored locally
- Heap dumps written to local disk

**Fix:**
```xml
<!-- Replace local file storage with Object Store -->
<os:object-store name="persistentCache"
    persistent="true"
    maxEntries="10000"
    entryTtl="24"
    entryTtlUnit="HOURS"/>

<!-- Use Object Store instead of file write -->
<os:store key="#[vars.cacheKey]"
    objectStore="persistentCache"
    value="#[payload]"/>
```

### Gotcha 2: OOMKilled vs. OutOfMemoryError

**CH1 behavior:** JVM throws `OutOfMemoryError`, heap dump is written, app can potentially recover.
**CH2 behavior:** Kubernetes kills the container when it exceeds memory limits. No heap dump, no graceful shutdown, no error in Mule logs.

**Symptoms:**
- Pod status shows `OOMKilled`
- No OutOfMemoryError in application logs
- Application restarts with no apparent cause

**Fix:**
```bash
# Check pod status
anypoint-cli runtime-mgr:application:describe <app-name> --output json | jq '.replicas[].status'

# Prevention: set JVM heap lower than container limit
# Container limit = vCore memory allocation
# JVM heap should be 60-70% of container limit
# Add JVM args:
-Xmx768m -Xms512m  # For 1 vCore (1.5 GB container)
```

### Gotcha 3: Networking Changes

**CH1 behavior:** Workers have static private IPs (in VPC), predictable DNS.
**CH2 behavior:** Pods get dynamic IPs, DNS resolves to pod IPs that change on restart.

**What breaks:**
- Firewall rules based on static outbound IPs
- IP whitelisting with third-party services
- DNS-based service discovery that caches old IPs

**Fix:**
```bash
# Use Anypoint VPN or private connectivity for static IP requirements
# For outbound static IP, configure NAT gateway in the VPN

# Reduce DNS TTL caching in JVM:
-Dnetworkaddress.cache.ttl=30
-Dnetworkaddress.cache.negative.ttl=10
```

### Gotcha 4: Log File Access

**CH1 behavior:** `mule_ee.log` accessible via Runtime Manager download, file on disk.
**CH2 behavior:** Logs go to stdout/stderr only. No log files to download.

**What breaks:**
- Log forwarding configurations that read from log files
- Log analysis scripts that expect file paths
- Custom log4j2 appenders writing to specific file paths

**Fix:**
```xml
<!-- Ensure log4j2.xml uses Console appender only -->
<Appenders>
    <Console name="Console" target="SYSTEM_OUT">
        <PatternLayout pattern="%d [%t] %-5p %c - %m%n"/>
    </Console>
    <!-- Remove any RollingFile appenders -->
</Appenders>
```

### Gotcha 5: Warm Restart vs. Cold Restart

**CH1 behavior:** Mule runtime stays running, only the application reloads (warm restart).
**CH2 behavior:** Entire container restarts. JVM starts from scratch (cold restart).

**Impact:**
- Startup time is longer on CH2 (30-90 seconds vs. 10-30 seconds)
- JIT compilation cache is lost
- Connection pools start empty
- First few requests after restart are slower

**Fix:** Design for cold starts. Use health check endpoints with readiness probes:
```xml
<flow name="readinessProbe">
    <http:listener config-ref="HTTP" path="/ready"/>
    <try>
        <!-- Verify all critical connections are up -->
        <db:select config-ref="DB">
            <db:sql>SELECT 1</db:sql>
        </db:select>
        <set-payload value='{"status": "ready"}'/>
    <error-handler>
        <on-error-continue type="ANY">
            <set-payload value='{"status": "not ready"}'/>
            <set-variable variableName="httpStatus" value="503"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

### Gotcha 6: Scheduler Behavior on Multiple Replicas

**CH1 behavior:** Each worker runs its own scheduler independently.
**CH2 behavior:** Same — each replica runs its own scheduler.

**What breaks:** If you deploy 2 replicas and have a cron scheduler, BOTH replicas fire the cron job. This means duplicate processing.

**Fix:**
```xml
<!-- Use Object Store as a distributed lock -->
<flow name="scheduledJob">
    <scheduler>
        <scheduling-strategy>
            <cron expression="0 0 * * * ?"/>
        </scheduling-strategy>
    </scheduler>

    <!-- Acquire lock -->
    <try>
        <os:store key="scheduler-lock" objectStore="locks"
            value="#[server.dateTime]"
            failIfPresent="true"/>

        <!-- Processing here — only one replica gets the lock -->

        <!-- Release lock -->
        <os:remove key="scheduler-lock" objectStore="locks"/>

    <error-handler>
        <on-error-continue type="OS:KEY_ALREADY_EXISTS">
            <logger level="DEBUG" message="Another replica has the lock, skipping"/>
        </on-error-continue>
    </error-handler>
    </try>
</flow>
```

### Gotcha 7: Environment Variable Handling

**CH1 behavior:** Properties set in Runtime Manager UI are Java system properties.
**CH2 behavior:** Properties are environment variables, which have naming restrictions.

**What breaks:** Property names with dots (e.g., `db.host`) are valid Java system properties but invalid environment variable names in some Kubernetes implementations.

**Fix:** Use underscores or configure properties via secure properties files instead of environment variables.

### Gotcha 8: Object Store Behavior

**CH1 behavior:** Object Store v2 with CloudHub-managed persistence.
**CH2 behavior:** Same Object Store v2, but behavior during pod restarts differs.

**What breaks:** In-memory Object Store (non-persistent) is lost on every pod restart (which happens more frequently on CH2 due to cold restarts).

**Fix:** Always use `persistent="true"` for any data that must survive restarts.

### Gotcha 9: Deployment Rollback

**CH1 behavior:** You can manually select a previous version to redeploy from the UI.
**CH2 behavior:** No built-in rollback UI. You must redeploy the previous artifact manually.

**Fix:** Keep versioned artifacts in Exchange or an artifact repository. Tag deployments:
```bash
# Store deployment info for rollback
echo "$(date): Deployed version 1.2.3 to production" >> deployment_log.txt

# Rollback procedure:
anypoint-cli runtime-mgr:application:deploy <app-name> \
  --artifact com.mycompany:my-app:1.2.2:mule-application \
  --runtime 4.6.0
```

### Gotcha 10: TLS and Certificates

**CH1 behavior:** Certificates in Mule's JVM truststore persist.
**CH2 behavior:** Custom certificates must be included in the application package or configured via secrets.

**Fix:** Bundle certificates in your application:
```xml
<tls:context name="TLS_Context">
    <tls:trust-store path="certs/custom-ca.pem" type="pem"/>
</tls:context>
```

### Migration Checklist

```
Pre-Migration:
[ ] Inventory all file system usage (reads, writes, temp files)
[ ] Identify all scheduler/cron jobs and their idempotency
[ ] List all IP-based firewall rules and whitelist entries
[ ] Document current log forwarding setup
[ ] Export all Runtime Manager properties
[ ] Test application startup time (expect 2-3x longer on CH2)
[ ] Verify Object Store is set to persistent where needed

Migration:
[ ] Update log4j2.xml to Console appender only
[ ] Replace file writes with Object Store or external storage
[ ] Add readiness and liveness probes
[ ] Configure JVM heap at 60-70% of container memory
[ ] Test with multiple replicas (verify no duplicate processing)
[ ] Set DNS cache TTL to 30 seconds
[ ] Bundle any custom TLS certificates

Post-Migration:
[ ] Verify log forwarding works with stdout-based logs
[ ] Test failover by killing one replica
[ ] Verify scheduler runs correctly with multiple replicas
[ ] Confirm no OOMKilled events in first 24 hours
[ ] Validate response times are within SLA
```

### Gotchas
- **CH2 is not a drop-in replacement** — expect to spend 2-5 days per application on migration, more for complex applications with file I/O or scheduler dependencies.
- **Monitoring dashboards change** — Anypoint Monitoring dashboards built for CH1 may not show CH2 metrics. Rebuild dashboards after migration.
- **Cost model differs** — CH2 uses fractional vCores and replica-based pricing. Total cost may differ from CH1.
- **CH2 auto-scaling is different** — CH1 uses worker count. CH2 uses HPA (Horizontal Pod Autoscaler) based on CPU/memory metrics.
- **Shared load balancer behavior differs** — CH2's shared LB has different timeout and keepalive settings than CH1's.

### Related
- [Deployment Failure Common Causes](../deployment-failure-common-causes/) — deployment issues on both platforms
- [Memory Budget Breakdown](../memory-budget-breakdown/) — vCore memory on CH2
- [CloudHub Log Analysis](../cloudhub-log-analysis/) — log management on both platforms
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — handling OOMKilled on CH2
