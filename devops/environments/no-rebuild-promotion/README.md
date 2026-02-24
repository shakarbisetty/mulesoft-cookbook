## No-Rebuild Promotion
> Promote the same JAR artifact across DEV, QA, and PROD without rebuilding

### When to Use
- You want to guarantee that the exact binary tested in QA is the one deployed to PROD
- Your compliance/audit requirements mandate artifact immutability
- You need to eliminate "works on my machine" issues caused by non-deterministic builds

### Configuration

**pom.xml — externalize all environment-specific values**
```xml
<configuration>
    <cloudhub2Deployment>
        <uri>https://anypoint.mulesoft.com</uri>
        <connectedAppClientId>${anypoint.connectedApp.clientId}</connectedAppClientId>
        <connectedAppClientSecret>${anypoint.connectedApp.clientSecret}</connectedAppClientSecret>
        <connectedAppGrantType>client_credentials</connectedAppGrantType>
        <environment>${deploy.environment}</environment>
        <businessGroup>${anypoint.businessGroup}</businessGroup>
        <target>${cloudhub2.target}</target>
        <replicas>${cloudhub2.replicas}</replicas>
        <vCores>${cloudhub2.vCores}</vCores>
        <properties>
            <api.id>${api.id}</api.id>
            <env>${deploy.environment}</env>
            <db.host>${db.host}</db.host>
            <db.port>${db.port}</db.port>
        </properties>
    </cloudhub2Deployment>
</configuration>
```

**deploy.sh — reusable promotion script**
```bash
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_PATH="$1"
ENV_NAME="$2"
PROPERTIES_FILE="config/${ENV_NAME,,}.properties"

if [ ! -f "$ARTIFACT_PATH" ]; then
    echo "ERROR: Artifact not found: $ARTIFACT_PATH"
    exit 1
fi

if [ ! -f "$PROPERTIES_FILE" ]; then
    echo "ERROR: Properties file not found: $PROPERTIES_FILE"
    exit 1
fi

echo "Deploying $(basename "$ARTIFACT_PATH") to $ENV_NAME..."

# Read properties file and pass as Maven args
MAVEN_PROPS=""
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    MAVEN_PROPS="$MAVEN_PROPS -D${key}=${value}"
done < "$PROPERTIES_FILE"

mvn mule:deploy -B \
    -Dmule.artifact="$ARTIFACT_PATH" \
    -Ddeploy.environment="$ENV_NAME" \
    $MAVEN_PROPS

echo "Deployment to $ENV_NAME complete."
```

**config/dev.properties**
```properties
anypoint.connectedApp.clientId=${CONNECTED_APP_ID}
anypoint.connectedApp.clientSecret=${CONNECTED_APP_SECRET}
anypoint.businessGroup=MyOrg
cloudhub2.target=us-east-2
cloudhub2.replicas=1
cloudhub2.vCores=0.1
api.id=19283746
db.host=dev-db.internal
db.port=5432
```

### How It Works
1. Build once in the CI build stage; archive the JAR as a pipeline artifact
2. Each deploy stage downloads the same artifact and passes environment-specific properties via Maven `-D` flags
3. The Mule app reads properties from Runtime Manager at startup (not baked into the JAR)
4. The JAR contains zero environment-specific values — all configuration is external
5. Promotion is simply: download artifact + apply target env properties + deploy

### Gotchas
- The JAR must NOT contain hardcoded property files with env-specific values; use `${property}` placeholders everywhere
- Runtime Manager properties override `mule-artifact.json` properties, which override defaults in config YAML
- Artifact checksums (SHA-256) should be verified before each promotion to ensure immutability
- If you use Exchange for artifact storage, publish once and reference by GAV coordinates in deploy stages
- Ensure all environments use the same Mule runtime version to avoid compatibility issues

### Related
- [property-externalization](../property-externalization/) — External YAML per environment
- [secure-properties](../secure-properties/) — Encrypt sensitive values
- [gitlab-ci](../../cicd-pipelines/gitlab-ci/) — Pipeline that implements this pattern
