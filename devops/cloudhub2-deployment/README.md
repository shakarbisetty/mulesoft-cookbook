# CloudHub 2.0 Deployment Guide

> Deploy, scale, and manage Mule applications on CloudHub 2.0 — architecture, networking, autoscaling, and monitoring.

## CloudHub 2.0 vs CloudHub 1.0

CloudHub 2.0 runs on Kubernetes (AWS EKS) instead of dedicated VMs. Key differences:

| Feature | CloudHub 1.0 | CloudHub 2.0 |
|---------|-------------|-------------|
| **Compute** | EC2 instances per worker | Kubernetes pods per replica |
| **Clustering** | No native clustering | Native Mule cluster (replicas > 1) |
| **Network isolation** | VPC | Private Space (single-tenant) |
| **Connectivity** | VPC Peering, Direct Connect | VPN, Transit Gateway |
| **vCore sizes** | Fixed tiers | 14 fractional tiers (0.1 to 4.0) |
| **Persistent queues** | Supported | Not supported — use Anypoint MQ |
| **Custom Log4j** | Support ticket required | Self-service |
| **Min Mule version** | 3.x | 4.3.0+ |
| **TLS** | 1.0+ | 1.1+ only |

## Shared Spaces vs Private Spaces

| Dimension | Shared Space | Private Space |
|-----------|-------------|---------------|
| **Tenancy** | Multi-tenant | Single-tenant, isolated |
| **On-prem connectivity** | Not available | VPN or Transit Gateway |
| **Custom domains/TLS** | Not available | Full support |
| **Egress control** | Unrestricted | Configurable firewall rules |
| **Use case** | Public APIs, dev/test | Production, regulated workloads |

## Deployment via Maven

### `pom.xml` Configuration

```xml
<plugin>
  <groupId>org.mule.tools.maven</groupId>
  <artifactId>mule-maven-plugin</artifactId>
  <version>4.6.0</version>
  <extensions>true</extensions>
  <configuration>
    <cloudhub2Deployment>
      <uri>https://anypoint.mulesoft.com</uri>
      <provider>MC</provider>
      <target>Cloudhub-US-East-1</target>
      <environment>${environment}</environment>
      <muleVersion>4.6.0</muleVersion>
      <applicationName>${appName}</applicationName>

      <connectedAppClientId>${app.client_id}</connectedAppClientId>
      <connectedAppClientSecret>${app.client_secret}</connectedAppClientSecret>
      <connectedAppGrantType>client_credentials</connectedAppGrantType>

      <replicas>2</replicas>
      <vCores>0.5</vCores>

      <properties>
        <env>${environment}</env>
      </properties>
      <secureProperties>
        <db.password>${db.password}</db.password>
      </secureProperties>

      <deploymentSettings>
        <updateStrategy>rolling</updateStrategy>
        <clustered>true</clustered>
        <enforceDeployingReplicasAcrossNodes>true</enforceDeployingReplicasAcrossNodes>
        <persistentObjectStore>true</persistentObjectStore>
        <http>
          <inbound>
            <lastMileSecurity>true</lastMileSecurity>
            <forwardSslSession>true</forwardSslSession>
            <pathRewrite>/api</pathRewrite>
          </inbound>
        </http>
      </deploymentSettings>

      <integrations>
        <services>
          <objectStoreV2>
            <enabled>true</enabled>
          </objectStoreV2>
        </services>
      </integrations>
    </cloudhub2Deployment>
  </configuration>
</plugin>
```

### vCore Sizing

| vCores | Memory | Use Case |
|--------|--------|----------|
| 0.1 | 500 MB | DEV/testing |
| 0.2 | 1 GB | Light workloads |
| 0.5 | 1.5 GB | Standard APIs |
| 1.0 | 3.5 GB | High-traffic APIs |
| 2.0 | 7.5 GB | Heavy processing |
| 4.0 | 15 GB | Enterprise workloads |

