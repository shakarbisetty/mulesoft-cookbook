## Exchange Publishing
> Automate asset publishing to Anypoint Exchange from CI/CD pipelines

### When to Use
- You want API specs, connectors, and templates published automatically on merge
- You need versioned assets in Exchange for discovery and reuse
- You want to automate the full lifecycle: publish, deprecate, and remove

### Configuration

**pom.xml — Exchange publishing configuration**
```xml
<distributionManagement>
    <repository>
        <id>anypoint-exchange-v3</id>
        <name>Anypoint Exchange</name>
        <url>https://maven.anypoint.mulesoft.com/api/v3/organizations/${anypoint.orgId}/maven</url>
        <layout>default</layout>
    </repository>
</distributionManagement>

<!-- For API specs (RAML/OAS) -->
<build>
    <plugins>
        <plugin>
            <groupId>org.mule.tools.maven</groupId>
            <artifactId>exchange-mule-maven-plugin</artifactId>
            <version>0.0.22</version>
            <executions>
                <execution>
                    <id>publish</id>
                    <phase>deploy</phase>
                    <goals>
                        <goal>exchange-deploy</goal>
                    </goals>
                </execution>
            </executions>
            <configuration>
                <classifier>oas</classifier>
            </configuration>
        </plugin>
    </plugins>
</build>
```

**settings.xml — authentication**
```xml
<servers>
    <server>
        <id>anypoint-exchange-v3</id>
        <username>~~~Client~~~</username>
        <password>${CONNECTED_APP_CLIENT_ID}~?~${CONNECTED_APP_CLIENT_SECRET}</password>
    </server>
</servers>
```

**publish-to-exchange.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

ASSET_TYPE="${1:-mule-application}"  # mule-application, raml, oas, custom

echo "=== Publishing to Exchange ==="

case "$ASSET_TYPE" in
    mule-application)
        echo "Publishing Mule application to Exchange..."
        mvn deploy -B \
            -DskipTests \
            -Danypoint.orgId="$ANYPOINT_ORG_ID"
        ;;

    raml|oas)
        echo "Publishing API spec to Exchange..."
        mvn deploy -B \
            -Danypoint.orgId="$ANYPOINT_ORG_ID"
        ;;

    custom)
        echo "Publishing custom asset via API..."
        # Get access token
        TOKEN=$(curl -s -X POST "https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token" \
            -H "Content-Type: application/json" \
            -d "{
                \"grant_type\": \"client_credentials\",
                \"client_id\": \"$CONNECTED_APP_CLIENT_ID\",
                \"client_secret\": \"$CONNECTED_APP_CLIENT_SECRET\"
            }" | jq -r '.access_token')

        # Create asset
        curl -X POST "https://anypoint.mulesoft.com/exchange/api/v2/assets" \
            -H "Authorization: Bearer $TOKEN" \
            -F "organizationId=$ANYPOINT_ORG_ID" \
            -F "groupId=$ANYPOINT_ORG_ID" \
            -F "assetId=order-api-docs" \
            -F "version=1.0.0" \
            -F "name=Order API Documentation" \
            -F "type=custom" \
            -F "properties.mainFile=index.html" \
            -F "files.index.html=@docs/index.html"
        ;;
esac

echo "Published to Exchange successfully."
```

**CI pipeline integration**
```yaml
publish:
  stage: publish
  script:
    - |
      mvn deploy -B \
          -DskipTests \
          -DmuleDeploy \
          -Danypoint.orgId="$ANYPOINT_ORG_ID"
  only:
    - tags
  environment:
    name: exchange
```

**Deprecate old versions**
```bash
# Deprecate an asset version
curl -X PATCH "https://anypoint.mulesoft.com/exchange/api/v2/assets/${ORG_ID}/order-api/1.0.0" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"status": "deprecated"}'

# Delete a specific version (use with caution)
curl -X DELETE "https://anypoint.mulesoft.com/exchange/api/v2/assets/${ORG_ID}/order-api/1.0.0" \
    -H "Authorization: Bearer $TOKEN"
```

### How It Works
1. `mvn deploy` with Exchange distribution management pushes the asset to Anypoint Exchange
2. The `~~~Client~~~` username signals Connected App authentication to the Exchange Maven facade
3. Assets are versioned following semver; each deploy creates a new version
4. Custom assets (docs, templates) use the Exchange REST API with multipart file upload
5. Published assets are immediately available for discovery, dependency resolution, and API Manager linking

### Gotchas
- The `groupId` in pom.xml must match your Anypoint Organization ID for Exchange publishing
- Connected App needs `Exchange Contributor` role to publish assets
- Publishing the same version twice fails; increment the version or use `-SNAPSHOT` for development
- RAML/OAS specs need the `exchange-mule-maven-plugin` with the correct classifier
- Large assets (>100MB) may timeout; adjust `maven.wagon.http.timeout` settings

### Related
- [cli-v4-recipes](../cli-v4-recipes/) — CLI for listing Exchange assets
- [api-manager-automation](../api-manager-automation/) — Link Exchange assets to API instances
- [no-rebuild-promotion](../../environments/no-rebuild-promotion/) — Reference Exchange artifacts by GAV
