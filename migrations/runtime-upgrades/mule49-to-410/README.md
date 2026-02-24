## Mule 4.9 to 4.10 Upgrade
> Upgrade Mule runtime from 4.9 to 4.10 Edge: Java 17 default, HTTP/2 support, and updated connector ecosystem

### When to Use
- Running Mule 4.9 and need HTTP/2 multiplexing for high-throughput API traffic
- Want Java 17 as the default runtime (no longer opt-in)
- Need DataWeave 2.9 improvements (enhanced pattern matching, new string functions)
- Preparing to adopt Flex Gateway 2.x features that require runtime 4.10+
- Targeting CloudHub 2.0 deployments with latest runtime support

### Configuration / Code

#### 1. Update POM Runtime and Plugin Versions

```xml
<!-- Before (4.9) -->
<properties>
    <app.runtime>4.9.0</app.runtime>
    <mule.maven.plugin.version>4.2.0</mule.maven.plugin.version>
    <munit.version>3.2.0</munit.version>
</properties>

<!-- After (4.10) -->
<properties>
    <app.runtime>4.10.0-edge</app.runtime>
    <mule.maven.plugin.version>4.3.0</mule.maven.plugin.version>
    <munit.version>3.3.0</munit.version>
</properties>
```

#### 2. Update Connector Versions to 4.10-Compatible Releases

```xml
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-http-connector</artifactId>
    <version>1.11.0</version>   <!-- Required for HTTP/2 support -->
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-db-connector</artifactId>
    <version>1.16.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>11.3.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-file-connector</artifactId>
    <version>1.6.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-ftp-connector</artifactId>
    <version>2.1.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 3. Enable HTTP/2 on HTTP Requester

```xml
<http:request-config name="HTTP2_Request"
                     doc:name="HTTP/2 Requester">
    <http:request-connection host="api.example.com"
                             port="443"
                             protocol="HTTPS">
        <http:client-socket-properties>
            <sockets:tcp-client-socket-properties
                keepAlive="true" />
        </http:client-socket-properties>
        <tls:context>
            <tls:trust-store insecure="false"
                             path="truststore.jks"
                             password="${secure::truststore.password}" />
        </tls:context>
        <http:protocol-config>
            <http:http2-config
                enabled="true"
                priorKnowledge="false" />
        </http:protocol-config>
    </http:request-connection>
</http:request-config>
```

#### 4. Update wrapper.conf (On-Prem Only)

```properties
# Java 17 is now the default — remove Java 11 fallback
wrapper.java.command=%JAVA_HOME%/bin/java

# --add-opens flags still required for backward compatibility
wrapper.java.additional.50=--add-opens=java.base/java.lang=ALL-UNNAMED
wrapper.java.additional.51=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED
wrapper.java.additional.52=--add-opens=java.base/java.util=ALL-UNNAMED
wrapper.java.additional.53=--add-opens=java.base/java.util.concurrent=ALL-UNNAMED
wrapper.java.additional.54=--add-opens=java.base/java.io=ALL-UNNAMED
wrapper.java.additional.55=--add-opens=java.base/java.net=ALL-UNNAMED
wrapper.java.additional.56=--add-opens=java.base/java.nio=ALL-UNNAMED

# New in 4.10: G1GC is default, remove CMS flags if present
# REMOVE: wrapper.java.additional.60=-XX:+UseConcMarkSweepGC
```

#### 5. MUnit 3.3 Configuration

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
1. Mule 4.10 Edge makes Java 17 the default JVM — Java 11 support is deprecated but still functional
2. The HTTP connector 1.11.0 introduces HTTP/2 protocol negotiation via ALPN over TLS
3. HTTP/2 multiplexing replaces the connection pool model, allowing multiple concurrent streams over a single TCP connection
4. DataWeave 2.9 adds enhanced pattern matching with guard clauses and new string interpolation features
5. G1GC replaces CMS as the default garbage collector, improving pause times for large heaps
6. The Mule Maven Plugin 4.3.0 adds support for the new deployment descriptor format required by CloudHub 2.0

### Migration Checklist
- [ ] Verify Java 17 is installed on all environments (dev, CI, staging, prod)
- [ ] Update `app.runtime` to `4.10.0-edge` in POM
- [ ] Update `mule-maven-plugin` to 4.3.0
- [ ] Update MUnit to 3.3.0
- [ ] Update all connectors to 4.10-compatible versions (see table above)
- [ ] Remove CMS GC flags from wrapper.conf — G1GC is now default
- [ ] Test all custom Java code on Java 17 if not already done
- [ ] Enable HTTP/2 on requester configs where backend supports it
- [ ] Run full MUnit suite and integration tests on Edge runtime
- [ ] Deploy to a staging environment on CloudHub 2.0 before production

### Gotchas
- **Edge vs LTS**: 4.10 is an Edge release — it receives monthly updates but no long-term support. Do not use Edge in production unless you have a rapid update cadence. Wait for 4.11 LTS for production stability.
- **Connector compatibility matrix**: Not all connectors have 4.10-compatible releases on day one. Check the MuleSoft Connector Release Notes for each connector before upgrading.
- **HTTP/2 requires TLS**: HTTP/2 over cleartext (h2c) is not supported in the Mule HTTP connector. You must configure TLS for HTTP/2 to negotiate via ALPN.
- **Custom Java modules**: Any custom Java code using `sun.*` internal APIs or deep reflection will still need `--add-opens` flags even though Java 17 is now the default.
- **CMS GC removal**: If your wrapper.conf has CMS garbage collector flags (`-XX:+UseConcMarkSweepGC`), remove them — CMS was removed in Java 14 and these flags cause JVM startup warnings.
- **Anypoint Studio**: Studio 7.18+ is required for Mule 4.10 project support. Earlier versions cannot resolve the 4.10 runtime.

### Related
- [mule46-to-49](../mule46-to-49/) — Previous upgrade step
- [mule410-to-411](../mule410-to-411/) — Next upgrade: Edge to LTS
- [java11-to-17-encapsulation](../../java-versions/java11-to-17-encapsulation/) — Java 17 module system
- [ch1-app-to-ch2](../../cloudhub/ch1-app-to-ch2/) — CloudHub 2.0 migration
- [munit2-to-3](../../build-tools/munit2-to-3/) — MUnit upgrade
