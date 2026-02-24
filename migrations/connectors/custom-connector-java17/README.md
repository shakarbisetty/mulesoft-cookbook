## Custom Java Connector to Java 17
> Migrate custom Mule SDK Java connectors to Java 17 compatibility

### When to Use
- Custom connectors fail on Java 17 runtime
- Building new connectors targeting Java 17+
- Existing connector uses reflection or internal APIs

### Configuration / Code

#### 1. Update Connector POM

```xml
<properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
    <maven.compiler.release>17</maven.compiler.release>
    <mule.version>4.6.0</mule.version>
</properties>
<parent>
    <groupId>org.mule.extensions</groupId>
    <artifactId>mule-modules-parent</artifactId>
    <version>1.6.0</version>
</parent>
```

#### 2. Replace Removed APIs

```java
// Before: javax.annotation
import javax.annotation.PostConstruct;

// After: jakarta or Mule SDK
import jakarta.annotation.PostConstruct;
// Or use Mule SDK lifecycle:
import org.mule.runtime.extension.api.annotation.OnStart;
```

#### 3. Fix Reflection Issues

```java
// Before: fails on Java 17
Field field = obj.getClass().getDeclaredField("internalState");
field.setAccessible(true); // InaccessibleObjectException

// After: use public API or MethodHandles
MethodHandles.Lookup lookup = MethodHandles.privateLookupIn(
    obj.getClass(), MethodHandles.lookup());
VarHandle handle = lookup.findVarHandle(
    obj.getClass(), "internalState", Object.class);
Object value = handle.get(obj);
```

#### 4. Update Dependencies

```xml
<!-- Replace CGLIB with ByteBuddy -->
<dependency>
    <groupId>net.bytebuddy</groupId>
    <artifactId>byte-buddy</artifactId>
    <version>1.14.18</version>
</dependency>

<!-- Update JAXB if needed -->
<dependency>
    <groupId>jakarta.xml.bind</groupId>
    <artifactId>jakarta.xml.bind-api</artifactId>
    <version>4.0.2</version>
</dependency>
```

### How It Works
1. Java 17 enforces strong encapsulation of JDK internals
2. Custom connectors using reflection need code changes
3. Mule SDK provides lifecycle annotations replacing Java EE
4. Building with `--release 17` ensures compatibility

### Migration Checklist
- [ ] Update POM compiler settings to Java 17
- [ ] Replace `javax.*` imports
- [ ] Fix reflection-based access
- [ ] Replace CGLIB with ByteBuddy
- [ ] Update all dependencies
- [ ] Test on Mule 4.6+ with Java 17
- [ ] Publish to Exchange

### Gotchas
- `--add-opens` in connector POM only affects tests, not runtime
- Custom classloader behavior may differ on Java 17
- Connector certification may require Java 17 test results

### Related
- [java11-to-17-encapsulation](../../java-versions/java11-to-17-encapsulation/) - Encapsulation
- [javax-to-jakarta](../../java-versions/javax-to-jakarta/) - Namespace migration
- [cglib-to-bytebuddy](../../java-versions/cglib-to-bytebuddy/) - Bytecode library
