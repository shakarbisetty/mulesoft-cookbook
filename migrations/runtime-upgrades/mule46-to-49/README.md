## Mule 4.6 to 4.9 Upgrade
> Upgrade Mule runtime from 4.6 to 4.9: Java 17 support, performance improvements, and new capabilities

### When to Use
- Need Java 17 support for security patches and modern language features
- Want the latest DataWeave engine improvements
- Preparing for CloudHub 2.0 with latest runtime features
- Need new connector capabilities only available in Mule 4.9

### Configuration / Code

#### 1. Update POM Runtime Version

```xml
<properties>
    <app.runtime>4.9.0</app.runtime>
    <mule.maven.plugin.version>4.2.0</mule.maven.plugin.version>
    <munit.version>3.2.0</munit.version>
</properties>
```

#### 2. Set Java 17

```bash
# Install Temurin JDK 17
sudo apt install temurin-17-jdk

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64

# Verify
java -version
# openjdk version "17.0.x"
```

#### 3. Add Required JVM Flags

```properties
# $MULE_HOME/conf/wrapper.conf
wrapper.java.additional.50=--add-opens=java.base/java.lang=ALL-UNNAMED
wrapper.java.additional.51=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED
wrapper.java.additional.52=--add-opens=java.base/java.util=ALL-UNNAMED
wrapper.java.additional.53=--add-opens=java.base/java.util.concurrent=ALL-UNNAMED
wrapper.java.additional.54=--add-opens=java.base/java.io=ALL-UNNAMED
wrapper.java.additional.55=--add-opens=java.base/java.net=ALL-UNNAMED
wrapper.java.additional.56=--add-opens=java.base/java.nio=ALL-UNNAMED
wrapper.java.additional.57=--add-opens=java.base/sun.nio.ch=ALL-UNNAMED
wrapper.java.additional.58=--add-opens=java.management/sun.management=ALL-UNNAMED
```

#### 4. Update Connector Versions

```xml
<!-- All connectors should be latest release for 4.9 compatibility -->
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-http-connector</artifactId>
    <version>1.10.1</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-db-connector</artifactId>
    <version>1.15.2</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>11.2.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 5. MUnit 3 Configuration

```xml
<plugin>
    <groupId>com.mulesoft.munit.tools</groupId>
    <artifactId>munit-maven-plugin</artifactId>
    <version>${munit.version}</version>
    <configuration>
        <runtimeVersion>${app.runtime}</runtimeVersion>
        <argLine>
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

### How It Works
1. Mule 4.9 adds official Java 17 support while maintaining Java 11 backward compatibility
2. The DataWeave engine receives performance optimizations and new built-in functions
3. Strong encapsulation in Java 17 requires explicit `--add-opens` flags
4. Connector APIs may have breaking changes — verify each connector's compatibility matrix

### Migration Checklist
- [ ] Install Java 17 on all environments (dev, CI, staging, prod)
- [ ] Update POM to `app.runtime=4.9.0`
- [ ] Update all connectors to 4.9-compatible versions
- [ ] Add `--add-opens` JVM flags to wrapper.conf and CI configs
- [ ] Update MUnit to 3.x
- [ ] Test all custom Java code on Java 17
- [ ] Verify JAXB, CGLIB, and reflection-heavy code still works
- [ ] Deploy to staging and run integration tests
- [ ] Update CloudHub runtime version in deployment descriptors

### Gotchas
- Not all third-party connectors support Java 17 immediately — check release notes
- Custom Java code using `sun.*` internal APIs will fail without `--add-opens`
- CGLIB-based proxies break on Java 17 — migrate to ByteBuddy
- On-prem: Tanuki Wrapper version must support Java 17
- CloudHub 1.0 does not support Mule 4.9 — migrate to CloudHub 2.0

### Related
- [mule44-to-46](../mule44-to-46/) — Previous upgrade step
- [java11-to-17-encapsulation](../../java-versions/java11-to-17-encapsulation/) — Java 17 encapsulation
- [ch1-app-to-ch2](../../cloudhub/ch1-app-to-ch2/) — CloudHub 2.0 migration
- [munit2-to-3](../../build-tools/munit2-to-3/) — MUnit upgrade
