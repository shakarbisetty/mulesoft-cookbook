## SAP JCo CloudHub Deployment

> Native library deployment, JCo configuration, and troubleshooting for running MuleSoft SAP Connector on CloudHub and CloudHub 2.0.

### When to Use

- Deploying a Mule application with the SAP connector to CloudHub (shared or dedicated)
- Getting `UnsatisfiedLinkError` or `java.lang.ExceptionInInitializerError` for `sapjco3` on deployment
- Need to configure SAP JCo properties for a cloud environment where you cannot install native libraries on the OS
- Migrating SAP integrations from on-premises Mule runtime to CloudHub 2.0

### The Problem

The MuleSoft SAP connector depends on SAP Java Connector (JCo), which includes native C libraries (`sapjco3.dll` / `libsapjco3.so`). On-premises deployments drop these into the Mule runtime's `lib/` directory, but CloudHub does not allow filesystem access. Developers hit `UnsatisfiedLinkError` on first deployment and spend hours debugging classloader and library path issues that have a specific, documented solution.

### Configuration

#### Project Structure for CloudHub

```
src/
  main/
    mule/
      sap-integration.xml
    resources/
      lib/
        sapjco3.jar         ← SAP JCo Java library
        libsapjco3.so       ← Linux native library (for CloudHub)
      application-types.xml
  test/
pom.xml
```

#### pom.xml — SAP Connector and JCo Dependencies

```xml
<dependencies>
    <!-- MuleSoft SAP Connector from Exchange -->
    <dependency>
        <groupId>com.mulesoft.connectors</groupId>
        <artifactId>mule-sap-connector</artifactId>
        <version>5.8.1</version>
        <classifier>mule-plugin</classifier>
    </dependency>
</dependencies>

<build>
    <plugins>
        <plugin>
            <groupId>org.mule.tools.maven</groupId>
            <artifactId>mule-maven-plugin</artifactId>
            <version>${mule.maven.plugin.version}</version>
            <extensions>true</extensions>
            <configuration>
                <cloudHubDeployment>
                    <uri>https://anypoint.mulesoft.com</uri>
                    <muleVersion>4.6.0</muleVersion>
                    <workers>1</workers>
                    <workerType>MICRO</workerType>
                    <environment>Production</environment>
                    <applicationName>${app.name}</applicationName>
                    <properties>
                        <sap.host>${sap.host}</sap.host>
                        <sap.systemNumber>${sap.systemNumber}</sap.systemNumber>
                        <sap.client>${sap.client}</sap.client>
                    </properties>
                </cloudHubDeployment>
            </configuration>
        </plugin>
    </plugins>
</build>

<!-- SAP JCo as a system-scope dependency for native library loading -->
<profiles>
    <profile>
        <id>include-sapjco</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <dependencies>
            <dependency>
                <groupId>com.sap.conn.jco</groupId>
                <artifactId>sapjco3</artifactId>
                <version>3.1.9</version>
                <scope>system</scope>
                <systemPath>${project.basedir}/src/main/resources/lib/sapjco3.jar</systemPath>
            </dependency>
        </dependencies>
    </profile>
</profiles>
```

#### SAP Connector Configuration for CloudHub

```xml
<sap:config name="SAP_Config" doc:name="SAP Config">
    <sap:simple-connection-provider
        applicationServerHost="${sap.host}"
        systemNumber="${sap.systemNumber}"
        client="${sap.client}"
        userName="${sap.user}"
        password="${sap.password}"
        language="EN">
        <sap:additional-connection-properties>
            <!-- CloudHub-specific JCo properties -->
            <sap:additional-connection-property
                key="jco.client.network"
                value="LAN" />
            <sap:additional-connection-property
                key="jco.client.peak_limit"
                value="5" />
            <sap:additional-connection-property
                key="jco.client.pool_capacity"
                value="3" />
            <sap:additional-connection-property
                key="jco.client.expiration_time"
                value="300000" />
            <sap:additional-connection-property
                key="jco.client.expiration_check_period"
                value="60000" />
        </sap:additional-connection-properties>
    </sap:simple-connection-provider>
</sap:config>
```

#### CloudHub 2.0 (RTF) Deployment

