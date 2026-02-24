## Query Timeout
> Set per-query timeouts to prevent long-running queries from holding connections.

### When to Use
- Queries against large tables that could run indefinitely
- Protecting connection pool from being held by slow queries
- SLA enforcement on database operations

### Configuration / Code

```xml
<db:select config-ref="Database_Config" queryTimeout="10" queryTimeoutUnit="SECONDS">
    <db:sql>SELECT * FROM transactions WHERE created_at BETWEEN :start AND :end</db:sql>
    <db:input-parameters>#[{start: vars.startDate, end: vars.endDate}]</db:input-parameters>
</db:select>
```

### How It Works
1. `queryTimeout` sets the maximum execution time for the query
2. If exceeded, the JDBC driver cancels the query and throws an error
3. The connection is returned to the pool (not leaked)

### Gotchas
- `queryTimeout` is per-statement, not per-connection
- Not all JDBC drivers support query timeout (MySQL requires `socketTimeout` as fallback)
- Cancelled queries may still run on the database briefly before being killed
- Set timeouts shorter than your HTTP response timeout to fail gracefully

### Related
- [Connection Timeouts](../../connections/connection-timeouts/) — connection-level timeouts
- [DB Deadlock Retry](../../../error-handling/connector-errors/db-deadlock-retry/) — handling slow queries
