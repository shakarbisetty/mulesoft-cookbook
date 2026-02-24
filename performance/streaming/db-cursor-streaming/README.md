## Database Cursor Streaming
> Stream large database result sets using repeatable-iterable with fetchSize.

### When to Use
- Queries returning 10K+ rows that would OOM if loaded at once
- ETL pipelines reading from large tables
- Batch jobs sourced from database queries

### Configuration / Code

```xml
<db:config name="Database_Config">
    <db:my-sql-connection host="${db.host}" port="3306" database="warehouse"
                          user="${db.user}" password="${db.password}"/>
</db:config>

<flow name="large-query-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/export"/>
    <db:select config-ref="Database_Config" fetchSize="200">
        <db:sql>SELECT * FROM transactions WHERE created_at > :since</db:sql>
        <db:input-parameters>#[{since: attributes.queryParams.since}]</db:input-parameters>
        <repeatable-file-store-iterable
            inMemoryObjects="500"
            maxInMemoryObjects="1000"/>
    </db:select>
    <foreach>
        <flow-ref name="process-record"/>
    </foreach>
</flow>
```

### How It Works
1. `fetchSize="200"` tells the JDBC driver to fetch 200 rows per network round-trip
2. `repeatable-file-store-iterable` buffers first 500 objects in memory, spills rest to disk
3. `foreach` iterates one record at a time — constant memory usage regardless of result set size
4. The cursor stays open on the database until iteration completes

### Gotchas
- The DB connection is held open for the entire iteration — keep it short or use batch
- `fetchSize` is a hint — not all JDBC drivers honor it (MySQL requires `useCursorFetch=true`)
- PostgreSQL needs `defaultRowFetchSize` on the connection string
- Do NOT use `sizeOf(payload)` before iterating — it forces loading all rows

### Related
- [Repeatable File Store](../repeatable-file-store/) — byte stream equivalent
- [Bulk Insert Aggregator](../../database/bulk-insert-aggregator/) — batch writes
- [Block Size Optimization](../../batch/block-size-optimization/) — batch processing large sets
