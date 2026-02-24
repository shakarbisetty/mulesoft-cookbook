## XA Transaction Rollback
> Wrap database + JMS operations in an XA transaction so both roll back atomically if either fails.

### When to Use
- You write to a database AND publish to a JMS queue in the same flow
- Both operations must succeed or both must roll back (two-phase commit)
- Data consistency across multiple resources is critical

### Configuration / Code

```xml
<flow name="order-with-notification">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <try transactionalAction="ALWAYS_BEGIN" transactionType="XA">
        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (id, customer_id, total) VALUES (:id, :cid, :total)</db:sql>
            <db:input-parameters>#[{id: uuid(), cid: payload.customerId, total: payload.total}]</db:input-parameters>
        </db:insert>
        <jms:publish config-ref="JMS_Config" destination="order-events">
            <jms:body>#[write(payload, "application/json")]</jms:body>
        </jms:publish>
        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR" message="XA transaction rolling back: #[error.description]"/>
                <set-variable variableName="httpStatus" value="500"/>
                <set-payload value='{"error":"Transaction failed, all changes rolled back"}' mimeType="application/json"/>
            </on-error-propagate>
        </error-handler>
    </try>
    <set-payload value='{"status":"created"}' mimeType="application/json"/>
</flow>
```

### How It Works
1. `transactionType="XA"` enables two-phase commit across multiple resources
2. Both DB insert and JMS publish participate in the same XA transaction
3. If the JMS publish fails, the DB insert is rolled back automatically
4. `on-error-propagate` triggers the rollback and returns an error response

### Gotchas
- Both connectors must support XA transactions (DB and JMS do; HTTP does not)
- XA transactions have higher latency due to the two-phase commit protocol
- The transaction manager requires a persistent log — ensure `/tmp` has space on CloudHub
- CloudHub 2.0 supports XA; CloudHub 1.0 requires persistent queues workaround
- Avoid long-running operations inside XA — keep the scope tight

### Related
- [Local Transaction Try](../local-transaction-try/) — single-resource transactions
- [SAGA Compensation](../saga-compensation/) — eventual consistency alternative
