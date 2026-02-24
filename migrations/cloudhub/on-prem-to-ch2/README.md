## On-Premises to CloudHub 2.0 Migration
> Migrate Mule applications from on-premises runtime to CloudHub 2.0

### When to Use
- Moving from self-managed Mule runtime to MuleSoft-managed cloud
- Reducing infrastructure management overhead
- Need auto-scaling, zero-downtime deployments, and managed updates
- Consolidating on-prem and cloud deployments to a single platform

### Configuration / Code

#### 1. Audit On-Prem Configuration

```bash
# Document current on-prem settings
# Check Mule runtime version
$MULE_HOME/bin/mule -version

# List deployed applications
ls $MULE_HOME/apps/

# Check wrapper.conf for JVM settings
cat $MULE_HOME/conf/wrapper.conf | grep "wrapper.java"

# Check custom lib directory
ls $MULE_HOME/lib/user/

# Check domains
ls $MULE_HOME/domains/
```

#### 2. Externalize File-System Dependencies

```xml
<!-- Before: local file path (on-prem) -->
<file:config name="File_Config">
    <file:connection workingDir="/opt/mule/data/input" />
</file:config>

<!-- After: use Object Store or S3 -->
<s3:config name="S3_Config">
    <s3:connection
        accessKey="${secure::aws.accessKey}"
        secretKey="${secure::aws.secretKey}"
        region="us-east-1" />
</s3:config>
<flow name="fileProcessing">
    <s3:listener config-ref="S3_Config"
        bucketName="my-mule-data"
        prefix="input/">
        <scheduling-strategy>
            <fixed-frequency frequency="30000" />
        </scheduling-strategy>
    </s3:listener>
</flow>
```

#### 3. Replace Domain Shared Resources

```xml
<!-- On-prem: domain-level shared HTTP listener -->
<!-- File: $MULE_HOME/domains/api-domain/mule-domain-config.xml -->
<http:listener-config name="Shared_HTTP">
    <http:listener-connection host="0.0.0.0" port="8081" />
</http:listener-config>

<!-- CH2: each app defines its own listener (port 8081 is standard) -->
<http:listener-config name="HTTP_Listener">
    <http:listener-connection host="0.0.0.0" port="8081" />
</http:listener-config>
```

#### 4. Replace Local JDBC with Cloud Database

```xml
<!-- Before: local database connection -->
<db:config name="DB_Config">
    <db:my-sql-connection
        host="192.168.1.100"
        port="3306"
        database="mydb"
        user="${db.user}"
        password="${secure::db.password}" />
</db:config>

<!-- After: cloud database (RDS, Azure SQL, etc.) -->
<db:config name="DB_Config">
    <db:my-sql-connection
        host="${db.host}"
        port="3306"
        database="mydb"
        user="${db.user}"
        password="${secure::db.password}">
        <db:connection-properties>
            <db:connection-property key="useSSL" value="true" />
            <db:connection-property key="requireSSL" value="true" />
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>
```

#### 5. CloudHub 2.0 Deployment Configuration

```xml
<!-- pom.xml deployment config -->
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.1.1</version>
    <configuration>
        <cloudhub2Deployment>
            <uri>https://anypoint.mulesoft.com</uri>
            <muleVersion>4.6.0</muleVersion>
            <target>Shared Space</target>
            <provider>MC</provider>
            <environment>Production</environment>
            <replicas>2</replicas>
            <vCores>0.5</vCores>
            <applicationName>my-api</applicationName>
            <connectedAppClientId>${AP_CLIENT_ID}</connectedAppClientId>
            <connectedAppClientSecret>${AP_CLIENT_SECRET}</connectedAppClientSecret>
            <connectedAppGrantType>client_credentials</connectedAppGrantType>
        </cloudhub2Deployment>
    </configuration>
</plugin>
```

### How It Works
1. On-prem apps often depend on local file systems, network resources, and shared domains
2. CloudHub 2.0 runs in isolated containers — all external dependencies must be network-accessible
3. Shared resources (domains) are replaced by per-app configurations or API-led connectivity
4. File-based integrations are replaced by cloud storage (S3, Azure Blob) or Anypoint MQ

### Migration Checklist
- [ ] Inventory all on-prem dependencies (file paths, local DBs, shared domains, custom JARs)
- [ ] Replace local file system access with cloud storage connectors
- [ ] Replace domain shared resources with per-app configurations
- [ ] Move databases to cloud-accessible endpoints (RDS, Azure SQL, etc.)
- [ ] Add custom JARs from `lib/user/` as Maven dependencies or Mule plugins
- [ ] Externalize all configuration to properties files
- [ ] Encrypt sensitive properties
- [ ] Set up VPN or Private Space for connectivity to on-prem resources that cannot be cloud-migrated
- [ ] Deploy to CloudHub 2.0 staging and test
- [ ] Configure monitoring and alerting

### Gotchas
- On-prem apps that read/write local file systems need cloud storage alternatives
- Custom JARs in `$MULE_HOME/lib/user/` must be converted to proper Maven dependencies
- Domain-level shared resources (HTTP listeners, DB pools) do not exist in CloudHub 2.0
- Network latency to on-prem resources may increase — test performance
- CloudHub 2.0 has no persistent local disk — use Object Store for state

### Related
- [ch1-app-to-ch2](../ch1-app-to-ch2/) — CloudHub 1.0 to 2.0 migration
- [vpc-to-private-space](../vpc-to-private-space/) — Network connectivity
- [mule3-domains-to-mule4](../../architecture/mule3-domains-to-mule4/) — Domain migration
