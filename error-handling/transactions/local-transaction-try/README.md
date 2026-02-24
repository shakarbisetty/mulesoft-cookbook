## Local Transaction with Try Scope
> Use a try scope with transactionalAction for single-resource transactions that roll back together.

### When to Use
- Multiple database operations that must all succeed or all fail
- Single-resource transactional scope (one database connection)
- Simpler than XA when only one transactional resource is involved

### Configuration / Code

```xml
<flow name="transfer-funds-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/transfer" method="POST"/>
    <try transactionalAction="ALWAYS_BEGIN">
        <db:update config-ref="Database_Config">
            <db:sql>UPDATE accounts SET balance = balance - :amount WHERE id = :fromId</db:sql>
            <db:input-parameters>#[{amount: payload.amount, fromId: payload.fromAccount}]</db:input-parameters>
        </db:update>
        <db:update config-ref="Database_Config">
            <db:sql>UPDATE accounts SET balance = balance + :amount WHERE id = :toId</db:sql>
            <db:input-parameters>#[{amount: payload.amount, toId: payload.toAccount}]</db:input-parameters>
        </db:update>
        <db:insert config-ref="Database_Config">
            <db:sql>INSERT INTO transfers (from_id, to_id, amount, created_at) VALUES (:from, :to, :amt, NOW())</db:sql>
            <db:input-parameters>#[{from: payload.fromAccount, to: payload.toAccount, amt: payload.amount}]</db:input-parameters>
        </db:insert>
        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR" message="Transfer failed, rolling back: #[error.description]"/>
                <set-variable variableName="httpStatus" value="500"/>
                <set-payload value='{"error":"Transfer failed"}' mimeType="application/json"/>
            </on-error-propagate>
        </error-handler>
    </try>
    <set-payload value='{"status":"transferred"}' mimeType="application/json"/>
</flow>
```

### How It Works
1. `transactionalAction="ALWAYS_BEGIN"` starts a new local transaction
2. All DB operations within the try use the same connection and transaction
3. If any operation fails, `on-error-propagate` causes automatic rollback of all operations
4. On success, the transaction is committed when execution leaves the try scope

### Gotchas
- All DB operations must use the same `config-ref` to share the transaction
- Local transactions only work with a single resource — use XA for multiple resources
- `on-error-continue` inside the try does NOT rollback — it commits what was done so far

### Related
- [XA Transaction Rollback](../xa-transaction-rollback/) — multi-resource transactions
- [Selective Rollback](../selective-rollback/) — partial rollback within transactions
