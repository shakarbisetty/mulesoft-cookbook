## Mule 4.10 to 4.11 Upgrade
> Upgrade from Mule 4.10 Edge to 4.11 LTS: Jakarta EE namespace migration, DataWeave 2.10, and long-term support stability

### When to Use
- Running Mule 4.10 Edge and need to move to a long-term supported release
- Need DataWeave 2.10 features (native logging, decimal math, enhanced pattern matching)
- Must migrate from `javax.*` to `jakarta.*` namespace before support deadline
- Want production-grade runtime with 2+ years of security patches
- Preparing for enterprise compliance that requires LTS versions only

### Configuration / Code

#### 1. Update POM Runtime and Plugin Versions

```xml
<!-- Before (4.10 Edge) -->
<properties>
    <app.runtime>4.10.0-edge</app.runtime>
    <mule.maven.plugin.version>4.3.0</mule.maven.plugin.version>
    <munit.version>3.3.0</munit.version>
</properties>

<!-- After (4.11 LTS) -->
<properties>
    <app.runtime>4.11.0</app.runtime>
    <mule.maven.plugin.version>4.4.0</mule.maven.plugin.version>
    <munit.version>3.4.0</munit.version>
</properties>
```

#### 2. Jakarta EE Namespace Migration

```xml
<!-- Before: javax namespace (deprecated in 4.11) -->
<dependency>
    <groupId>javax.servlet</groupId>
    <artifactId>javax.servlet-api</artifactId>
    <version>4.0.1</version>
</dependency>

<!-- After: jakarta namespace -->
<dependency>
    <groupId>jakarta.servlet</groupId>
    <artifactId>jakarta.servlet-api</artifactId>
    <version>6.0.0</version>
</dependency>
```

```java
// Before — custom Java component
import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;

// After — Jakarta namespace
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
```

#### 3. Minimum Connector Version Table

| Connector | Min Version for 4.11 | Key Change |
|-----------|----------------------|------------|
| HTTP | 1.12.0 | Jakarta servlet, HTTP/2 GA |
| Database | 1.17.0 | Jakarta persistence, connection pool improvements |
| Salesforce | 11.4.0 | Jakarta namespace, bulk API v2 |
| File | 1.7.0 | NIO.2 improvements |
| FTP/SFTP | 2.2.0 | Jakarta namespace migration |
| Email | 1.8.0 | Jakarta Mail API |
| JMS | 1.10.0 | Jakarta JMS 3.0 |
| VM | 2.1.0 | Internal optimization |
| ObjectStore | 1.4.0 | Serialization update |
| Anypoint MQ | 4.1.0 | Performance improvements |

#### 4. Update All Connectors

```xml
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-http-connector</artifactId>
    <version>1.12.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-db-connector</artifactId>
    <version>1.17.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-jms-connector</artifactId>
    <version>1.10.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-email-connector</artifactId>
    <version>1.8.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 5. DataWeave 2.10 Features Now Available

```dataweave
%dw 2.0
import decimalAdd, decimalRound from dw::util::Math
output application/json

// Native logging — no more Set Variable + Logger workaround
var _ = logInfo("Processing $(sizeOf(payload.items)) items")

// Decimal math — exact financial calculations
var total = payload.items reduce (item, acc = 0) ->
    decimalAdd(acc, decimalRound(item.price * item.quantity, 2))
---
{
    total: total,
    itemCount: sizeOf(payload.items)
}
```

#### 6. Rollback Plan

```bash
#!/bin/bash
# Rollback from 4.11 to 4.10 if critical issues found

# 1. Revert POM changes
git checkout HEAD~1 -- pom.xml

# 2. On-prem: switch runtime symlink
cd /opt/mule
ln -sfn mule-enterprise-standalone-4.10.0 current

# 3. CloudHub 2.0: redeploy with previous runtime
anypoint-cli runtime-mgr cloudhub-application modify \
  --runtime "4.10.0" \
  my-app

# 4. Verify rollback
curl -s https://my-app.cloudhub.io/api/health | jq .runtime
```

### How It Works
1. Mule 4.11 is the first LTS release with full Jakarta EE 10 namespace support, replacing all `javax.*` references
2. DataWeave 2.10 ships natively with 4.11, providing `logInfo`, `logWarn`, `logError`, `logDebug` and decimal math functions
3. The runtime enforces minimum connector versions — connectors below the threshold fail at deployment with a clear error message
4. Performance improvements include optimized thread scheduling, reduced memory footprint for idle flows, and faster cold start times
5. LTS means 24 months of bug fixes and security patches, with an additional 12 months of critical-only patches
6. The Mule Maven Plugin 4.4.0 validates Jakarta namespace compliance at build time

### Migration Checklist
- [ ] Update `app.runtime` to `4.11.0` in POM
- [ ] Update `mule-maven-plugin` to 4.4.0
- [ ] Update MUnit to 3.4.0
- [ ] Update ALL connectors to minimum versions (see table above)
- [ ] Search and replace `javax.` to `jakarta.` in all custom Java code
- [ ] Update third-party libraries that depend on javax namespace
- [ ] Test DataWeave 2.10 features (logging, decimal math) in staging
- [ ] Run full regression suite on 4.11 runtime
- [ ] Deploy to staging on CloudHub 2.0 with 4.11 runtime
- [ ] Monitor for 48 hours before promoting to production
- [ ] Document rollback procedure and test it in staging

### Gotchas
- **javax to jakarta is not optional**: While 4.11 includes a compatibility bridge for most `javax.*` imports, this bridge is deprecated from day one. Custom Java code must migrate to `jakarta.*` to avoid runtime warnings and future breakage.
- **Third-party library chain**: Your custom Java modules may depend on libraries that still use `javax.*`. Use `jdeps --multi-release 17 --print-module-deps` to identify transitive javax dependencies.
- **Plugin version enforcement**: Mule Maven Plugin 4.4.0 will fail the build if any connector is below its minimum version for 4.11. This is intentional — do not downgrade the plugin to bypass this check.
- **MUnit test isolation**: MUnit 3.4.0 changes how test isolation works with Jakarta — mock processors may need updates if they reference javax-based interfaces.
- **Edge to LTS configuration drift**: If you customized Edge-specific features (experimental APIs, preview flags), verify they are GA in 4.11. Experimental features may have different configuration syntax in the LTS release.
- **ObjectStore serialization**: Objects serialized by 4.10 ObjectStore connector may not deserialize on 4.11 due to namespace changes. Drain persistent ObjectStores before upgrading, or implement a migration step.
- **Anypoint Studio**: Studio 7.20+ is required for 4.11 LTS project support and Jakarta namespace autocomplete.

### Related
- [mule49-to-410](../mule49-to-410/) — Previous upgrade step
- [java11-to-17-encapsulation](../../java-versions/java11-to-17-encapsulation/) — Java 17 module system details
- [jaxb-javax-removal](../../java-17/jaxb-javax-removal/) — JAXB migration guide
- [ch1-app-to-ch2](../../cloudhub/ch1-app-to-ch2/) — CloudHub 2.0 migration
- [munit2-to-3](../../build-tools/munit2-to-3/) — MUnit upgrade path
