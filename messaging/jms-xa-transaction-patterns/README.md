## JMS XA Transaction Patterns

> Two-phase commit (2PC) with JMS and database resources to guarantee atomic message processing without data loss or duplicates.

### When to Use
- You consume a JMS message and write to a database -- both must succeed or both must roll back
- Your integration moves data between two JMS brokers and needs atomicity across both
- Regulatory requirements mandate that no message is lost AND no duplicate records are created
- You are replacing a legacy XA integration (IBM MQ + Oracle) with MuleSoft

### The Problem
Without XA transactions, there is always a window between committing the database write and acknowledging the JMS message (or vice versa). If the application crashes in that window, you get either data loss (message acked but DB not committed) or duplicates (DB committed but message not acked, redelivered on restart). XA transactions coordinate both resources through a transaction manager, ensuring atomic commit or rollback across all participants. MuleSoft supports XA through the Bitronix transaction manager, but configuring it correctly requires specific connector settings, timeout tuning, and understanding of the 2PC protocol.

### Configuration

#### Bitronix Transaction Manager Setup

```xml
<!-- Required dependency in pom.xml -->
<!--
<dependency>
    <groupId>org.mule.runtime</groupId>
    <artifactId>mule-module-xa-transactions</artifactId>
    <scope>provided</scope>
</dependency>
-->

<!-- Global transaction manager config -->
<bti:transaction-manager />
```

#### JMS Connector with XA Support

```xml
<jms:config name="JMS_XA_Config" doc:name="JMS XA Config">
    <jms:active-mq-connection>
        <jms:caching-strategy>
            <jms:no-caching />
            <!-- IMPORTANT: Do not use connection caching with XA.
                 Cached connections bypass the transaction manager. -->
        </jms:caching-strategy>
        <jms:factory-configuration
            brokerUrl="${activemq.broker.url}"
            maxConnections="10" />
    </jms:active-mq-connection>
</jms:config>

<!-- For IBM MQ with XA -->
<jms:config name="IBM_MQ_XA_Config">
    <jms:generic-connection
        connectionFactory="IBM_MQ_XA_Factory"
        specification="JMS_2_0">
        <jms:caching-strategy>
            <jms:no-caching />
        </jms:caching-strategy>
    </jms:generic-connection>
</jms:config>

<!-- Spring bean for IBM MQ XA Connection Factory -->
<!--
<spring:beans>
    <spring:bean name="IBM_MQ_XA_Factory"
        class="com.ibm.mq.jms.MQXAConnectionFactory">
        <spring:property name="hostName" value="${ibm.mq.host}" />
        <spring:property name="port" value="${ibm.mq.port}" />
        <spring:property name="queueManager" value="${ibm.mq.queue.manager}" />
        <spring:property name="channel" value="${ibm.mq.channel}" />
        <spring:property name="transportType" value="1" />
    </spring:bean>
</spring:beans>
-->
```

#### Database Connector with XA Support

```xml
<db:config name="Database_XA_Config">
    <db:generic-connection>
        <!-- Use XA-capable DataSource -->
        <db:data-source-connection dataSourceRef="XA_DataSource" />
    </db:generic-connection>
</db:config>

<!-- Spring bean for XA DataSource -->
<!--
<spring:beans>
    <spring:bean name="XA_DataSource"
        class="org.postgresql.xa.PGXADataSource">
        <spring:property name="serverNames" value="${db.host}" />
        <spring:property name="portNumbers" value="${db.port}" />
        <spring:property name="databaseName" value="${db.name}" />
        <spring:property name="user" value="${db.user}" />
        <spring:property name="password" value="${db.password}" />
    </spring:bean>
</spring:beans>
-->
```

#### XA Transaction Flow: JMS to Database

```xml
<!--
    Atomic: JMS message consumption + database write.
    If either fails, both roll back.
    The JMS message returns to the queue for redelivery.
-->
<flow name="jms-to-db-xa" maxConcurrency="4">
    <jms:listener
        config-ref="JMS_XA_Config"
        destination="orders"
        ackMode="AUTO"
        transactionalAction="ALWAYS_BEGIN"
        transactionType="XA">
    </jms:listener>

    <logger level="INFO"
        message="XA processing: #[payload.orderId] (JMS MessageID: #[attributes.headers.messageId])" />

    <!-- Parse the JMS message body -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.orderId,
    customerId: payload.customerId,
    amount: payload.amount,
    status: "RECEIVED",
    receivedAt: now()
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Database write participates in XA transaction -->
    <db:insert config-ref="Database_XA_Config"
        transactionalAction="ALWAYS_JOIN">
        <db:sql>INSERT INTO orders (order_id, customer_id, amount, status, received_at)
                 VALUES (:orderId, :customerId, :amount, :status, :receivedAt)</db:sql>
        <db:input-parameters><![CDATA[#[{
            orderId: payload.orderId,
            customerId: payload.customerId,
            amount: payload.amount,
            status: payload.status,
            receivedAt: payload.receivedAt
        }]]]></db:input-parameters>
    </db:insert>

    <!-- Publish confirmation to another queue (also in XA) -->
    <jms:publish
        config-ref="JMS_XA_Config"
        destination="order-confirmations"
        transactionalAction="ALWAYS_JOIN">
        <jms:message>
            <jms:body><![CDATA[#[output application/json --- {
                orderId: payload.orderId,
                status: "CONFIRMED",
                confirmedAt: now()
            }]]]></jms:body>
        </jms:message>
    </jms:publish>

    <error-handler>
        <on-error-propagate type="ANY">
            <logger level="ERROR"
                message="XA transaction will rollback: #[error.description]" />
            <!-- No explicit rollback needed — XA transaction manager handles it.
                 The JMS message is returned to the queue.
                 The DB insert is rolled back.
                 The confirmation publish is rolled back. -->
        </on-error-propagate>
    </error-handler>
</flow>
```

