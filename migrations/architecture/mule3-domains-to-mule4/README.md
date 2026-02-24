## Mule 3 Domains to Mule 4 Domains
> Migrate Mule 3 domain projects to Mule 4 domain architecture

### When to Use
- Migrating Mule 3 apps that share domain-level resources
- Multiple Mule 4 apps need shared connector configurations
- Consolidating HTTP listener ports across applications
- Sharing JDBC connection pools between apps

### Configuration / Code

#### 1. Mule 3 Domain Structure

```xml
<!-- Mule 3: $MULE_HOME/domains/api-domain/mule-domain-config.xml -->
<mule-domain xmlns="http://www.mulesoft.org/schema/mule/domain">
    <http:connector name="shared-http" />
    <http:listener-config name="Shared_HTTP"
        host="0.0.0.0" port="8081" />
    <db:generic-config name="Shared_DB"
        url="jdbc:mysql://db:3306/mydb"
        driverClassName="com.mysql.jdbc.Driver" />
</mule-domain>
```

#### 2. Mule 4 Domain Structure

```
my-domain/
  src/main/mule/
    mule-domain-config.xml
  pom.xml
  mule-artifact.json
```

```xml
<!-- Mule 4: mule-domain-config.xml -->
<mule-domain
    xmlns="http://www.mulesoft.org/schema/mule/domain"
    xmlns:http="http://www.mulesoft.org/schema/mule/http"
    xmlns:db="http://www.mulesoft.org/schema/mule/db"
    xmlns:tls="http://www.mulesoft.org/schema/mule/tls">

    <!-- Shared HTTP Listener -->
    <http:listener-config name="Shared_HTTP_Listener">
        <http:listener-connection host="0.0.0.0" port="8081" />
    </http:listener-config>

    <!-- Shared HTTPS Listener -->
    <http:listener-config name="Shared_HTTPS_Listener">
        <http:listener-connection host="0.0.0.0" port="8443"
            protocol="HTTPS"
            tlsContext="Shared_TLS" />
    </http:listener-config>

    <tls:context name="Shared_TLS">
        <tls:key-store path="keystore.p12"
            password="${secure::keystore.password}"
            keyPassword="${secure::key.password}"
            type="pkcs12" />
    </tls:context>

    <!-- Shared Database Config -->
    <db:config name="Shared_DB">
        <db:my-sql-connection host="${db.host}" port="3306"
            database="${db.name}" user="${db.user}"
            password="${secure::db.password}">
            <db:pooling-profile maxPoolSize="20" minPoolSize="5" />
        </db:my-sql-connection>
    </db:config>
</mule-domain>
```

#### 3. Domain POM

```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.mycompany</groupId>
    <artifactId>api-domain</artifactId>
    <version>1.0.0</version>
    <packaging>mule-domain</packaging>

    <properties>
        <mule.version>4.6.0</mule.version>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <version>4.2.0</version>
                <extensions>true</extensions>
            </plugin>
        </plugins>
    </build>

    <dependencies>
        <dependency>
            <groupId>org.mule.connectors</groupId>
            <artifactId>mule-http-connector</artifactId>
            <version>1.9.3</version>
            <classifier>mule-plugin</classifier>
        </dependency>
        <dependency>
            <groupId>org.mule.connectors</groupId>
            <artifactId>mule-db-connector</artifactId>
            <version>1.14.6</version>
            <classifier>mule-plugin</classifier>
        </dependency>
    </dependencies>
</project>
```

#### 4. App Referencing Domain

```xml
<!-- App's mule-artifact.json -->
{
    "minMuleVersion": "4.6.0",
    "domain": "api-domain"
}
```

```xml
<!-- App's flow referencing shared config -->
<flow name="customerFlow">
    <http:listener config-ref="Shared_HTTP_Listener" path="/customers" />
    <db:select config-ref="Shared_DB">
        <db:sql>SELECT * FROM customers</db:sql>
    </db:select>
</flow>
```

### How It Works
1. Domain projects package shared configurations (listeners, DB pools, TLS)
2. Applications reference the domain in `mule-artifact.json`
3. All apps sharing a domain use the same port/connection pool
4. Domain is deployed first; dependent apps are deployed after

### Migration Checklist
- [ ] Inventory Mule 3 domain shared resources
- [ ] Create Mule 4 domain project with equivalent configs
- [ ] Update connector versions in domain POM
- [ ] Deploy domain to target runtime
- [ ] Update each app's `mule-artifact.json` to reference domain
- [ ] Remove redundant configs from individual apps
- [ ] Test all apps referencing the shared domain

### Gotchas
- Domains only work on-prem and RTF; CloudHub 2.0 does NOT support domains
- For CloudHub 2.0, each app must define its own configs (port 8081 is shared by the platform)
- Domain changes require redeployment of all dependent apps
- Connector versions in domain must be compatible with all dependent apps
- Domain packaging type is `mule-domain`, not `mule-application`

### Related
- [on-prem-to-ch2](../../cloudhub/on-prem-to-ch2/) - CloudHub migration (no domains)
- [monolith-to-api-led](../monolith-to-api-led/) - Architecture decomposition
- [mule3-to-4-mma](../../runtime-upgrades/mule3-to-4-mma/) - Mule 3 to 4 migration
