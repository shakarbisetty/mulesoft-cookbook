## Selective Rollback
> Catch non-critical errors with on-error-continue within a transaction while propagating critical errors to trigger rollback.

### When to Use
- Some operations within a transaction can fail without requiring full rollback
- Non-critical enrichment or notification should not cause data loss
- You want fine-grained control over which errors trigger rollback

### Configuration / Code

```xml
<flow name="order-with-enrichment">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <try transactionalAction="ALWAYS_BEGIN">
        <!-- Critical: must succeed -->
        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (id, data) VALUES (:id, :data)</db:sql>
            <db:input-parameters>#[{id: uuid(), data: write(payload, "application/json")}]</db:input-parameters>
        </db:insert>

        <!-- Non-critical: enrichment can fail without rollback -->
        <try>
            <http:request config-ref="Enrichment_Service" path="/enrich" method="POST"/>
            <db:update config-ref="Database_Config">
                <db:sql>UPDATE orders SET enriched_data = :data WHERE id = :id</db:sql>
                <db:input-parameters>#[{data: write(payload, "application/json"), id: vars.orderId}]</db:input-parameters>
            </db:update>
            <error-handler>
                <on-error-continue type="HTTP:TIMEOUT, HTTP:CONNECTIVITY">
                    <logger level="WARN" message="Enrichment failed, order still saved: #[error.description]"/>
                </on-error-continue>
            </error-handler>
        </try>

        <error-handler>
            <!-- Critical errors trigger full rollback -->
            <on-error-propagate type="DB:CONNECTIVITY, DB:QUERY_EXECUTION">
                <logger level="ERROR" message="Critical DB error, rolling back: #[error.description]"/>
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. The outer try starts a transaction
2. Critical DB operations are directly in the transaction scope
3. Non-critical operations are in a nested try with `on-error-continue`
4. `on-error-continue` swallows the error — the transaction stays alive
5. `on-error-propagate` on the outer try triggers rollback for critical failures

### Gotchas
- `on-error-continue` does NOT rollback the transaction — committed work persists
- The nested try must be within the transaction scope to participate
- If the enrichment update succeeds but the outer transaction rolls back, the update is also rolled back (it shares the transaction)
- HTTP requests inside a transaction do NOT participate in rollback — only DB/JMS operations do

### Related
- [Local Transaction Try](../local-transaction-try/) — basic local transactions
- [On-Error-Continue vs Propagate](../../global/on-error-continue-vs-propagate/) — decision matrix
