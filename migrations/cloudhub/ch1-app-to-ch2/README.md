## Full App Migration from CloudHub 1.0 to CloudHub 2.0
> Step-by-step migration of a Mule application from CloudHub 1.0 to CloudHub 2.0

### When to Use
- CloudHub 1.0 end-of-life planning
- Need container-based deployment with horizontal scaling
- Require Kubernetes features (rolling updates, health checks, replica management)
- Moving to Private Spaces for better network isolation

### Configuration / Code

#### 1. Pre-Migration Audit

```bash
# Get current app configuration
anypoint-cli-v4 cloudhub app describe-v2 \
    --name "my-api" \
    --environment "Production"

# Document current settings
# - Runtime version
# - Worker size and count
# - Properties (app + system)
# - Regions
# - Static IPs
# - Logging configuration
# - Object Store usage
# - Persistent queues
```

#### 2. Update `mule-artifact.json`

```json
{
    "minMuleVersion": "4.6.0",
    "classLoaderModelLoaderDescriptor": {
        "id": "mule",
        "attributes": {
            "exportedResources": []
        }
    },
    "requiredProduct": "MULE_EE"
}
```

#### 3. Update Deployment Descriptor

```json
{
    "applicationName": "my-api",
    "target": {
        "provider": "MC",
        "targetId": "your-private-space-or-shared-space-id",
        "deploymentSettings": {
            "runtimeVersion": "4.6.0",
            "javaVersion": "11",
            "http": {
                "inbound": {
                    "publicUrl": "my-api.us-e1.cloudhub.io",
                    "lastMileSecurity": true
                }
            },
            "resources": {
                "cpu": {
                    "reserved": "500m",
                    "limit": "1000m"
                },
                "memory": {
                    "reserved": "1000Mi",
                    "limit": "1500Mi"
                }
            },
            "replicas": 2,
            "updateStrategy": "rolling"
        }
    },
    "properties": {
        "env": "production",
        "api.id": "${AP_API_ID}"
    },
    "secureProperties": {
        "db.password": "${DB_PASSWORD}",
        "api.key": "${API_KEY}"
    }
}
```

#### 4. Worker Size to Resource Mapping

| CH1 Worker | CH2 CPU (reserved/limit) | CH2 Memory (reserved/limit) |
|---|---|---|
| 0.1 vCore | 100m / 200m | 500Mi / 700Mi |
| 0.2 vCore | 200m / 400m | 1000Mi / 1200Mi |
| 1 vCore | 500m / 1000m | 1500Mi / 2000Mi |
| 2 vCores | 1000m / 2000m | 3000Mi / 4000Mi |
| 4 vCores | 2000m / 4000m | 6000Mi / 8000Mi |

#### 5. Maven Deploy Plugin Configuration

```xml
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.1.1</version>
    <configuration>
        <cloudhub2Deployment>
            <uri>https://anypoint.mulesoft.com</uri>
            <muleVersion>4.6.0</muleVersion>
            <target>your-target-name</target>
            <provider>MC</provider>
            <environment>Production</environment>
            <replicas>2</replicas>
            <vCores>0.5</vCores>
            <applicationName>my-api</applicationName>
            <connectedAppClientId>${AP_CLIENT_ID}</connectedAppClientId>
            <connectedAppClientSecret>${AP_CLIENT_SECRET}</connectedAppClientSecret>
            <connectedAppGrantType>client_credentials</connectedAppGrantType>
            <properties>
                <env>production</env>
            </properties>
            <secureProperties>
                <db.password>${DB_PASSWORD}</db.password>
            </secureProperties>
        </cloudhub2Deployment>
    </configuration>
</plugin>
```

### How It Works
1. CloudHub 2.0 runs on a container-based architecture (Kubernetes) vs CloudHub 1.0's worker model
2. Resources are specified in CPU millicores and memory instead of vCore sizes
3. Scaling is horizontal (replicas) rather than vertical (bigger workers)
4. Deployment uses the Runtime Manager Agent (MC provider) instead of the CloudHub agent

