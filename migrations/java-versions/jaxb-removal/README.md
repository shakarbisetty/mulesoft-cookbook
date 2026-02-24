## Replace JAXB with Jakarta XML Binding
> Remove deprecated javax.xml.bind and replace with Jakarta XML Binding for Java 11+ compatibility

### When to Use
- Custom Java components use `javax.xml.bind.*` annotations (`@XmlRootElement`, `@XmlElement`, etc.)
- Build fails with `ClassNotFoundException: javax.xml.bind.JAXBContext` on Java 11+
- Mule custom modules marshal/unmarshal XML using JAXB
- Preparing for Java 17 where `--add-modules` workarounds no longer function

### Configuration / Code

#### 1. Remove Old JAXB Dependencies

```xml
<!-- REMOVE these if present -->
<!--
<dependency>
    <groupId>javax.xml.bind</groupId>
    <artifactId>jaxb-api</artifactId>
</dependency>
<dependency>
    <groupId>com.sun.xml.bind</groupId>
    <artifactId>jaxb-impl</artifactId>
</dependency>
<dependency>
    <groupId>com.sun.xml.bind</groupId>
    <artifactId>jaxb-core</artifactId>
</dependency>
-->
```

#### 2. Add Jakarta XML Binding

```xml
<!-- Jakarta XML Binding API -->
<dependency>
    <groupId>jakarta.xml.bind</groupId>
    <artifactId>jakarta.xml.bind-api</artifactId>
    <version>4.0.2</version>
</dependency>

<!-- Runtime implementation (GlassFish) -->
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <version>4.0.5</version>
    <scope>runtime</scope>
</dependency>
```

#### 3. Update Java Imports

```java
// Before (javax)
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import javax.xml.bind.Marshaller;
import javax.xml.bind.Unmarshaller;
import javax.xml.bind.annotation.XmlRootElement;
import javax.xml.bind.annotation.XmlElement;

// After (jakarta)
import jakarta.xml.bind.JAXBContext;
import jakarta.xml.bind.JAXBException;
import jakarta.xml.bind.Marshaller;
import jakarta.xml.bind.Unmarshaller;
import jakarta.xml.bind.annotation.XmlRootElement;
import jakarta.xml.bind.annotation.XmlElement;
```

#### 4. Bridging Strategy (Transitional)

If you cannot change imports immediately (e.g., shared library), use the 2.3.x bridge:

```xml
<!-- Bridge: jakarta groupId but javax namespace -->
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

#### 5. Maven Plugin for Code Generation

```xml
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>jaxb2-maven-plugin</artifactId>
    <version>3.1.0</version>
    <executions>
        <execution>
            <id>xjc</id>
            <goals><goal>xjc</goal></goals>
            <configuration>
                <sources>
                    <source>src/main/resources/xsd</source>
                </sources>
                <packageName>com.mycompany.model</packageName>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### How It Works
1. JAXB was part of Java SE through Java 8, deprecated in Java 9, and removed in Java 11
2. The Jakarta XML Binding 2.3.x line keeps `javax.xml.bind` package names but ships as a separate dependency
3. The Jakarta XML Binding 4.x line changes the package to `jakarta.xml.bind` — this is the forward-looking option
4. `jaxb-runtime` provides the actual marshal/unmarshal implementation; the API jar contains only interfaces

### Migration Checklist
- [ ] Inventory all files importing `javax.xml.bind.*`
- [ ] Decide on bridge (2.3.x) vs full migration (4.x) strategy
- [ ] Replace all `javax.xml.bind` imports with `jakarta.xml.bind` (if using 4.x)
- [ ] Update `jaxb2-maven-plugin` to 3.x for Jakarta namespace support
- [ ] Test XML serialization/deserialization round-trip
- [ ] Verify no duplicate JAXB jars on classpath (`mvn dependency:tree | grep jaxb`)

### Gotchas
- Jakarta XML Binding 2.3.x uses `javax.xml.bind` namespace; 4.x uses `jakarta.xml.bind` — mixing them causes `ClassCastException`
- Mule connectors may ship their own JAXB — check `mvn dependency:tree` for conflicts and add `<exclusions>` as needed
- `@XmlTransient` behavior is identical across versions but be aware that annotation processors may need updates
- Schema-generated classes must be regenerated with the new plugin version
- If using Spring in custom modules, Spring 6+ requires Jakarta namespace (4.x); Spring 5.x works with either

### Related
- [java8-to-11](../java8-to-11/) — Overall Java 8 to 11 migration
- [javax-to-jakarta](../javax-to-jakarta/) — Full javax-to-jakarta namespace migration
- [Java 17 Migration](../../java-17/) — Complete Java 17 guide
