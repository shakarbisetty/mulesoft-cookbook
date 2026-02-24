## javax.* to jakarta.* Namespace Migration
> Migrate from javax.* to jakarta.* namespace for Jakarta EE 9+ compatibility in Mule custom components

### When to Use
- Custom Java modules use `javax.servlet`, `javax.persistence`, `javax.inject`, or other Jakarta EE APIs
- Upgrading to libraries that require Jakarta EE 9+ (e.g., Spring 6, Hibernate 6)
- Building custom Mule connectors that depend on Jakarta EE specifications
- Preparing for long-term Java 17/21 compatibility

### Configuration / Code

#### 1. Namespace Mapping Reference

| javax Package | jakarta Package | Since Jakarta EE |
|---|---|---|
| `javax.servlet` | `jakarta.servlet` | 9 |
| `javax.persistence` | `jakarta.persistence` | 9 |
| `javax.inject` | `jakarta.inject` | 9 |
| `javax.validation` | `jakarta.validation` | 9 |
| `javax.xml.bind` | `jakarta.xml.bind` | 9 |
| `javax.ws.rs` | `jakarta.ws.rs` | 9 |
| `javax.json` | `jakarta.json` | 9 |
| `javax.mail` | `jakarta.mail` | 9 |
| `javax.annotation` | `jakarta.annotation` | 9 |

> **Note:** `javax.sql`, `javax.crypto`, `javax.net`, `javax.security.auth` are **Java SE** packages and do NOT change to jakarta.

#### 2. POM Dependency Updates

```xml
<!-- Before -->
<dependency>
    <groupId>javax.servlet</groupId>
    <artifactId>javax.servlet-api</artifactId>
    <version>4.0.1</version>
</dependency>
<dependency>
    <groupId>javax.persistence</groupId>
    <artifactId>javax.persistence-api</artifactId>
    <version>2.2</version>
</dependency>
<dependency>
    <groupId>javax.inject</groupId>
    <artifactId>javax.inject</artifactId>
    <version>1</version>
</dependency>

<!-- After -->
<dependency>
    <groupId>jakarta.servlet</groupId>
    <artifactId>jakarta.servlet-api</artifactId>
    <version>6.0.0</version>
</dependency>
<dependency>
    <groupId>jakarta.persistence</groupId>
    <artifactId>jakarta.persistence-api</artifactId>
    <version>3.1.0</version>
</dependency>
<dependency>
    <groupId>jakarta.inject</groupId>
    <artifactId>jakarta.inject-api</artifactId>
    <version>2.0.1</version>
</dependency>
```

#### 3. Automated Migration with Eclipse Transformer

```bash
# Install Eclipse Transformer
curl -L -o transformer.jar https://repo1.maven.org/maven2/org/eclipse/transformer/org.eclipse.transformer.cli/0.5.0/org.eclipse.transformer.cli-0.5.0.jar

# Transform a JAR
java -jar transformer.jar input.jar output.jar

# Transform source directory
java -jar transformer.jar -o src/main/java-jakarta src/main/java -tf javax-to-jakarta.properties
```

#### 4. Maven Plugin for Build-Time Transformation

```xml
<plugin>
    <groupId>org.eclipse.transformer</groupId>
    <artifactId>transformer-maven-plugin</artifactId>
    <version>0.5.0</version>
    <executions>
        <execution>
            <id>transform-jakarta</id>
            <phase>process-classes</phase>
            <goals><goal>jar</goal></goals>
        </execution>
    </executions>
</plugin>
```

#### 5. IntelliJ / IDE Find-and-Replace

```
# Regex pattern for bulk replacement
Find:    javax\.(servlet|persistence|inject|validation|xml\.bind|ws\.rs|json|mail|annotation)
Replace: jakarta.$1
```

### How It Works
1. Jakarta EE 9 (2020) renamed all `javax.*` packages to `jakarta.*` after Oracle transferred Java EE to the Eclipse Foundation
2. The `javax.*` namespace is frozen — no new features will be added
3. Libraries like Spring 6, Hibernate 6, and Tomcat 10+ require the `jakarta.*` namespace
4. Eclipse Transformer can mechanically convert bytecode and source from javax to jakarta

### Migration Checklist
- [ ] Identify all `javax.*` imports that map to Jakarta EE (not Java SE)
- [ ] Update POM dependencies to Jakarta versions
- [ ] Replace imports in Java source files
- [ ] Update `persistence.xml`, `web.xml`, and other configuration files referencing javax
- [ ] Replace any `META-INF/services/javax.*` files with `META-INF/services/jakarta.*`
- [ ] Run full test suite to verify

### Gotchas
- **Do NOT rename Java SE packages** — `javax.sql.*`, `javax.crypto.*`, `javax.net.*`, `javax.security.auth.*` stay as-is
- Mule runtime itself still uses some `javax.*` internally — only migrate YOUR custom code
- If you have transitive dependencies that still use `javax.*`, you may need the Eclipse Transformer at build time
- Spring Boot 2.x uses `javax.*`; Spring Boot 3.x uses `jakarta.*` — do not mix
- Some annotation processors (Lombok, MapStruct) need version updates to support `jakarta.*`

### Related
- [jaxb-removal](../jaxb-removal/) — Specific JAXB migration details
- [java8-to-11](../java8-to-11/) — Java version migration context
- [custom-connector-java17](../../connectors/custom-connector-java17/) — Custom connector updates
