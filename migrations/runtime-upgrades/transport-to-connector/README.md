## Mule 3 Transports to Mule 4 Connectors
> Migrate Mule 3 transport-based endpoints to Mule 4 connector-based operations

### When to Use
- Converting Mule 3 inbound/outbound endpoints to Mule 4 sources and operations
- Mule 3 apps using VM, JMS, File, FTP, SFTP, SMTP, or TCP transports
- MMA output needs manual transport configuration refinement

### Configuration / Code

#### 1. VM Transport → VM Connector

```xml
<!-- Mule 3 -->
<vm:inbound-endpoint path="input.queue" exchange-pattern="one-way" />
<vm:outbound-endpoint path="output.queue" exchange-pattern="one-way" />

<!-- Mule 4 -->
<vm:config name="VM_Config">
    <vm:queues>
        <vm:queue queueName="input.queue" queueType="TRANSIENT" />
        <vm:queue queueName="output.queue" queueType="TRANSIENT" />
    </vm:queues>
</vm:config>
<flow name="listenerFlow">
    <vm:listener config-ref="VM_Config" queueName="input.queue" />
    <!-- processing -->
    <vm:publish config-ref="VM_Config" queueName="output.queue" />
</flow>
```

#### 2. JMS Transport → JMS Connector

```xml
<!-- Mule 3 -->
<jms:activemq-connector name="JMS" brokerURL="tcp://localhost:61616" />
<jms:inbound-endpoint queue="orders" connector-ref="JMS" />

<!-- Mule 4 -->
<jms:config name="JMS_Config">
    <jms:active-mq-connection>
        <jms:factory-configuration brokerUrl="tcp://localhost:61616" />
    </jms:active-mq-connection>
</jms:config>
<flow name="ordersFlow">
    <jms:listener config-ref="JMS_Config" destination="orders" />
    <!-- processing -->
    <jms:publish config-ref="JMS_Config" destination="processed.orders" />
</flow>
```

#### 3. File Transport → File Connector

```xml
<!-- Mule 3 -->
<file:inbound-endpoint path="/input"
    moveToDirectory="/processed"
    pollingFrequency="5000"
    fileAge="2000" />

<!-- Mule 4 -->
<file:config name="File_Config">
    <file:connection workingDir="/input" />
</file:config>
<flow name="fileFlow">
    <file:listener config-ref="File_Config" directory="."
        autoDelete="false"
        watermarkEnabled="true">
        <scheduling-strategy>
            <fixed-frequency frequency="5000" />
        </scheduling-strategy>
    </file:listener>
    <!-- processing -->
    <file:move config-ref="File_Config"
        sourcePath="#[attributes.path]"
        targetPath="/processed"
        overwrite="true" />
</flow>
```

#### 4. SFTP Transport → SFTP Connector

```xml
<!-- Mule 3 -->
<sftp:connector name="SFTP" />
<sftp:inbound-endpoint host="sftp.example.com" port="22"
    user="admin" password="secret" path="/upload" />

<!-- Mule 4 -->
<sftp:config name="SFTP_Config">
    <sftp:connection host="sftp.example.com" port="22"
        username="admin" password="${secure::sftp.password}"
        workingDir="/upload" />
</sftp:config>
<flow name="sftpFlow">
    <sftp:listener config-ref="SFTP_Config" directory=".">
        <scheduling-strategy>
            <fixed-frequency frequency="10000" />
        </scheduling-strategy>
    </sftp:listener>
</flow>
```

#### 5. TCP Transport → Sockets Connector

```xml
<!-- Mule 3 -->
<tcp:connector name="TCP" sendBufferSize="1024" receiveBufferSize="1024" />
<tcp:inbound-endpoint host="0.0.0.0" port="9090" />

<!-- Mule 4 -->
<sockets:config name="Sockets_Config">
    <sockets:tcp-server-connection host="0.0.0.0" port="9090">
        <sockets:protocol>
            <sockets:direct-protocol />
        </sockets:protocol>
    </sockets:tcp-server-connection>
</sockets:config>
<flow name="tcpFlow">
    <sockets:listener config-ref="Sockets_Config" />
</flow>
```

### How It Works
1. Mule 3 used the transport model: inbound-endpoint (source) and outbound-endpoint (operation)
2. Mule 4 replaced transports with connectors: listener (source) and explicit operations (publish, write, etc.)
3. Each Mule 4 connector has its own configuration element with connection details
4. Polling-based sources (File, FTP, SFTP) now use `<scheduling-strategy>` instead of `pollingFrequency`

### Migration Checklist
- [ ] Map each Mule 3 transport to its Mule 4 connector equivalent
- [ ] Create Mule 4 connector configurations with connection details
- [ ] Replace inbound-endpoints with listeners
- [ ] Replace outbound-endpoints with operations (publish, write, send)
- [ ] Convert `pollingFrequency` to `<scheduling-strategy>`
- [ ] Move credentials to Secure Properties
- [ ] Test connectivity for each converted transport

### Gotchas
- VM queues are application-scoped in Mule 4 (no cross-app VM like Mule 3 domains)
- File connector `autoDelete` defaults differ between Mule 3 and 4
- JMS `exchange-pattern` is replaced by using `publish` (fire-and-forget) vs `publish-consume` (request-reply)
- SFTP connector requires explicit `<scheduling-strategy>` — there is no default poll interval
- Mule 4 File listener uses watermark-based processing by default (vs polling + move in Mule 3)

### Related
- [mule3-to-4-mma](../mule3-to-4-mma/) — Automated migration tool
- [persistent-queues-to-mq](../../cloudhub/persistent-queues-to-mq/) — VM queue to Anypoint MQ
- [mule3-domains-to-mule4](../../architecture/mule3-domains-to-mule4/) — Shared connector configs
