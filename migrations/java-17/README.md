# Java 8 to Java 17 Migration for MuleSoft

> Complete migration guide: breaking changes, DataWeave fixes, connector updates, pom.xml changes, and step-by-step upgrade path.

## Why Migrate Now

**Mule 4.9 LTS (February 2025) dropped Java 8 and Java 11.** Java 17 is the only option.

| Mule Version | Java Support | LTS End |
|-------------|-------------|---------|
| 4.4 | 8, 11 | October 2024 **EXPIRED** |
| 4.6 LTS | 8, 11, **17** | August 2026 |
| **4.9 LTS** | **17 only** | **August 2027** |
| 4.11 Edge | 17 only | July 2026 |

If you're targeting 4.9+ for LTS support through 2027, Java 17 migration is mandatory.

## Breaking Changes

### 1. JAXB Removed (`javax.xml.bind`)

JAXB was deprecated in Java 9 and removed in Java 11. Completely absent in Java 17.

**Error:**
```
java.lang.NoClassDefFoundError: javax/xml/bind/JAXBException
java.lang.ClassNotFoundException: javax.xml.bind.DatatypeConverter
```

**Fix — replace `javax` with `jakarta` in pom.xml:**
```xml
<!-- REMOVE old javax JAXB -->
<!-- <dependency>
    <groupId>javax.xml.bind</groupId>
    <artifactId>jaxb-api</artifactId>
</dependency> -->

<!-- ADD Jakarta replacements -->
<dependency>
    <groupId>jakarta.xml.bind</groupId>
    <artifactId>jakarta.xml.bind-api</artifactId>
    <version>4.0.0</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <version>4.0.2</version>
    <scope>runtime</scope>
</dependency>
```

Also replace in code: `javax.xml.bind.*` → `jakarta.xml.bind.*`

### 2. Strong Encapsulation (Module System)

Java 17 enforces the module system. Internal JDK APIs are sealed.

**Error:**
```
InaccessibleObjectException: Unable to make field private java.lang.String
java.util.Currency.currencyCode accessible: module java.base does not
"opens java.util" to unnamed module
```

**CloudHub 2.0 and RTF do NOT allow `--add-opens` flags.** You must fix the code, not add JVM flags.

### 3. Reflection on Private Fields Blocked

```java
// BROKEN in Java 17
Field field = MyClass.class.getDeclaredField("secretField");
field.setAccessible(true); // throws InaccessibleObjectException
```

**Fix:** Use public getters/setters instead of reflective field access.

### 4. Other Removed `javax.*` APIs

| Removed | Replacement |
|---------|-------------|
| `javax.activation` | `jakarta.activation` |
| `javax.annotation` | `jakarta.annotation` |
| `javax.xml.ws` (JAX-WS) | `jakarta.xml.ws` |

### 5. Class File Version Mismatch

```
UnsupportedClassVersionError: class file version 61.0
(Java 8=52, Java 11=55, Java 17=61)
```

All dependencies must be compiled for Java 17 or lower.

## DataWeave Fixes

### Error Object Access

Java 17's module system breaks DataWeave's reflection-based access to internal Mule error objects:

| Broken (Java 8) | Fixed (Java 17) |
|-----------------|-----------------|
| `error.errorType.asString` | `error.errorType.namespace ++ ":" ++ error.errorType.identifier` |
| `error.muleMessage` | `error.errorMessage` |
| `error.errors` | `error.childErrors` |

### Java Object Access — Getters/Setters Required

In Java 8, DataWeave could access private fields via reflection. Java 17 blocks this.

**Before (worked in Java 8):**
```java
public class Order {
    private String orderId;  // DW accessed directly via reflection
}
```

**After (required for Java 17):**
```java
public class Order {
    private String orderId;

    public Order() {}  // Required for DW instantiation
    public String getOrderId() { return orderId; }
    public void setOrderId(String id) { this.orderId = id; }
}
```

DataWeave syntax itself does not change. Only the Java objects and error access patterns change.

## Connector Compatibility

**Every connector must be Java 17-certified before upgrading the runtime.**

**Error with non-compliant connector:**
```
Extension 'module-error-handler-plugin' does not support Java 17.
Supported versions are: [1.8, 11]
```

Key minimum versions:

| Connector | Min Java 17 Version |
|-----------|-------------------|
| HTTP | 1.6.1+ |
| Database | 1.14.0+ |
| Salesforce | 10.18.0+ |
| File | 1.5.0+ |
| FTP | 1.6.0+ |
| JMS | 1.8.0+ |
| Sockets | 1.2.3+ |
| Validation | 2.0.4+ |

