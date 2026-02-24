## Bulk Insert with Batch Aggregator
> Collect records and execute single bulk insert for 10-50x speedup.

### When to Use
- Inserting thousands of records from batch processing
- Row-by-row inserts are too slow
- Database supports JDBC batch operations

### Configuration / Code

```xml
<batch:step name="db-write-step">
    <batch:aggregator size="200">
        <db:bulk-insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (id, customer, total, created_at)
                     VALUES (:id, :customer, :total, :created)</db:sql>
            <db:bulk-input-parameters><![CDATA[#[payload map {
                id: $.orderId,
                customer: $.customerName,
                total: $.orderTotal,
                created: now()
            }]]]></db:bulk-input-parameters>
        </db:bulk-insert>
    </batch:aggregator>
</batch:step>
```

### How It Works
1. Aggregator collects 200 records before executing
2. `db:bulk-insert` sends all records in one JDBC batch call
3. Single network round-trip instead of 200 individual inserts
4. Database commits all rows in one transaction

### Gotchas
- If the bulk insert fails, ALL 200 records fail — no partial success
- `bulk-input-parameters` expects a list of maps — each map is one row
- MySQL: increase `max_allowed_packet` for large batches
- PostgreSQL: use `reWriteBatchedInserts=true` in connection string for best performance

### Related
- [Aggregator Commit Sizing](../../batch/aggregator-commit-sizing/) — sizing the aggregator
- [Upsert on Conflict](../upsert-on-conflict/) — upsert pattern
