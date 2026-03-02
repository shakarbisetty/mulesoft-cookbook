## JMS IBM MQ Production Patterns

> Production-hardened IBM MQ integration with backout queues, durable subscriptions, MQ cluster failover, and connection recovery.

### When to Use
- You are integrating MuleSoft with IBM MQ (WebSphere MQ / IBM MQ 9.x) in an enterprise environment
- You need to handle message failures with backout queues (IBM MQ's DLQ equivalent)
- Your IBM MQ topology uses multi-instance queue managers or MQ clusters for high availability
- You need durable topic subscriptions that survive consumer restarts

### The Problem
IBM MQ is the most common enterprise message broker that MuleSoft integrates with, yet most implementations use the bare minimum configuration -- a queue name and connection details. Production IBM MQ requires: backout queue handling for poison messages, durable subscriptions for pub/sub, connection failover for HA queue managers, and proper credential/SSL configuration. Getting these wrong causes silent message loss, connection storms during failover, and subscription data gaps.

### Configuration

#### IBM MQ Connection with Failover

```xml
<!-- IBM MQ Connector with multi-instance failover -->
<jms:config name="IBM_MQ_Production">
    <jms:generic-connection
        specification="JMS_2_0"
        connectionFactory="IBM_MQ_CF">
        <jms:caching-strategy>
            <jms:default-caching
                sessionCacheSize="10"
                cacheConsumers="false" />
            <!-- cacheConsumers=false: required for durable subscriptions -->
        </jms:caching-strategy>
        <reconnection>
            <reconnect frequency="5000" count="10" />
        </reconnection>
    </jms:generic-connection>
</jms:config>

<!-- Spring bean: IBM MQ Connection Factory with HA -->
<!--
<spring:beans>
    <spring:bean name="IBM_MQ_CF"
        class="com.ibm.mq.jms.MQConnectionFactory">
        <spring:property name="hostName" value="${ibm.mq.host1}" />
        <spring:property name="port" value="${ibm.mq.port}" />
        <spring:property name="queueManager" value="${ibm.mq.queue.manager}" />
        <spring:property name="channel" value="${ibm.mq.channel}" />
        <spring:property name="transportType" value="1" />

        <! Multi-instance QM failover: comma-separated host(port) list
        <spring:property name="connectionNameList"
            value="${ibm.mq.host1}(${ibm.mq.port}),${ibm.mq.host2}(${ibm.mq.port})" />

        <! SSL/TLS configuration
        <spring:property name="SSLCipherSuite" value="TLS_RSA_WITH_AES_128_CBC_SHA256" />

        <! Client reconnection
        <spring:property name="clientReconnectOptions" value="67108864" />
        <! 67108864 = WMQConstants.WMQ_CLIENT_RECONNECT
        <spring:property name="clientReconnectTimeout" value="1800" />
    </spring:bean>
</spring:beans>
-->
```

#### Properties File

```properties
# ibm-mq.properties
ibm.mq.host1=mqserver1.corp.example.com
ibm.mq.host2=mqserver2.corp.example.com
ibm.mq.port=1414
ibm.mq.queue.manager=QM_PROD
ibm.mq.channel=MULE.SVRCONN
ibm.mq.ssl.cipher=TLS_RSA_WITH_AES_128_CBC_SHA256
ibm.mq.client.id=MULE_APP_ORDERS
```

#### Consumer with Backout Queue Handling

```xml
<!--
    IBM MQ backout queue: when a message is rolled back BACKOUT_THRESHOLD
    times, MQ moves it to the BACKOUT_REQ_Q (backout requeue queue).

    Queue definition on MQ side:
    DEFINE QLOCAL(ORDERS) +
        BOTHRESH(3) +
        BOQNAME(ORDERS.BACKOUT)

    In Mule: use transactional listener and inspect backout count.
-->
<flow name="ibm-mq-consumer-with-backout" maxConcurrency="4">
    <jms:listener
        config-ref="IBM_MQ_Production"
        destination="ORDERS"
        ackMode="AUTO"
        transactionalAction="ALWAYS_BEGIN"
        transactionType="LOCAL">
    </jms:listener>

    <!-- Check backout count (IBM MQ sets JMSXDeliveryCount) -->
    <set-variable variableName="deliveryCount"
        value="#[attributes.properties.jmsxProperties.JMSXDeliveryCount default 1]" />

    <choice>
        <!-- Approaching backout threshold: log warning -->
        <when expression="#[vars.deliveryCount > 2]">
            <logger level="WARN"
                message="Message #[attributes.headers.messageId] delivery attempt #[vars.deliveryCount] — approaching backout" />
        </when>
    </choice>

    <try>
        <!-- Parse IBM MQ message (often MQSTR or MQHRF2 format) -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
// IBM MQ messages may arrive as text/plain or application/xml
if (payload is String)
    read(payload, "application/json")
else
    payload]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <flow-ref name="process-order" />

        <!-- Transaction commits on successful completion (auto-ack) -->

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                    message="Processing failed (attempt #[vars.deliveryCount]): #[error.description]" />
                <!-- Transaction rolls back. Message returned to queue.
                     After BOTHRESH (3) rollbacks, MQ moves it to BOQNAME. -->
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Backout Queue Monitor and Reprocessor

```xml
<flow name="backout-queue-monitor">
    <scheduler>
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <!-- Browse the backout queue (non-destructive read) -->
    <jms:consume
        config-ref="IBM_MQ_Production"
        destination="ORDERS.BACKOUT"
        maximumWait="5000"
        ackMode="MANUAL" />

    <choice>
        <when expression="#[payload != null]">
            <logger level="ERROR"
                message="Backout queue has messages — alerting operations team" />

            <!-- Send alert -->
            <http:request config-ref="Alert_API" method="POST" path="/alerts">
                <http:body><![CDATA[#[output application/json --- {
                    severity: "HIGH",
                    source: "IBM_MQ",
                    queue: "ORDERS.BACKOUT",
                    message: "Poison messages detected in backout queue",
                    timestamp: now()
                }]]]></http:body>
            </http:request>
        </when>
    </choice>