Check the full matrix: [Java 17 Compatible Connectors](https://help.salesforce.com/s/articleView?id=000782248&language=en_US&type=1)

## POM Changes

### Core Properties

```xml
<properties>
    <app.runtime>4.9.0</app.runtime>
    <mule.maven.plugin.version>4.2.0</mule.maven.plugin.version>
    <munit.version>3.2.0</munit.version>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
</properties>
```

### CloudHub 2.0 Deployment

```xml
<cloudhub2Deployment>
    <!-- ... other config ... -->
    <javaVersion>17</javaVersion>
    <releaseChannel>LTS</releaseChannel>
</cloudhub2Deployment>
```

### mule-artifact.json

```json
{
  "minMuleVersion": "4.9.0",
  "javaSpecificationVersions": ["17"],
  "supportedJavaVersions": ["17"]
}
```

### Custom Connectors — mule-modules-parent

```xml
<parent>
    <groupId>org.mule.extensions</groupId>
    <artifactId>mule-modules-parent</artifactId>
    <version>1.9.0</version>  <!-- Required for Java 17 -->
</parent>
```

Add the annotation:
```java
@Extension(name = "MyConnector")
@JavaVersionSupport({JAVA_8, JAVA_11, JAVA_17})
public class MyConnectorExtension { }
```

## Step-by-Step Migration

### Step 1: Audit Dependencies

```bash
# List all connector versions
mvn dependency:tree | grep mule

# Scan for javax.xml.bind usage
grep -r "javax.xml.bind" src/
grep -r "javax.activation" src/
grep -r "setAccessible(true)" src/
```

### Step 2: Install JDK 17

Eclipse Temurin or Amazon Corretto recommended. Update `JAVA_HOME` and `PATH`.

### Step 3: Update pom.xml

- Set `<app.runtime>4.9.0</app.runtime>`
- Set `<mule.maven.plugin.version>4.2.0</mule.maven.plugin.version>`
- Update all connectors to Java 17-certified versions
- Add Jakarta JAXB dependencies if needed

### Step 4: Fix Custom Java Code

- Add getters/setters to all POJOs used by DataWeave
- Replace `javax.xml.bind.*` with `jakarta.xml.bind.*`
- Remove `setAccessible(true)` calls
- Replace PowerMock with Mockito 5.x

### Step 5: Fix DataWeave Scripts

```bash
# Find broken error access patterns
grep -r "error.errorType.asString" src/
grep -r "error.muleMessage" src/
grep -r "error.errors" src/
```

### Step 6: Run MUnit Tests

```bash
# Run with LOOSE enforcement first (warnings, not failures)
mvn clean test -Dmule.jvm.version.extension.enforcement=LOOSE

# Then STRICT (default in 4.9)
mvn clean test -Dapp.runtime=4.9.0
```

### Step 7: Deploy to DEV/QA

Deploy with `<javaVersion>17</javaVersion>` in pom.xml. Monitor logs for:
- `InaccessibleObjectException`
- `NoClassDefFoundError`
- `UnsupportedClassVersionError`

### Step 8: Promote to Production

After full regression in DEV/QA, promote to production.

## Do NOT Do

| Forbidden | Why |
|-----------|-----|
| `--add-opens` in CloudHub/RTF | Not supported on managed runtimes |
| Force Java 8 on Mule 4.9 | 4.9 physically requires JDK 17 |
| Leave `javax.xml.bind` imports | `NoClassDefFoundError` at runtime |
| Use PowerMock on Java 17 | Incompatible with sealed modules |
| Skip connector audit | One non-compliant connector blocks deployment |

## References

- [Java Support — MuleSoft Docs](https://docs.mulesoft.com/general/java-support)
- [Java Adoption Timeline](https://docs.mulesoft.com/release-notes/mule-runtime/java-adoption)
- [Java 17 Compatible Connectors](https://help.salesforce.com/s/articleView?id=000782248&language=en_US&type=1)
- [Java 17 Upgrade FAQ](https://help.salesforce.com/s/articleView?id=000396936&language=en_US&type=1)
- [Custom Connector Upgrade Guide](https://docs.mulesoft.com/general/customer-connector-upgrade)
- [Error Handling Changes in Java 17](https://medium.com/@muralidhargumma007/error-handling-changes-in-java17-mulesoft-dd5a6bb915d1)
