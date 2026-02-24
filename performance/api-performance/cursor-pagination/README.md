## Cursor-Based API Pagination
> Implement cursor pagination for large result sets instead of offset pagination.

### When to Use
- APIs returning large datasets where offset pagination is slow
- Real-time data where new records can shift offset positions
- Better performance than LIMIT/OFFSET for deep pages

### Configuration / Code

```xml
<flow name="cursor-paginated-api">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>
    <set-variable variableName="cursor" value="#[attributes.queryParams.cursor default null]"/>
    <set-variable variableName="limit" value="#[attributes.queryParams.limit default 20]"/>
    <choice>
        <when expression="#[vars.cursor != null]">
            <db:select config-ref="DB_Config">
                <db:sql>SELECT * FROM orders WHERE id > :cursor ORDER BY id LIMIT :limit</db:sql>
                <db:input-parameters>#[{cursor: vars.cursor, limit: vars.limit + 1}]</db:input-parameters>
            </db:select>
        </when>
        <otherwise>
            <db:select config-ref="DB_Config">
                <db:sql>SELECT * FROM orders ORDER BY id LIMIT :limit</db:sql>
                <db:input-parameters>#[{limit: vars.limit + 1}]</db:input-parameters>
            </db:select>
        </otherwise>
    </choice>
    <ee:transform xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core">
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
var hasMore = sizeOf(payload) > vars.limit
var items = if (hasMore) payload[0 to vars.limit - 1] else payload
---
{
    data: items,
    pagination: {
        nextCursor: if (hasMore) items[-1].id else null,
        hasMore: hasMore,
        limit: vars.limit
    }
}]]></ee:set-payload></ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. Client sends `?cursor=<lastId>&limit=20`
2. Query fetches `limit + 1` records after the cursor using indexed `id > :cursor`
3. If we got more than `limit`, there are more pages — return next cursor
4. O(1) performance regardless of page depth (vs O(n) for OFFSET)

### Gotchas
- Cursor must be a unique, sortable column (usually primary key or timestamp)
- Clients cannot "jump to page 5" — cursor pagination is forward-only
- If records are deleted between pages, the cursor may skip items — use soft deletes

### Related
- [Watermark Incremental Sync](../../batch/watermark-incremental-sync/) — similar cursor pattern
- [DB Cursor Streaming](../../streaming/db-cursor-streaming/) — server-side cursors
