## Database Change Data Capture

> Database CDC without dedicated CDC tools — timestamp-based polling, trigger-based capture, and transaction log tailing patterns.

### When to Use

- Propagating database changes to downstream systems in near-real-time without a dedicated CDC platform (Debezium, Oracle GoldenGate, AWS DMS)
- Building event-driven integrations from legacy databases that only support polling
- Syncing reference data or transactional data between microservices with different data stores
- Implementing incremental data extraction for ETL pipelines where full loads are too expensive

### CDC Approach Comparison

| Approach | Latency | Captures Deletes | Schema Changes | DB Load | Complexity |
|----------|---------|-------------------|----------------|---------|------------|
| Timestamp polling | Seconds-minutes | No (unless soft-delete) | Tolerant | Low (indexed query) | Low |
| Trigger-based | Sub-second | Yes | Requires trigger updates | Medium (write overhead) | Medium |
| Transaction log | Sub-second | Yes | Requires log parsing | Very low (read-only on log) | High |
| Snapshot diff | Minutes-hours | Yes | Tolerant | High (full scan) | Low |

### Configuration

#### Timestamp-Based Polling with Object Store Watermark

```xml
<os:object-store name="CDC_Watermark_Store"
    doc:name="CDC Watermark Store"
    persistent="true"
    entryTtl="0"
    maxEntries="100" />

<flow name="database-cdc-polling-flow">
    <scheduler doc:name="Poll Every 30s">
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS" />
        </scheduling-strategy>
    </scheduler>

    <!-- Read last watermark -->
    <os:retrieve key="orders_last_modified"
        objectStore="CDC_Watermark_Store"
        doc:name="Get Watermark">
        <os:default-value><![CDATA[1970-01-01T00:00:00Z]]></os:default-value>
    </os:retrieve>

    <set-variable variableName="lastWatermark" value="#[payload]" />

    <!-- Query for changes since last watermark -->
    <db:select config-ref="Database_Config" doc:name="Select Changed Records">
        <db:sql><![CDATA[SELECT id, customer_id, order_total, status, created_at, updated_at
FROM orders
WHERE updated_at > :lastModified
ORDER BY updated_at ASC
LIMIT 1000]]></db:sql>
        <db:input-parameters><![CDATA[#[{
    lastModified: vars.lastWatermark
}]]]></db:input-parameters>
    </db:select>

    <choice doc:name="Has Changes?">
        <when expression="#[sizeOf(payload) > 0]">
            <set-variable variableName="newWatermark"
                value="#[payload[-1].updated_at as String {format: \"yyyy-MM-dd'T'HH:mm:ss'Z'\"}]" />

            <ee:transform doc:name="Build Change Events">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map {
    eventType: if ($.created_at == $.updated_at) "INSERT" else "UPDATE",
    table: "orders",
    timestamp: $.updated_at,
    data: {
        id: $.id,
        customerId: $.customer_id,
        orderTotal: $.order_total,
        status: $.status
    }
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <!-- Publish change events -->
            <foreach doc:name="Publish Each Event">
                <anypoint-mq:publish config-ref="AnypointMQ_Config"
                    destination="order-change-events"
                    doc:name="Publish Change Event" />
            </foreach>

            <!-- Update watermark after successful processing -->
            <os:store key="orders_last_modified"
                objectStore="CDC_Watermark_Store"
                doc:name="Update Watermark">
                <os:value><![CDATA[#[vars.newWatermark]]]></os:value>
            </os:store>

            <logger level="INFO"
                message="CDC: Published #[sizeOf(payload)] change events. New watermark: #[vars.newWatermark]" />
        </when>
    </choice>

    <error-handler>
        <on-error-continue type="ANY">
            <logger level="ERROR"
                message="CDC polling error: #[error.description]. Watermark NOT advanced." />
            <!-- Watermark not updated on error — next poll retries same window -->
        </on-error-continue>
    </error-handler>
</flow>
```

#### Trigger-Based CDC (Database Side + MuleSoft Consumer)

SQL trigger (create on your database):

```sql
-- Change tracking table
CREATE TABLE change_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    INDEX idx_processed_changed (processed, changed_at)
);

-- Trigger on source table
CREATE TRIGGER orders_after_insert
AFTER INSERT ON orders
FOR EACH ROW
INSERT INTO change_log (table_name, record_id, operation, new_values)
VALUES ('orders', NEW.id, 'INSERT', JSON_OBJECT(
    'customer_id', NEW.customer_id,
    'order_total', NEW.order_total,
    'status', NEW.status
));

CREATE TRIGGER orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
INSERT INTO change_log (table_name, record_id, operation, old_values, new_values)
VALUES ('orders', NEW.id, 'UPDATE',
    JSON_OBJECT('status', OLD.status, 'order_total', OLD.order_total),
    JSON_OBJECT('status', NEW.status, 'order_total', NEW.order_total)
);

CREATE TRIGGER orders_after_delete
AFTER DELETE ON orders
FOR EACH ROW
INSERT INTO change_log (table_name, record_id, operation, old_values)
VALUES ('orders', OLD.id, 'DELETE',
    JSON_OBJECT('customer_id', OLD.customer_id, 'order_total', OLD.order_total, 'status', OLD.status)
);
```

MuleSoft consumer for the change log:

