## Watermark Incremental Sync
> Use Object Store watermarks to process only new/changed records.

### When to Use
- Scheduled batch jobs that should only process records modified since the last run
- Delta sync between systems (CRM to warehouse)

### Configuration / Code

```xml
<flow name="incremental-sync">
    <scheduler><scheduling-strategy><fixed-frequency frequency="300000"/></scheduling-strategy></scheduler>
    <try>
        <os:retrieve key="last-sync-timestamp" objectStore="watermark-store" target="lastSync"/>
        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <set-variable variableName="lastSync" value="2020-01-01T00:00:00Z"/>
            </on-error-continue>
        </error-handler>
    </try>
    <set-variable variableName="syncStart" value="#[now()]"/>
    <db:select config-ref="DB_Config">
        <db:sql>SELECT * FROM orders WHERE updated_at > :since ORDER BY updated_at</db:sql>
        <db:input-parameters>#[{since: vars.lastSync}]</db:input-parameters>
    </db:select>
    <foreach>
        <flow-ref name="sync-record"/>
    </foreach>
    <os:store key="last-sync-timestamp" objectStore="watermark-store">
        <os:value>#[vars.syncStart]</os:value>
    </os:store>
</flow>
```

### How It Works
1. Retrieve the last sync timestamp from Object Store
2. Query only records modified since that timestamp
3. After successful processing, update the watermark to current time
4. Next run picks up where the last one left off

### Gotchas
- Store watermark AFTER successful processing, not before — prevents skipping records on failure
- Use `updated_at` index on the source table for query performance
- Clock skew between app and DB may cause missed records — use DB server time

### Related
- [Batch Concurrency](../batch-concurrency/) — parallel processing
- [DB Cursor Streaming](../../streaming/db-cursor-streaming/) — streaming large queries
