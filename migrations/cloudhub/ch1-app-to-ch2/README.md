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

### Related
- [vpc-to-private-space](../vpc-to-private-space/) — Network migration
- [persistent-queues-to-mq](../persistent-queues-to-mq/) — Queue migration
- [properties-to-secure](../properties-to-secure/) — Secure properties
- [cicd-for-ch2](../../build-tools/cicd-for-ch2/) — CI/CD updates
