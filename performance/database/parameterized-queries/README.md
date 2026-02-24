## Parameterized Queries
> Use input parameters for prepared statement reuse and SQL injection prevention.

### When to Use
- Every database query (always use parameterized queries)
- Preventing SQL injection attacks
- Enabling prepared statement plan caching

### Configuration / Code

```xml
<!-- CORRECT: parameterized query -->
<db:select config-ref="Database_Config">
    <db:sql>SELECT * FROM users WHERE email = :email AND status = :status</db:sql>
    <db:input-parameters>#[{email: attributes.queryParams.email, status: "active"}]</db:input-parameters>
</db:select>

<!-- WRONG: string concatenation (SQL injection risk!) -->
<!-- <db:sql>SELECT * FROM users WHERE email = ' ++ payload.email ++ '</db:sql> -->
```

### How It Works
1. `:paramName` placeholders are replaced by the JDBC driver with bound values
2. The SQL plan is compiled once and reused (prepared statement caching)
3. User input is always treated as data, never as SQL code

### Gotchas
- NEVER concatenate user input into SQL strings — always use parameters
- Column names and table names CANNOT be parameterized — only values
- Use `db:connection-properties` with `cachePrepStmts=true` for plan caching
- Dynamic table/column names need whitelist validation, not parameterization

### Related
- [Upsert on Conflict](../upsert-on-conflict/) — parameterized upserts
- [Bulk Insert Aggregator](../bulk-insert-aggregator/) — parameterized bulk operations