#### XA Transaction Flow: Bridge Two JMS Brokers

```xml
<!--
    Move messages between two JMS brokers atomically.
    Both consume and publish participate in the same XA transaction.
-->
<flow name="jms-bridge-xa" maxConcurrency="2">
    <jms:listener
        config-ref="JMS_XA_Config"
        destination="source-queue"
        ackMode="AUTO"
        transactionalAction="ALWAYS_BEGIN"
        transactionType="XA">
    </jms:listener>

    <!-- Transform for target system -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    (payload),
    bridgedAt: now(),
    sourceSystem: "SYSTEM_A"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Publish to second broker in same XA transaction -->
    <jms:publish
        config-ref="IBM_MQ_XA_Config"
        destination="target-queue"
        transactionalAction="ALWAYS_JOIN">
        <jms:message>
            <jms:body>#[payload]</jms:body>
            <jms:properties>
                <jms:property key="sourceMessageId" value="#[attributes.headers.messageId]" />
            </jms:properties>
        </jms:message>
    </jms:publish>
</flow>
```

### Two-Phase Commit Protocol

```
Phase 1: PREPARE
────────────────────────────────────────────────────────
  Transaction Manager → JMS Broker:   "Can you commit?"
  Transaction Manager → Database:     "Can you commit?"
  JMS Broker → TM:                    "Yes, prepared"
  Database → TM:                      "Yes, prepared"

Phase 2: COMMIT (only if ALL said "Yes")
────────────────────────────────────────────────────────
  Transaction Manager → JMS Broker:   "Commit"
  Transaction Manager → Database:     "Commit"

Phase 2: ROLLBACK (if ANY said "No" or timeout)
────────────────────────────────────────────────────────
  Transaction Manager → JMS Broker:   "Rollback"
  Transaction Manager → Database:     "Rollback"

Recovery (after crash):
────────────────────────────────────────────────────────
  Transaction Manager checks its log for in-doubt transactions.
  Re-issues COMMIT or ROLLBACK based on logged decision.
```

### Gotchas
- **XA is slower than local transactions**: Every operation adds a prepare phase. Expect 2-5x latency increase compared to non-XA flows. Use XA only when atomicity across resources is mandatory.
- **Connection caching breaks XA**: If you enable JMS connection caching (`<jms:caching-strategy>`), cached connections may not be enlisted in the XA transaction. Always use `<jms:no-caching />` for XA connections.
- **Transaction timeout**: The default Bitronix transaction timeout is 60 seconds. If your flow takes longer (e.g., calling a slow API within the XA scope), the transaction times out and rolls back. Configure `mule.xa.transaction.timeout=120` in system properties.
- **In-doubt transactions after crash**: If the app crashes between phase 1 (prepare) and phase 2 (commit/rollback), transactions are "in-doubt." On restart, the Bitronix TM reads its recovery log and resolves them. Ensure the recovery log directory is persistent (not ephemeral container storage).
- **XA + HTTP is not possible**: HTTP calls cannot participate in XA transactions. If your flow calls an HTTP API inside an XA scope, the API call is NOT rolled back if the transaction fails. Use the Saga pattern instead for HTTP-based distributed transactions.
- **Deadlocks with high concurrency**: With `maxConcurrency > 1` and XA, multiple threads hold locks on both the JMS broker and database simultaneously. If two threads process messages that update the same DB row, you get a deadlock. Set `maxConcurrency=1` for queues with related messages, or use row-level locking strategies.
- **CloudHub and XA recovery**: CloudHub 1.0 persistent Object Store is not suitable for Bitronix recovery logs. CloudHub 2.0 with persistent volumes is required for reliable XA recovery. Without persistent recovery logs, in-doubt transactions after a crash may cause data inconsistency.
- **PostgreSQL XA requires max_prepared_transactions**: PostgreSQL defaults to `max_prepared_transactions=0`, which disables XA. Set it to at least `maxConcurrency * 2` in postgresql.conf.

### Testing

```xml
<munit:test name="test-xa-rollback-on-db-failure"
    description="Verify JMS message is not consumed when DB insert fails">

    <munit:behavior>
        <!-- Mock DB to throw error -->
        <munit-tools:mock-when processor="db:insert">
            <munit-tools:then-return>
                <munit-tools:error typeId="DB:CONNECTIVITY" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- Publish a test message to JMS -->
        <jms:publish config-ref="JMS_XA_Config" destination="orders">
            <jms:message>
                <jms:body>#[output application/json --- {orderId: "ORD-XA-001", amount: 50.00}]</jms:body>
            </jms:message>
        </jms:publish>

        <!-- Wait for consumer to process and rollback -->
        <munit-tools:sleep time="3000" />
    </munit:execution>

    <munit:validation>
        <!-- Message should still be on the queue (not consumed due to rollback) -->
        <jms:consume config-ref="JMS_XA_Config"
            destination="orders"
            maximumWait="5000" />
        <munit-tools:assert-that
            expression="#[payload.orderId]"
            is="#[MunitTools::equalTo('ORD-XA-001')]" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [JMS IBM MQ Production](../jms-ibm-mq-production/) -- IBM MQ-specific XA configuration
- [EDA Saga Orchestration](../eda-saga-orchestration/) -- saga pattern when XA is not possible (HTTP, cross-service)
- [VM vs AMQ vs JMS Decision](../vm-vs-amq-vs-jms-decision/) -- when JMS XA is worth the complexity
