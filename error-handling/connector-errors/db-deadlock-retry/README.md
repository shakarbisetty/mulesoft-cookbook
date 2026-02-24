## Database Deadlock Retry
> Detect database deadlock errors and retry the transaction with a short delay.

### When to Use
- Concurrent database writes cause occasional deadlocks
- The operation is safe to retry (idempotent or within a new transaction)
- You want automatic recovery without manual intervention

### Configuration / Code

```xml
<flow name="upsert-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/inventory" method="PUT"/>
    <until-successful maxRetries="3" millisBetweenRetries="500">
        <try transactionalAction="ALWAYS_BEGIN">
            <db:update config-ref="Database_Config">
                <db:sql>UPDATE inventory SET quantity = :qty WHERE sku = :sku</db:sql>
                <db:input-parameters>#[{qty: payload.quantity, sku: payload.sku}]</db:input-parameters>
            </db:update>
        </try>
    </until-successful>
    <error-handler>
        <on-error-propagate type="MULE:RETRY_EXHAUSTED">
            <set-variable variableName="httpStatus" value="409"/>
            <set-payload value='{"error":"Conflict","message":"Database deadlock persisted after retries"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `until-successful` wraps the DB operation for automatic retry
2. Each retry starts a new transaction (so the deadlocked one is rolled back)
3. Short delay (500ms) gives the competing transaction time to complete
4. After 3 retries, returns 409 Conflict

### Gotchas
- Only retry if the operation is idempotent or uses a new transaction each time
- Deadlocks are a sign of contention — fix the root cause (ordering, indexing)
- Some databases return specific error codes for deadlocks — match on those if needed

### Related
- [Until Successful Basic](../../retry/until-successful-basic/) — retry fundamentals
- [Upsert on Conflict](../../performance/database/upsert-on-conflict/) — avoid deadlocks with upserts
