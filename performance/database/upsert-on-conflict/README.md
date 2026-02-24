## Database Upsert with ON CONFLICT
> Use database-native upsert to avoid select-then-insert/update anti-pattern.

### When to Use
- Syncing data where records may already exist
- Avoiding deadlocks from concurrent select-then-insert patterns
- Atomic insert-or-update operations

### Configuration / Code

```xml
<!-- PostgreSQL ON CONFLICT -->
<db:insert config-ref="Postgres_Config">
    <db:sql>INSERT INTO products (sku, name, price, updated_at)
             VALUES (:sku, :name, :price, NOW())
             ON CONFLICT (sku) DO UPDATE SET
                 name = EXCLUDED.name,
                 price = EXCLUDED.price,
                 updated_at = NOW()</db:sql>
    <db:input-parameters>#[{sku: payload.sku, name: payload.name, price: payload.price}]</db:input-parameters>
</db:insert>

<!-- MySQL ON DUPLICATE KEY -->
<db:insert config-ref="MySQL_Config">
    <db:sql>INSERT INTO products (sku, name, price)
             VALUES (:sku, :name, :price)
             ON DUPLICATE KEY UPDATE name = VALUES(name), price = VALUES(price)</db:sql>
    <db:input-parameters>#[{sku: payload.sku, name: payload.name, price: payload.price}]</db:input-parameters>
</db:insert>
```

### How It Works
1. Attempt to INSERT the record
2. If a unique constraint violation occurs (duplicate key), UPDATE instead
3. Atomic — no race condition between checking and writing
4. Single SQL statement, single round-trip

### Gotchas
- Requires a unique constraint on the conflict column(s) — add an index
- `ON CONFLICT` is PostgreSQL; `ON DUPLICATE KEY` is MySQL; `MERGE` is Oracle/SQL Server
- Upsert increments auto-increment IDs even on updates (PostgreSQL)

### Related
- [Bulk Insert Aggregator](../bulk-insert-aggregator/) — batch upserts
- [DB Deadlock Retry](../../../error-handling/connector-errors/db-deadlock-retry/) — avoiding deadlocks
