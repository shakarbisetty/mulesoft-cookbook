## Java 11 to 17 Strong Encapsulation
> Handle strong encapsulation in Java 17: --add-opens workarounds, reflective access fixes, and runtime flags

### When to Use
- Upgrading Mule 4.6+ runtime to Java 17
- Seeing `InaccessibleObjectException` or `IllegalAccessError` at runtime
- Third-party libraries use deep reflection into JDK internals
- Migrating from `--illegal-access=permit` (Java 11-15) to Java 17 where it is denied by default

### Configuration / Code

#### 1. Identify Reflection Violations

Run your app with Java 17 and capture violations:

```bash
# Java 16: warn mode (last version to support this)
java --illegal-access=warn -jar mule-app.jar 2>&1 | grep "WARNING: An illegal reflective access"

# Java 17: no --illegal-access flag; violations throw exceptions
java -jar mule-app.jar 2>&1 | grep "InaccessibleObjectException"
```

#### 2. Add `--add-opens` to `wrapper.conf`

```properties
# $MULE_HOME/conf/wrapper.conf
# Core JDK packages commonly accessed by Mule and connectors
wrapper.java.additional.30=--add-opens=java.base/java.lang=ALL-UNNAMED
wrapper.java.additional.31=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED
wrapper.java.additional.32=--add-opens=java.base/java.util=ALL-UNNAMED
wrapper.java.additional.33=--add-opens=java.base/java.util.concurrent=ALL-UNNAMED
wrapper.java.additional.34=--add-opens=java.base/java.io=ALL-UNNAMED
wrapper.java.additional.35=--add-opens=java.base/java.net=ALL-UNNAMED
wrapper.java.additional.36=--add-opens=java.base/java.nio=ALL-UNNAMED
wrapper.java.additional.37=--add-opens=java.base/sun.nio.ch=ALL-UNNAMED
wrapper.java.additional.38=--add-opens=java.base/sun.security.ssl=ALL-UNNAMED
wrapper.java.additional.39=--add-opens=java.management/sun.management=ALL-UNNAMED
wrapper.java.additional.40=--add-opens=java.xml/jdk.xml.internal=ALL-UNNAMED
```

#### 3. POM-Based Configuration for MUnit

```xml
<plugin>
    <groupId>com.mulesoft.munit.tools</groupId>
    <artifactId>munit-maven-plugin</artifactId>
    <version>${munit.version}</version>
    <configuration>
        <argLine>
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
            --add-opens java.base/java.lang.reflect=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

#### 4. Surefire / Failsafe for Custom Java Tests

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.2.5</version>
    <configuration>
        <argLine>
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

#### 5. CloudHub 2.0 JVM Args

```json
{
  "target": {
    "provider": "MC",
    "targetId": "your-target-id",
    "replicas": 1,
    "javaVersion": "17",
    "properties": {
      "jvm.args": "--add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED"
    }
  }
}
```

### How It Works
1. Java 9-15 had `--illegal-access=permit` as default, which allowed reflective access with a warning
2. Java 16 changed the default to `--illegal-access=deny` but still accepted the flag
3. Java 17 removed the `--illegal-access` flag entirely — strong encapsulation is enforced
4. `--add-opens` grants reflective access to specific packages from specific modules to unnamed modules (your app)
5. Each `--add-opens` directive follows the pattern: `module/package=target-module`

### Migration Checklist
- [ ] Run app on Java 17 and collect all `InaccessibleObjectException` stack traces
- [ ] Map each exception to the specific `--add-opens` directive needed
- [ ] Add directives to `wrapper.conf`, MUnit plugin, and CI/CD scripts
- [ ] Verify CloudHub 2.0 deployment passes JVM args correctly
- [ ] Check if library updates eliminate the need for `--add-opens` (prefer updating over adding flags)
- [ ] Document all `--add-opens` flags with comments explaining which library needs them

### Gotchas
- **Do not blanket-add every `--add-opens` you find online** — each one weakens module encapsulation. Only add what your app actually needs
- `--add-opens` is for reflective access; `--add-exports` is for compile-time access — they are different
- CloudHub 1.0 does not support Java 17; you must be on CloudHub 2.0 or Runtime Fabric
- Some Mule connectors have not been certified for Java 17 — check the connector release notes
- Tanuki Service Wrapper (used by on-prem Mule) may have its own Java 17 compatibility requirements

### Related
- [java8-to-11](../java8-to-11/) — Previous migration step
- [powermock-to-mockito](../powermock-to-mockito/) — Test framework migration for Java 17
- [Java 17 Migration](../../java-17/) — Complete Java 17 guide
- [mule46-to-49](../../runtime-upgrades/mule46-to-49/) — Mule 4.6 to 4.9 runtime upgrade