For CloudHub 2.0 (Runtime Fabric), the native library handling is different:

```xml
<!-- pom.xml additions for CloudHub 2.0 -->
<build>
    <plugins>
        <plugin>
            <groupId>org.mule.tools.maven</groupId>
            <artifactId>mule-maven-plugin</artifactId>
            <configuration>
                <runtimeFabricDeployment>
                    <uri>https://anypoint.mulesoft.com</uri>
                    <muleVersion>4.6.0</muleVersion>
                    <target>${rtf.target}</target>
                    <provider>MC</provider>
                    <replicas>2</replicas>
                    <cores>0.5</cores>
                    <memoryReserved>1500Mi</memoryReserved>
                    <memoryMax>1500Mi</memoryMax>
                    <applicationName>${app.name}</applicationName>
                    <deploymentSettings>
                        <http>
                            <inbound>
                                <lastMileSecurity>true</lastMileSecurity>
                            </inbound>
                        </http>
                        <jvm>
                            <args>-Djava.library.path=/opt/mule/lib</args>
                        </jvm>
                    </deploymentSettings>
                </runtimeFabricDeployment>
            </configuration>
        </plugin>
    </plugins>
</build>
```

#### Connection Test Flow

```xml
<flow name="sap-jco-connection-test-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/health/sap"
        allowedMethods="GET" />

    <try doc:name="Test SAP Connection">
        <sap:function-call config-ref="SAP_Config"
            doc:name="RFC Ping"
            key="RFC_PING" />

        <ee:transform doc:name="Success Response">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "UP",
    sapSystem: "${sap.host}",
    client: "${sap.client}",
    jcoVersion: "3.1.x",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <error-handler>
            <on-error-continue type="SAP:CONNECTIVITY">
                <ee:transform doc:name="Connection Failed">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "DOWN",
    error: error.description,
    hint: if (error.description contains "sapjco3")
              "Native library not loaded. Check lib/ directory and classloader."
          else if (error.description contains "COMMUNICATION_FAILURE")
              "Network issue. Verify SAP host is reachable from CloudHub VPC."
          else
              "Check SAP credentials and system number.",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                    </ee:message>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 503 }]]></ee:set-attributes>
                </ee:transform>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### Gotchas

- **Linux native library only** — CloudHub runs Linux. You must include `libsapjco3.so` (not `sapjco3.dll`). Get the Linux x86_64 version from SAP Marketplace (software component `SAPJCO3`)
- **JCo version must match connector version** — SAP Connector 5.x requires JCo 3.1.x. Mixing versions causes `ClassNotFoundException` or `NoSuchMethodError`. Check the connector release notes for the exact JCo version requirement
- **VPC required for SAP connectivity** — CloudHub Shared Space cannot reach on-premises SAP systems directly. You need an Anypoint VPC with VPN or CloudHub DLB peering to your corporate network where SAP resides
- **`jco.client.peak_limit` controls concurrent RFC calls** — Setting this too high on a small CloudHub worker (0.1 vCore) causes thread starvation. Keep it at 3-5 for micro workers, 10-15 for large workers
- **SAP connection pooling vs Mule thread pool** — JCo maintains its own connection pool (`pool_capacity`). If `pool_capacity` is smaller than the number of concurrent Mule threads calling SAP, threads will block waiting for a JCo connection. Size `pool_capacity` to match your expected concurrency
- **SNC (Secure Network Communication)** — If SAP requires SNC, you need additional native crypto libraries (`libsapcrypto.so`). These must also be packaged in your deployable archive
- **CloudHub 2.0 has different native library paths** — On Runtime Fabric, use `-Djava.library.path` in JVM args to point to where the native library is extracted. The exact path depends on your container image

### Testing

```xml
<munit:test name="sap-connection-test"
    description="Verify SAP connectivity health check">

    <munit:behavior>
        <munit-tools:mock-when processor="sap:function-call">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="sap-jco-connection-test-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('UP')]" />
    </munit:validation>
</munit:test>
```

### Related

- [SAP IDoc Processing](../sap-idoc-processing/) — IDoc patterns that run on top of this JCo configuration
- [SAP IDoc Processing Complete](../sap-idoc-processing-complete/) — Production-grade IDoc handling with TID management
