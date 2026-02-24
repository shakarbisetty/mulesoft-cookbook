## Batch Aggregator Commit Sizing
> Configure aggregatorSize for efficient bulk database writes.

### When to Use
- Batch jobs writing to databases where row-by-row inserts are too slow
- You want 10–50x write speedup with bulk operations

### Configuration / Code

```xml
<batch:step name="upsert-step">
    <batch:aggregator size="200">
        <db:bulk-insert config-ref="Database_Config">
            <db:sql>INSERT INTO orders (id, customer, total) VALUES (:id, :customer, :total)</db:sql>
        </db:bulk-insert>
    </batch:aggregator>
</batch:step>
```

### How It Works
1. Aggregator collects `size` records before executing the inner block
2. `db:bulk-insert` sends all 200 records in a single JDBC batch call
3. 200 rows × 1 call vs 200 × individual calls = ~20x faster

### Gotchas
- If the batch fails, all 200 records in the aggregator are marked failed
- Aggregator size should match your DB batch capacity (MySQL max_allowed_packet)
- The last block may be smaller than `size` — it still executes

### Related
- [Block Size Optimization](../block-size-optimization/) — input block sizing
- [Bulk Insert Aggregator](../../database/bulk-insert-aggregator/) — standalone pattern