</flow>
```

#### Durable Topic Subscription

```xml
<!--
    Durable subscription: messages are retained by MQ even when
    the subscriber is disconnected. On reconnect, all missed
    messages are delivered.

    Requires:
    - Unique clientId on the connection factory
    - durableSubscriptionName on the listener
    - cacheConsumers=false on the connection (see above)
-->
<flow name="ibm-mq-durable-subscriber" maxConcurrency="1">
    <jms:listener
        config-ref="IBM_MQ_Production"
        destination="EVENTS/ORDERS"
        ackMode="AUTO"
        numberOfConsumers="1"
        durable="true"
        subscriptionName="MULE_ORDER_EVENTS_SUB">
        <jms:consumer-type>
            <jms:topic-consumer />
        </jms:consumer-type>
    </jms:listener>

    <logger level="INFO"
        message="Received topic event: #[payload]" />

    <flow-ref name="handle-order-event" />

    <error-handler>
        <on-error-continue type="ANY">
            <logger level="ERROR"
                message="Topic event processing failed: #[error.description]" />
            <!-- For topics: message is ACKed (lost) even on error.
                 Log to error database for manual recovery. -->
            <db:insert config-ref="Database_Config">
                <db:sql>INSERT INTO failed_events (payload, error, created_at)
                         VALUES (:payload, :error, :created_at)</db:sql>
                <db:input-parameters><![CDATA[#[{
                    payload: write(payload, "application/json"),
                    error: error.description,
                    created_at: now()
                }]]]></db:input-parameters>
            </db:insert>
        </on-error-continue>
    </error-handler>
</flow>
```

#### MQ Cluster Consumer (Workload Distribution)

```xml
<!--
    IBM MQ Cluster: messages are distributed across cluster queue instances.
    Each MuleSoft instance connects to its local queue manager.
    MQ handles workload distribution across the cluster.

    Queue definition:
    DEFINE QLOCAL(SHARED.ORDERS) CLUSTER(PROD_CLUSTER) DEFBIND(NOTFIXED)
