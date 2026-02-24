## Java 8 to 11 Migration for MuleSoft
> Migrate Mule applications from Java 8 to Java 11: module system changes, removed APIs, and runtime configuration

### When to Use
- Upgrading Mule 4.4+ runtime that requires Java 11 as minimum
- Preparing for eventual Java 17 migration (Java 11 is the stepping stone)
- Resolving `ClassNotFoundException` or `NoClassDefFoundError` after JDK upgrade
- CI/CD pipelines switching from JDK 8 to JDK 11 base images

### Configuration / Code

#### 1. Update POM — Set Java 11 Compilation Target

```xml
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
    <maven.compiler.release>11</maven.compiler.release>
</properties>
```

#### 2. Update `wrapper.conf` — Set JVM for On-Prem Runtime

```properties
# $MULE_HOME/conf/wrapper.conf
wrapper.java.command=%JAVA_HOME%/bin/java
wrapper.java.additional.20=--add-opens=java.base/java.lang=ALL-UNNAMED
wrapper.java.additional.21=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED
wrapper.java.additional.22=--add-opens=java.base/java.util=ALL-UNNAMED
```

#### 3. Replace Removed APIs

**`javax.xml.bind` (JAXB) — removed in Java 11:**

```xml
<dependency>
    <groupId>jakarta.xml.bind</groupId>
    <artifactId>jakarta.xml.bind-api</artifactId>
    <version>2.3.3</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <version>2.3.9</version>
</dependency>
```

**`javax.activation` — removed in Java 11:**

```xml
<dependency>
    <groupId>jakarta.activation</groupId>
    <artifactId>jakarta.activation-api</artifactId>
    <version>1.2.2</version>
</dependency>
```

**`javax.annotation` — removed in Java 11:**

```xml
<dependency>
    <groupId>jakarta.annotation</groupId>
    <artifactId>jakarta.annotation-api</artifactId>
    <version>1.3.5</version>
</dependency>
```

#### 4. Dockerfile Update

```dockerfile
# Before
FROM openjdk:8-jre-alpine

# After
FROM eclipse-temurin:11-jre-jammy
```

#### 5. Maven Enforcer — Prevent Accidental Java 8 Builds

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-enforcer-plugin</artifactId>
    <version>3.4.1</version>
    <executions>
        <execution>
            <id>enforce-java</id>
            <goals><goal>enforce</goal></goals>
            <configuration>
                <rules>
                    <requireJavaVersion>
                        <version>[11,)</version>
                        <message>Java 11+ is required.</message>
                    </requireJavaVersion>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### How It Works
1. Java 9 introduced the module system (JPMS). Several `javax.*` packages that shipped with JDK 8 were deprecated in Java 9, made optional in Java 10, and fully removed in Java 11
2. The `--add-modules` flag can temporarily restore access during Java 9/10 transition but fails in Java 11 since the modules are gone entirely
3. Explicit Maven dependencies for JAXB, JAF, and `javax.annotation` replace the removed JDK modules
4. The `--add-opens` flags are needed when Mule runtime or third-party libraries use reflection to access JDK internals

### Migration Checklist
- [ ] Verify all custom Java code compiles with `javac --release 11`
- [ ] Search for `sun.misc.Unsafe`, `sun.reflect.*`, `com.sun.*` — replace with supported APIs
- [ ] Replace any `javax.xml.bind`, `javax.activation`, `javax.annotation` imports
- [ ] Update all Docker/CI base images to JDK 11
- [ ] Run full MUnit test suite on Java 11
- [ ] Test on-prem runtime with updated `wrapper.conf`
- [ ] Verify no reflection warnings in runtime logs

### Gotchas
- `--add-modules=java.xml.bind` works on Java 9/10 but **fails on Java 11** — use explicit dependencies
- Some connectors bundle their own JAXB; adding the dependency can cause classpath conflicts — use `<exclusions>` to resolve
- The Nashorn JavaScript engine was deprecated in Java 11 and removed in Java 15
- `java.security` default algorithms changed; TLS connections may fail if relying on deprecated cipher suites

### Related
- [jaxb-removal](../jaxb-removal/) — Detailed JAXB replacement guide
- [java11-to-17-encapsulation](../java11-to-17-encapsulation/) — Next step: Java 11 to 17
- [javax-to-jakarta](../javax-to-jakarta/) — Full namespace migration
- [Java 17 Migration](../../java-17/) — Complete Java 17 guide
