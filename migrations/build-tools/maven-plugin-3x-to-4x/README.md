## Mule Maven Plugin 3.x to 4.x
> Migrate from Mule Maven Plugin 3.x to 4.x for Mule 4.6+ compatibility

### When to Use
- Upgrading to Mule 4.6+ runtime
- Need CloudHub 2.0 deployment support
- Maven plugin 3.x shows deprecation warnings
- Building CI/CD pipelines for modern Mule deployments

### Configuration / Code

#### 1. POM Plugin Update

```xml
<!-- Before: 3.x -->
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>3.8.7</version>
    <extensions>true</extensions>
</plugin>

<!-- After: 4.x -->
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.2.0</version>
    <extensions>true</extensions>
</plugin>
```

#### 2. CloudHub 2.0 Deployment Configuration

```xml
<configuration>
    <cloudhub2Deployment>
        <uri>https://anypoint.mulesoft.com</uri>
        <muleVersion>4.6.0</muleVersion>
        <target>Shared Space</target>
        <provider>MC</provider>
        <environment>Production</environment>
        <replicas>2</replicas>
        <vCores>0.5</vCores>
        <applicationName>${project.artifactId}</applicationName>
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
```

#### 3. Deployment Profiles

```xml
<profiles>
    <profile>
        <id>cloudhub2</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.mule.tools.maven</groupId>
                    <artifactId>mule-maven-plugin</artifactId>
                    <configuration>
                        <cloudhub2Deployment>
                            <!-- CH2 config -->
                        </cloudhub2Deployment>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
    <profile>
        <id>rtf</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.mule.tools.maven</groupId>
                    <artifactId>mule-maven-plugin</artifactId>
                    <configuration>
                        <runtimeFabricDeployment>
                            <!-- RTF config -->
                        </runtimeFabricDeployment>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

#### 4. Deploy Command

```bash
# CloudHub 2.0
mvn deploy -DmuleDeploy -Pcloudhub2

# Runtime Fabric
mvn deploy -DmuleDeploy -Prtf

# Local standalone
mvn deploy -DmuleDeploy -Pstandalone
```

### How It Works
1. Plugin 4.x adds `cloudhub2Deployment` configuration block
2. Connected Apps replace username/password authentication
3. Deployment profiles enable target-specific configurations
4. Plugin handles artifact upload, deployment, and status verification

### Migration Checklist
- [ ] Update plugin version to 4.x
- [ ] Replace `cloudHubDeployment` with `cloudhub2Deployment`
- [ ] Switch from username/password to Connected App credentials
- [ ] Update deployment profiles for each target environment
- [ ] Update CI/CD pipeline Maven commands
- [ ] Test deployment to each target

### Gotchas
- Plugin 3.x `cloudHubDeployment` is for CH1; `cloudhub2Deployment` is for CH2
- Connected App must have correct scopes for deployment
- Plugin 4.x requires Maven 3.8+
- `<extensions>true</extensions>` is still required

### Related
- [cicd-for-ch2](../cicd-for-ch2/) - CI/CD pipeline updates
- [ch1-app-to-ch2](../../cloudhub/ch1-app-to-ch2/) - CloudHub migration
- [platform-permissions](../../security/platform-permissions/) - Connected Apps setup
