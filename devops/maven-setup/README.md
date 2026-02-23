# Maven Setup for MuleSoft

> Get the Mule Maven Plugin configured correctly the first time — authentication, deployment targets, and common fixes.

## Mule Maven Plugin Versions

| Version | Java | Key Feature |
|---------|------|-------------|
| 4.4.0 | 17 | CloudHub 2.0 deployment, pathRewrite nesting change |
| 4.6.0 | 21 | Java 21 support, latest stable |

## Step 1: Add Plugin to `pom.xml`

```xml
<properties>
  <mule.maven.plugin.version>4.6.0</mule.maven.plugin.version>
</properties>

<build>
  <plugins>
    <plugin>
      <groupId>org.mule.tools.maven</groupId>
      <artifactId>mule-maven-plugin</artifactId>
      <version>${mule.maven.plugin.version}</version>
      <extensions>true</extensions>
    </plugin>
  </plugins>
</build>

<pluginRepositories>
  <pluginRepository>
    <id>mule-public</id>
    <url>https://repository.mulesoft.org/nexus/content/repositories/releases</url>
  </pluginRepository>
</pluginRepositories>
```

## Step 2: Configure Authentication

### Connected App (recommended for CI/CD)

Create a Connected App in Anypoint Platform:
1. Go to **Access Management > Connected Apps**
2. Click **Create App** > **App acts on its own behalf**
3. Add scopes: Runtime Manager, Exchange Contributor, API Manager
4. Select all business groups and environments
5. Save the Client ID and Client Secret

### `settings.xml` (for Maven server reference)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings>
  <servers>
    <server>
      <id>anypoint-exchange-v3</id>
      <username>~~~Client~~~</username>
      <password>YOUR_CLIENT_ID~?~YOUR_CLIENT_SECRET</password>
    </server>
  </servers>
  <pluginGroups>
    <pluginGroup>org.mule.tools</pluginGroup>
  </pluginGroups>
</settings>
```

For CI/CD, use environment variables instead of hardcoded values:
```xml
<password>${env.CONNECTED_APP_CLIENT_ID}~?~${env.CONNECTED_APP_CLIENT_SECRET}</password>
```

### Authentication Methods

| Method | Element | Use When |
|--------|---------|----------|
| Connected App (settings.xml) | `<server>` reference | CI/CD pipelines |
| Connected App (inline) | `<connectedAppClientId>` + `<connectedAppClientSecret>` | Quick local testing |
| Auth token | `<authToken>` | Short-lived automation |
| Username/password | `<username>` + `<password>` | Never in CI |

## Step 3: Configure CloudHub 2.0 Deployment

```xml
<plugin>
  <groupId>org.mule.tools.maven</groupId>
  <artifactId>mule-maven-plugin</artifactId>
  <version>${mule.maven.plugin.version}</version>
  <extensions>true</extensions>
  <configuration>
    <cloudhub2Deployment>
      <uri>https://anypoint.mulesoft.com</uri>
      <provider>MC</provider>
      <target>Cloudhub-US-East-1</target>
      <environment>${environment}</environment>
      <muleVersion>4.6.0</muleVersion>
      <applicationName>${appName}</applicationName>

      <connectedAppClientId>${connectedApp.clientId}</connectedAppClientId>
      <connectedAppClientSecret>${connectedApp.clientSecret}</connectedAppClientSecret>
      <connectedAppGrantType>client_credentials</connectedAppGrantType>

      <replicas>1</replicas>
      <vCores>0.1</vCores>

      <properties>
        <env>${environment}</env>
        <http.port>8081</http.port>
      </properties>

      <secureProperties>
        <db.password>${db.password}</db.password>
      </secureProperties>

      <deploymentSettings>
        <http>
          <inbound>
            <lastMileSecurity>true</lastMileSecurity>
            <!-- v4.4.0+: pathRewrite MUST be here -->
            <pathRewrite>/api</pathRewrite>
          </inbound>
        </http>
        <updateStrategy>rolling</updateStrategy>
        <enforceDeployingReplicasAcrossNodes>true</enforceDeployingReplicasAcrossNodes>
        <persistentObjectStore>true</persistentObjectStore>
      </deploymentSettings>

      <deploymentTimeout>600000</deploymentTimeout>
    </cloudhub2Deployment>
  </configuration>
</plugin>
```

### vCore Options

| vCores | Memory | Use Case |
|--------|--------|----------|
| 0.1 | 500 MB | DEV/testing |
| 0.2 | 1 GB | Light workloads |
| 0.5 | 1.5 GB | Standard APIs |
| 1.0 | 3.5 GB | High-traffic APIs |
| 2.0 | 7.5 GB | Heavy processing |

## Step 4: Configure Exchange Publishing

```xml
<distributionManagement>
  <repository>
    <id>anypoint-exchange-v3</id>
    <name>Exchange Repository</name>
    <url>https://maven.anypoint.mulesoft.com/api/v3/organizations/${org.id}/maven</url>
  </repository>
</distributionManagement>

<repositories>
  <repository>
    <id>anypoint-exchange-v3</id>
    <name>Exchange Repository</name>
    <url>https://maven.anypoint.mulesoft.com/api/v3/organizations/${org.id}/maven</url>
  </repository>
</repositories>
```

## Maven Commands Reference

```bash
# Build only
mvn clean package

# Build + deploy to CloudHub 2.0
mvn clean deploy -DmuleDeploy -s settings.xml

# Deploy pre-built artifact (skip rebuild)
mvn mule:deploy -Dmule.artifact=target/my-app-1.0.0-mule-application.jar

# Undeploy
mvn mule:undeploy

# Deploy with Maven profile
mvn clean deploy -DmuleDeploy -Pprod -s settings.xml
```

## Common Gotchas

- **`~~~Client~~~` is literal** — use this exact string as `<username>` for Connected App auth
- **Separator is `~?~`** — `clientId~?~clientSecret` in the password field
- **`pathRewrite` moved in v4.4.0** — must be nested inside `<http><inbound>`, not at deployment settings root
- **`<extensions>true</extensions>` is required** — without it, the `mule-application` packaging type isn't recognized
- **Plugin repository must be declared** — Mule Maven Plugin isn't in Maven Central
- **`-DmuleDeploy` flag is required** — without it, `mvn deploy` only publishes to Exchange, doesn't deploy the app

## References

- [Mule Maven Plugin](https://docs.mulesoft.com/mule-runtime/latest/mmp-concept)
- [Deploy to CloudHub 2.0](https://docs.mulesoft.com/mule-runtime/latest/deploy-to-cloudhub-2)
- [Plugin 4.6.0 Release Notes](https://docs.mulesoft.com/release-notes/mule-maven-plugin/mule-maven-plugin-4.6.0-release-notes)
- [Connected App Authentication](https://docs.mulesoft.com/access-management/connected-apps-overview)