### Migration Checklist
- [ ] Document all CH1 app settings (workers, properties, regions, static IPs)
- [ ] Map worker sizes to CH2 resource allocations
- [ ] Convert app properties to CH2 format (properties + secureProperties)
- [ ] Replace persistent VM queues with Anypoint MQ (if used)
- [ ] Update `mule-artifact.json` with correct `minMuleVersion`
- [ ] Update Maven plugin configuration for CH2 deployment
- [ ] Update CI/CD pipeline deployment commands
- [ ] Deploy to CH2 staging and run integration tests
- [ ] Configure DNS CNAME for the new CH2 endpoint
- [ ] Switch traffic and decommission CH1 app

### Gotchas
- CloudHub 1.0 `${mule.env}` system property may not be available — use explicit properties
- Object Store v1 (CH1) is replaced by Object Store v2 — verify data migration
- Static IPs work differently in CH2 — configure NAT Gateway in Private Space
- CH1 logging integration may need reconfiguration for CH2
- CH2 apps have different URL patterns — update API Manager and client configurations
- Rolling updates require at least 2 replicas; single-replica deployment causes downtime

### CH2 Migration Gotchas — What Nobody Tells You

These are the real-world issues that catch teams during production cutover:

#### 1. Firewall CIDR Changes
CH2 uses different IP ranges than CH1. If your downstream systems or databases whitelist CH1 IPs, they will reject CH2 traffic.

```
# CH1 IP ranges (example — varies by region):
# us-east-1: 3.33.130.0/24, 3.33.131.0/24

# CH2 IP ranges are DIFFERENT and tied to your Private Space:
# Check Runtime Manager → Private Space → Networking → NAT Gateway IPs

# Action: Get CH2 NAT Gateway IPs BEFORE cutover and whitelist them
# on ALL downstream firewalls, databases, SaaS allowlists
```

**Pre-migration script to identify all outbound destinations:**
```bash
# Find every host your app connects to (from logs)
anypoint-cli-v4 cloudhub app download-logs \
    --name "my-api" --environment "Production"
grep -oE 'https?://[a-zA-Z0-9.-]+' mule-app.log | sort -u
```

#### 2. TCP Connection Loss During DNS Cutover
Long-lived connections (WebSocket, database pools, JMS) break during DNS switch. Plan for:

```
# Step 1: Lower DNS TTL to 60s at least 24h before cutover
# Step 2: Deploy to CH2 with new endpoint (parallel run)
# Step 3: Warm up connection pools by sending test traffic
# Step 4: Switch DNS CNAME
# Step 5: Wait 2× TTL for propagation
# Step 6: Monitor for connection errors (pool re-establishment)
# Step 7: Decommission CH1 after 48h observation
```

#### 3. Hazelcast / Distributed Caching
CH1 workers in the same app share a Hazelcast cluster. CH2 replicas do NOT automatically cluster.

- **Object Store v2** works across replicas (backed by Anypoint service)
- **Cache Scope** with in-memory caching is per-replica — not shared
- **VM queues** are per-replica — use Anypoint MQ for cross-replica messaging

```xml
<!-- Replace in-memory cache with Object Store-backed cache -->
<os:object-store name="distributed-cache"
    persistent="true"
    entryTtl="300"
    entryTtlUnit="SECONDS"
    maxEntries="1000" />
```

#### 4. DNS Cutover Checklist

| Step | Action | Timing |
|------|--------|--------|
| T-24h | Lower DNS TTL to 60s | Day before |
| T-4h | Deploy to CH2, run smoke tests | Pre-cutover |
| T-2h | Warm up caches, connection pools | Pre-cutover |
| T-0 | Switch DNS CNAME to CH2 endpoint | Cutover |
| T+5min | Verify traffic flowing to CH2 | Post-cutover |
| T+1h | Check error rates, latency metrics | Post-cutover |
| T+48h | Decommission CH1 app | Cleanup |

#### 5. Monitoring Gaps
CH1 dashboard metrics do NOT transfer to CH2. You start with a blank monitoring baseline.
- Export CH1 metrics/alerts before migration as your target SLOs
- Set up CH2 alerts immediately (CPU > 80%, memory > 85%, 5xx rate > 1%)
- Consider external monitoring (Datadog, New Relic) that survives the migration

### Related
- [vpc-to-private-space](../vpc-to-private-space/) — Network migration
- [persistent-queues-to-mq](../persistent-queues-to-mq/) — Queue migration
- [properties-to-secure](../properties-to-secure/) — Secure properties
- [cicd-for-ch2](../../build-tools/cicd-for-ch2/) — CI/CD updates
