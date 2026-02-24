## Mule 4.4 to 4.6 Upgrade
> Upgrade Mule runtime from 4.4 to 4.6: Java 11 minimum, new features, and connector compatibility

### When to Use
- Current apps run on Mule 4.4.x and need 4.6 features
- Java 11 is now your minimum JDK (Mule 4.6 drops Java 8 support)
- Need DataWeave 2.5+ features (improved error handling, new functions)
- Preparing for eventual Mule 4.9 / Java 17 upgrade path

### Configuration / Code

#### 1. Update POM Runtime Version

```xml
<properties>
    <app.runtime>4.6.0</app.runtime>
    <mule.maven.plugin.version>4.1.1</mule.maven.plugin.version>
</properties>

<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>${mule.maven.plugin.version}</version>
    <extensions>true</extensions>
    <configuration>
        <runtimeVersion>${app.runtime}</runtimeVersion>
    </configuration>
</plugin>
```

#### 2. Verify Java 11 Compliance

```bash
# Mule 4.6 requires Java 11+ — verify
java -version
# Expected: openjdk version "11.0.x" or higher

# Set JAVA_HOME if needed
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
```

#### 3. Update Connector Versions (Minimum Compatible)

```xml
<!-- HTTP Connector: 1.8.0+ for Mule 4.6 -->
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-http-connector</artifactId>
    <version>1.9.3</version>
    <classifier>mule-plugin</classifier>
</dependency>

<!-- Database Connector: 1.14.0+ -->
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-db-connector</artifactId>
    <version>1.14.6</version>
    <classifier>mule-plugin</classifier>
</dependency>

<!-- Salesforce Connector: 10.18.0+ -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>10.18.4</version>
    <classifier>mule-plugin</classifier>
</dependency>

<!-- File Connector: 1.5.0+ -->
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-file-connector</artifactId>
    <version>1.5.2</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 4. New DataWeave 2.5 Features Available

```dataweave
%dw 2.0
output application/json

// New in DW 2.5: improved error handling
var result = try(() -> payload.items map $.price) orElse []

// New: do block with local variables
var computed = do {
    var base = payload.amount
    var tax = base * 0.08
    ---
    base + tax
}
---
{
    items: result,
    total: computed
}
```

### How It Works
1. Mule 4.6 sets Java 11 as the minimum runtime requirement, dropping Java 8 support
2. DataWeave engine upgrades to 2.5 with improved error handling and new functions
3. Connector compatibility matrix changes — older connector versions may not work
4. CloudHub 2.0 deployment model becomes the recommended target

### Migration Checklist
- [ ] Verify all environments run Java 11+
- [ ] Update `app.runtime` to `4.6.0` in POM
- [ ] Update all connectors to 4.6-compatible versions
- [ ] Update `mule-maven-plugin` to 4.1.1+
- [ ] Run full MUnit suite — fix any DataWeave behavioral changes
- [ ] Test on local Mule 4.6 runtime before deploying
- [ ] Update CloudHub runtime version in deployment configs
- [ ] Review release notes for deprecated features

### Gotchas
- Java 8 builds will fail — ensure CI/CD uses JDK 11+
- Some community connectors may lag behind on 4.6 compatibility
- DataWeave 2.5 may have subtle behavioral differences in edge cases (null handling, type coercion)
- On-prem runtime upgrade requires Tanuki Wrapper update
- MUnit version must be compatible — use 2.3.x+ for Mule 4.6

### Related
- [java8-to-11](../../java-versions/java8-to-11/) — Java 8 to 11 migration
- [mule46-to-49](../mule46-to-49/) — Next upgrade: 4.6 to 4.9
- [connector-bulk-upgrade](../connector-bulk-upgrade/) — Bulk connector updates
- [maven-plugin-3x-to-4x](../../build-tools/maven-plugin-3x-to-4x/) — Maven plugin migration