-->
<flow name="mq-cluster-consumer" maxConcurrency="4">
    <jms:listener
        config-ref="IBM_MQ_Production"
        destination="SHARED.ORDERS"
        ackMode="AUTO"
        transactionalAction="ALWAYS_BEGIN"
        transactionType="LOCAL">
    </jms:listener>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.orderId,
    processedBy: Mule::p('mule.cluster.node.id') default "standalone",
    processedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="process-clustered-order" />
</flow>
```

### Gotchas
- **MQRC_NOT_AUTHORIZED (2035)**: The most common IBM MQ error in MuleSoft. Causes: wrong channel name, missing CHLAUTH rule, client IP not allowed, or SSL mismatch. Check MQ error logs (`AMQERR01.LOG`) on the queue manager, not just the Mule error.
- **MQRC_BACKOUT_THRESHOLD_REACHED**: When a message exceeds the backout threshold, MQ moves it to the backout requeue queue. If `BOQNAME` is blank, the message goes to the system dead letter queue (`SYSTEM.DEAD.LETTER.QUEUE`). Always configure `BOQNAME` explicitly.
- **Connection storms during QM failover**: When a multi-instance queue manager fails over, all clients reconnect simultaneously to the standby. With 50 Mule apps x 10 connections each = 500 simultaneous reconnection attempts. Use exponential backoff on reconnect (`frequency="5000"` with jitter).
- **Durable subscription cleanup**: If you change `subscriptionName` or delete the flow, the old durable subscription remains on the MQ broker, accumulating messages indefinitely. Clean up with: `DISPLAY SUB(MULE_ORDER_EVENTS_SUB)` then `DELETE SUB(MULE_ORDER_EVENTS_SUB)`.
- **IBM MQ message format**: IBM MQ wraps messages in MQMD (Message Descriptor) and RFH2 headers by default. MuleSoft's JMS connector strips RFH2 when `targetClient=1` is set on the destination. If you receive garbled headers in the payload, check the `targetClient` setting on the MQ queue definition.
- **SSL cipher suite mismatch**: IBM MQ and JVM use different cipher suite names. IBM: `TLS_RSA_WITH_AES_128_CBC_SHA256`, JVM/Oracle: `SSL_RSA_WITH_AES_128_CBC_SHA256`. Set `-Dcom.ibm.mq.cfg.useIBMCipherMappings=false` in JVM args to use standard names.
- **PUT disabled queues**: If the backout queue has `PUT(DISABLED)`, messages that exceed the backout threshold are lost. Always verify backout queue is PUT-enabled before going to production.
- **maxConcurrency vs numberOfConsumers**: `numberOfConsumers` creates multiple JMS sessions (parallel socket connections to MQ). `maxConcurrency` controls Mule thread pool. Set `numberOfConsumers=1` and control parallelism via `maxConcurrency` to avoid excessive MQ connections.

### Testing

```xml
<munit:test name="test-backout-count-detection"
    description="Verify high delivery count triggers warning log">

    <munit:execution>
        <!-- Simulate message with high delivery count -->
        <set-payload value='#[output application/json --- {orderId: "ORD-MQ-001"}]' />
        <set-variable variableName="attributes" value="#[{
            headers: {messageId: 'AMQ-12345'},
            properties: {
                jmsxProperties: {JMSXDeliveryCount: 3}
            }
        }]" />
        <flow-ref name="ibm-mq-consumer-with-backout" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[vars.deliveryCount]"
            is="#[MunitTools::greaterThan(2)]" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [JMS XA Transaction Patterns](../jms-xa-transaction-patterns/) -- XA transactions with IBM MQ
- [VM vs AMQ vs JMS Decision](../vm-vs-amq-vs-jms-decision/) -- when to use IBM MQ vs alternatives
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) -- DLQ patterns (Anypoint MQ equivalent of backout queues)
- [Message Ordering Guarantees](../message-ordering-guarantees/) -- ordering with MQ clusters