```xml
<flow name="database-cdc-trigger-consumer-flow">
    <scheduler doc:name="Poll Change Log">
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="SECONDS" />
        </scheduling-strategy>
    </scheduler>

    <db:select config-ref="Database_Config" doc:name="Read Unprocessed Changes">
        <db:sql><![CDATA[SELECT id, table_name, record_id, operation, old_values, new_values, changed_at
FROM change_log
WHERE processed = FALSE
ORDER BY id ASC
LIMIT 500]]></db:sql>
    </db:select>

    <choice doc:name="Has Changes?">
        <when expression="#[sizeOf(payload) > 0]">
            <set-variable variableName="changeIds"
                value="#[payload map $.id]" />

            <foreach doc:name="Process Each Change">
                <ee:transform doc:name="Map Change Event">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    eventId: payload.id,
    eventType: payload.operation,
    table: payload.table_name,
    recordId: payload.record_id,
    timestamp: payload.changed_at,
    before: if (payload.old_values != null) read(payload.old_values, "application/json") else null,
    after: if (payload.new_values != null) read(payload.new_values, "application/json") else null
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <anypoint-mq:publish config-ref="AnypointMQ_Config"
                    destination="order-change-events" />
            </foreach>

            <!-- Mark as processed -->
            <db:update config-ref="Database_Config" doc:name="Mark Processed">
                <db:sql><![CDATA[UPDATE change_log SET processed = TRUE WHERE id IN (:ids)]]></db:sql>
                <db:input-parameters><![CDATA[#[{ ids: vars.changeIds }]]]></db:input-parameters>
            </db:update>
        </when>
    </choice>
</flow>
```

#### Batch Processing for Large Change Sets

```xml
<flow name="database-cdc-batch-flow">
    <scheduler doc:name="Poll Every Minute">
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="SECONDS" />
        </scheduling-strategy>
    </scheduler>

    <os:retrieve key="orders_last_id"
        objectStore="CDC_Watermark_Store"
        doc:name="Get Last Processed ID">
        <os:default-value>0</os:default-value>
    </os:retrieve>

    <set-variable variableName="lastId" value="#[payload as Number]" />

    <db:select config-ref="Database_Config" doc:name="Select Changes by ID">
        <db:sql><![CDATA[SELECT id, customer_id, order_total, status, updated_at
FROM orders
WHERE id > :lastId
ORDER BY id ASC]]></db:sql>
        <db:input-parameters><![CDATA[#[{ lastId: vars.lastId }]]]></db:input-parameters>
    </db:select>

    <batch:job jobName="cdc-batch-sync"
        maxFailedRecords="50"
        blockSize="100">
        <batch:process-records>
            <batch:step name="transform-and-publish">
                <ee:transform doc:name="Build Event">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    eventType: "UPSERT",
    table: "orders",
    data: payload
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <http:request config-ref="Downstream_API"
                    method="PUT"
                    path="/api/orders/#[payload.data.id]" />
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <os:store key="orders_last_id"
                objectStore="CDC_Watermark_Store">
                <os:value><![CDATA[#[payload.lastProcessedId]]]></os:value>
            </os:store>
        </batch:on-complete>
    </batch:job>
</flow>
```

### How It Works

1. **Watermark tracking** — Object Store persists the last processed timestamp or ID across restarts. On each poll cycle, only records modified after the watermark are fetched
2. **Change detection** — Timestamp polling compares `updated_at` against the watermark. Trigger-based captures every INSERT/UPDATE/DELETE in a change log table. Transaction log reads the database's binary/redo log
3. **Event publishing** — Detected changes are transformed into standardized change events and published to a message queue (Anypoint MQ, JMS, Kafka) for downstream consumers
4. **Watermark advance** — The watermark is only updated after successful processing. If an error occurs, the next poll retries from the same position, ensuring at-least-once delivery
5. **Batch mode** — For high-volume tables, batch processing handles thousands of changes per cycle with configurable block sizes and failure thresholds

### Gotchas

- **Clock skew on timestamp polling** — If the application server and database server clocks are not synchronized, changes can be missed. Use the database server's clock (`NOW()` or `CURRENT_TIMESTAMP` in SQL) for watermarks, not MuleSoft's system clock
- **Missed deletes** — Timestamp-based polling cannot detect hard deletes because the row no longer exists. Use soft-delete patterns (set a `deleted_at` column) or switch to trigger-based CDC for delete capture
- **High-frequency polling overhead** — Polling every few seconds on a large table without a proper index on the watermark column causes full table scans. Ensure `updated_at` (or the watermark column) has a B-tree index
- **Duplicate processing** — Multiple records can share the same `updated_at` timestamp. If the batch limit splits records with identical timestamps, the watermark advances past some unprocessed rows. Mitigation: use a composite watermark (`updated_at` + `id`) or ensure `>= watermark` with dedup
- **Transaction visibility** — Long-running transactions may commit records with timestamps earlier than the current watermark. Use `READ COMMITTED` isolation and add a small overlap window (e.g., watermark minus 5 seconds) to catch late commits
- **Change log table growth** — Trigger-based CDC change log tables grow indefinitely. Schedule a purge job to delete processed records older than your retention window (e.g., 7 days)

### Related

- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — File-based change delivery with similar exactly-once semantics
- [SAP IDoc Processing](../sap-idoc-processing/) — Push-based change propagation as an alternative to polling
- [NetSuite Patterns](../netsuite-patterns/) — Saved search date filters for incremental data extraction from NetSuite