## Deployment via Anypoint CLI v4

### Install and Authenticate

```bash
npm install -g anypoint-cli-v4

# Connected App auth
anypoint-cli-v4 conf client_id YOUR_CLIENT_ID
anypoint-cli-v4 conf client_secret YOUR_CLIENT_SECRET
```

### Deploy

```bash
anypoint-cli-v4 runtime-mgr:application:deploy \
  my-api \
  us-east-1 \
  4.6.0 \
  my-api-1.0.0 \
  --name my-api-prod \
  --replicas 2 \
  --replicaSize 0.5 \
  --javaVersion 17 \
  --releaseChannel LTS \
  --updateStrategy rolling \
  --clustered \
  --objectStoreV2 \
  --property db.host:prod-db.internal \
  --secureProperty db.password:s3cr3t
```

### Manage

```bash
# List apps
anypoint-cli-v4 runtime-mgr:application:list --output table

# Scale up
anypoint-cli-v4 runtime-mgr:application:modify my-api --replicas 3

# View logs
anypoint-cli-v4 runtime-mgr:application:logs my-api

# Stop / start / delete
anypoint-cli-v4 runtime-mgr:application:stop my-api
anypoint-cli-v4 runtime-mgr:application:start my-api
anypoint-cli-v4 runtime-mgr:application:delete my-api
```

## Update Strategies

### Rolling Update (Default)

- Replicas updated one at a time
- Old version serves traffic while new version starts
- Zero downtime
- Requires backward-compatible changes

```xml
<updateStrategy>rolling</updateStrategy>
```

### Recreate

- All replicas terminated, then new replicas start
- Brief downtime
- Use when Mule runtime upgrade changes Hazelcast version, or app is stateful

```xml
<updateStrategy>recreate</updateStrategy>
```

## Horizontal Autoscaling

CloudHub 2.0 autoscaling monitors CPU and adds/removes replicas automatically.

### Configuration

```xml
<deploymentSettings>
  <autoscaling>
    <enabled>true</enabled>
    <minReplicas>1</minReplicas>
    <maxReplicas>8</maxReplicas>
  </autoscaling>
</deploymentSettings>
```

### Behavior

| Action | Trigger | Cooldown |
|--------|---------|----------|
| **Scale up** | CPU > 70% average | 180 seconds between scale events |
| **Scale down** | CPU < 70% sustained | 1800 seconds (30 min) stabilization window |

**Max replicas:** 8 (Standard), 16 (Advanced/Platinum/Titanium)

**Eligible replica sizes:** Micro, Micro.Mem, Small only

## Private Space Networking

### Anypoint VPN

IPsec tunnel connecting CloudHub 2.0 to on-premises networks:
- Two tunnels per VPN connection (HA — always configure both)
- Max throughput: 1.25 Gbps per Virtual Gateway
- Max route table entries: 95 per private space

### Transit Gateway

Connects CloudHub 1.0 VPCs to CloudHub 2.0 private spaces:
- VPC, Private Space, and TGW must be in the same AWS region
- Use when migrating from CH1 to CH2

### Built-in Ingress Load Balancer

Every Private Space gets an auto-scaling ingress load balancer. No separate Dedicated Load Balancer (DLB) needed (unlike CH1).

### Custom Domains and TLS (Private Space Only)

1. Add custom domain in Runtime Manager > Private Spaces
2. Create TLS context with PEM or JKS certificate
3. Create CNAME record pointing to private space FQDN
4. For mTLS: add Truststore with client CA certificates

## Object Store V2

Enabled by default in CloudHub 2.0:

```xml
<os:object-store
  name="myStore"
  entryTtl="3600"
  entryTtlUnit="SECONDS"
  persistent="true" />
```

| Setting | Limit |
|---------|-------|
| Entry TTL | 0 to 2,592,000 seconds (30 days) |
| Encryption | FIPS 140-2 at rest, TLS in transit |
| Key constraints | No pipe character (`\|`), spaces converted to `+` |

