## Bulk Connector Version Upgrade Strategy
> Systematically upgrade all Mule connectors across a portfolio of applications

### When to Use
- Runtime upgrade requires connector version bumps across many apps
- Security vulnerability requires specific connector patches
- Standardizing connector versions across a team/organization
- Preparing for major Mule runtime upgrade (4.4→4.6 or 4.6→4.9)

### Configuration / Code

#### 1. Audit Current Connector Versions

```bash
# Scan all POMs in a directory for connector versions
find /path/to/mule-apps -name "pom.xml" -exec grep -l "mule-plugin" {} \; | while read pom; do
    echo "=== $(dirname $pom) ==="
    grep -A2 "mule-.*-connector\|mule-.*-module" "$pom" | grep -E "artifactId|version"
done
```

#### 2. Connector Compatibility Matrix (Mule 4.6/4.9)

| Connector | Min for 4.6 | Recommended | Min for 4.9 |
|---|---|---|---|
| HTTP | 1.8.0 | 1.9.3 | 1.10.1 |
| Database | 1.14.0 | 1.14.6 | 1.15.2 |
| Salesforce | 10.18.0 | 10.20.0 | 11.2.0 |
| File | 1.5.0 | 1.5.2 | 1.6.0 |
| FTP | 1.6.0 | 1.6.3 | 1.7.0 |
| SFTP | 2.1.0 | 2.1.3 | 2.2.0 |
| JMS | 1.8.0 | 1.8.5 | 1.9.0 |
| VM | 2.0.0 | 2.0.1 | 2.1.0 |
| Email | 1.7.0 | 1.7.3 | 1.8.0 |
| ObjectStore | 1.2.0 | 1.2.2 | 1.3.0 |
| Anypoint MQ | 4.0.0 | 4.0.8 | 4.1.0 |

#### 3. Maven Versions Plugin — Automated Updates

```xml
<!-- Add to parent POM -->
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>versions-maven-plugin</artifactId>
    <version>2.16.2</version>
</plugin>
```

```bash
# Check for available updates
mvn versions:display-dependency-updates -pl .

# Automatically update to latest minor versions
mvn versions:use-latest-releases \
    -Dincludes="org.mule.connectors:*,com.mulesoft.connectors:*"

# Review changes
mvn versions:commit  # or versions:revert
```

#### 4. BOM (Bill of Materials) for Version Management

```xml
<!-- Parent POM: centralize connector versions -->
<dependencyManagement>
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
        <!-- ... more connectors ... -->
    </dependencies>
</dependencyManagement>
```

#### 5. Validation Script

```bash
#!/bin/bash
# validate-connectors.sh — Check all apps meet minimum versions
MIN_HTTP="1.8.0"
MIN_DB="1.14.0"

for pom in $(find . -name "pom.xml" -path "*/src/../pom.xml"); do
    app=$(dirname "$pom")
    http_ver=$(grep -A1 "mule-http-connector" "$pom" | grep version | sed 's/.*>\(.*\)<.*//')
    if [ -n "$http_ver" ]; then
        if [ "$(printf '%s
' "$MIN_HTTP" "$http_ver" | sort -V | head -n1)" != "$MIN_HTTP" ]; then
            echo "FAIL: $app HTTP connector $http_ver < $MIN_HTTP"
        fi
    fi
done
```

### How It Works
1. Connector versions are tied to runtime compatibility — each Mule version has minimum connector requirements
2. A BOM (Bill of Materials) in a parent POM ensures consistent versions across all apps
3. The Maven Versions Plugin automates discovery and update of outdated dependencies
4. Validation scripts in CI ensure no app falls below minimum versions

### Migration Checklist
- [ ] Audit current connector versions across all applications
- [ ] Build compatibility matrix for target runtime version
- [ ] Create or update parent BOM with approved connector versions
- [ ] Update each application POM
- [ ] Run MUnit tests per application
- [ ] Run integration tests in staging
- [ ] Add CI validation to prevent version regression

### Gotchas
- Major version jumps (e.g., Salesforce 10→11) often have breaking API changes
- Connector updates can change default behaviors (e.g., connection timeout values)
- Exchange-published custom connectors must be rebuilt for new runtime versions
- Some Enterprise connectors require separate license validation
- Always test connectors together — cross-connector interactions can surface issues

### Related
- [mule44-to-46](../mule44-to-46/) — Runtime 4.4 to 4.6 upgrade
- [mule46-to-49](../mule46-to-49/) — Runtime 4.6 to 4.9 upgrade
- [deprecated-connector-replacement](../../connectors/deprecated-connector-replacement/) — Replace deprecated connectors