For multi-replica apps, use `acquireLock` operation to prevent race conditions.

## Monitoring and Logging

### Built-in (Runtime Manager)

- Per-replica CPU and memory dashboards
- Log streams with severity filter
- Log retention: 100 MB or 30 days per config
- Deployment alerts (success/failure)

### External Log Forwarding (Log4j2)

CloudHub 2.0 supports custom `log4j2.xml` without a Support ticket. Place in `src/main/resources/`.

**Constraint:** Only asynchronous appenders are allowed. File appenders are stripped.

#### Example: Splunk

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="INFO" packages="com.splunk.logging">
  <Appenders>
    <Console name="CONSOLE" target="SYSTEM_OUT">
      <PatternLayout pattern="[%d{MM-dd HH:mm:ss}] %-5p %c{1}: %m%n"/>
    </Console>
    <SplunkHttp name="SPLUNK"
      url="${sys:splunk.host}" token="${sys:splunk.token}"
      source="${env:APP_NAME}" sourceType="mule-app" index="main">
      <PatternLayout pattern="[%d{MM-dd HH:mm:ss}] %-5p %c{1}: %m%n"/>
    </SplunkHttp>
  </Appenders>
  <Loggers>
    <AsyncRoot level="INFO">
      <AppenderRef ref="CONSOLE"/>
      <AppenderRef ref="SPLUNK"/>
    </AsyncRoot>
  </Loggers>
</Configuration>
```

Add dependency:
```xml
<dependency>
  <groupId>com.splunk.logging</groupId>
  <artifactId>splunk-library-javalogging</artifactId>
  <version>1.11.5</version>
</dependency>
```

## Migration from CloudHub 1.0

Key changes when migrating:

1. **Replace persistent queues** with Anypoint MQ
2. **Replace CloudHub Connector** with Object Store or HTTP operations
3. **Replace Insights** with Anypoint Monitoring
4. **Update VPC peering** to VPN or Transit Gateway
5. **Test with `recreate` strategy first** if changing Mule runtime version

## Common Gotchas

- **`pathRewrite` placement** — in plugin v4.4.0+, must be inside `<http><inbound>`, not at parent level
- **Persistent queues don't exist** — Anypoint MQ is the replacement
- **Mixed Hazelcast versions** — use `recreate` strategy when upgrading Mule runtime with clustering enabled
- **VPN tunnel redundancy** — always configure both tunnels; MuleSoft maintenance can disable one
- **Route table limit** — 95 entries per private space across all VPN connections
- **Log4j file appenders stripped** — only async appenders work in CH2
- **Autoscaling billing** — scale-out increases flow usage; monitor via usage reports

## References

- [CloudHub 2.0 Architecture](https://docs.mulesoft.com/cloudhub-2/ch2-architecture)
- [CH2 vs CH1 Comparison](https://docs.mulesoft.com/cloudhub-2/ch2-comparison)
- [Private Spaces](https://docs.mulesoft.com/cloudhub-2/ch2-private-space-about)
- [Horizontal Autoscaling](https://docs.mulesoft.com/cloudhub-2/ch2-configure-horizontal-autoscaling)
- [Updating Applications](https://docs.mulesoft.com/cloudhub-2/ch2-update-apps)
- [CLI for CloudHub 2.0](https://docs.mulesoft.com/anypoint-cli/latest/cloudhub2-apps)
- [Deploy via Maven](https://docs.mulesoft.com/mule-runtime/latest/deploy-to-cloudhub-2)
- [Custom Domains and TLS](https://docs.mulesoft.com/cloudhub-2/ps-config-domains)
- [Log Integration](https://docs.mulesoft.com/cloudhub-2/ch2-integrate-log-system)
- [Object Store V2](https://docs.mulesoft.com/object-store/osv2-guide)
