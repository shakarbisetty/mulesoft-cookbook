## SFTP Guaranteed Delivery

> SFTP file transfers with exactly-once delivery guarantee using watermark tracking, idempotent filtering, and move-after-process patterns.

### When to Use

- Processing files from trading partners or legacy systems that drop files on SFTP
- Requiring exactly-once processing guarantees for financial data, payroll, or inventory files
- Building file-based integrations where re-processing the same file would cause duplicates
- Replacing manual SFTP-based workflows with automated pickup, transform, and delivery

### Configuration

#### SFTP Connector Config

```xml
<sftp:config name="SFTP_Config" doc:name="SFTP Config">
    <sftp:connection
        host="${sftp.host}"
        port="${sftp.port}"
        username="${sftp.username}"
        workingDir="${sftp.baseDir}">
        <sftp:authentication>
            <sftp:key-based-authentication
                keyFile="${sftp.privateKeyPath}"
                passphrase="${sftp.keyPassphrase}" />
        </sftp:authentication>
    </sftp:connection>
</sftp:config>
```

#### SFTP Listener with Move-After-Process

```xml
<os:object-store name="SFTP_Idempotent_Store"
    doc:name="SFTP Idempotent Store"
    persistent="true"
    entryTtl="30"
    entryTtlUnit="DAYS"
    maxEntries="10000" />

<flow name="sftp-guaranteed-delivery-flow">
    <sftp:listener config-ref="SFTP_Config"
        doc:name="SFTP Listener"
        directory="${sftp.inbound.dir}"
        autoDelete="false"
        moveToDirectory="${sftp.processing.dir}"
        watermarkEnabled="true"
        timeBetweenSizeCheck="5"
        timeBetweenSizeCheckUnit="SECONDS">
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS" />
        </scheduling-strategy>
        <sftp:matcher
            filenamePattern="*.csv"
            notUpdatedInTheLast="10"
            notUpdatedInTheLast_timeUnit="SECONDS" />
    </sftp:listener>

    <!-- Idempotent filter: skip already-processed files -->
    <idempotent-message-validator
        doc:name="Idempotent Filter"
        idExpression="#[attributes.fileName ++ '-' ++ attributes.size ++ '-' ++ attributes.timestamp]"
        objectStore="SFTP_Idempotent_Store" />

    <logger level="INFO"
        message="Processing file: #[attributes.fileName] (size: #[attributes.size] bytes)" />

    <try doc:name="Process with Guaranteed Delivery">
        <!-- Transform file content -->
        <ee:transform doc:name="CSV to JSON">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
var records = payload
---
{
    fileName: attributes.fileName,
    processedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    recordCount: sizeOf(records),
    records: records map {
        id: $.id,
        ($ - "id")
    }
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Deliver to downstream system -->
        <http:request config-ref="Downstream_API"
            method="POST"
            path="/api/ingest">
            <http:response-validator>
                <http:success-status-code-validator values="200..299" />
            </http:response-validator>
        </http:request>

        <!-- Move to done directory on success -->
        <sftp:move config-ref="SFTP_Config"
            doc:name="Move to Done"
            sourcePath="#[vars.processingDir ++ '/' ++ attributes.fileName]"
            targetPath="#[vars.doneDir ++ '/' ++ attributes.fileName]"
            overwrite="false"
            createParentDirectories="true" />

        <logger level="INFO"
            message="File processed successfully: #[attributes.fileName] -> done/" />

        <error-handler>
            <on-error-propagate type="ANY">
                <!-- Move to error directory on failure -->
                <sftp:move config-ref="SFTP_Config"
                    doc:name="Move to Error"
                    sourcePath="#[vars.processingDir ++ '/' ++ attributes.fileName]"
                    targetPath="#[vars.errorDir ++ '/' ++ attributes.fileName]"
                    overwrite="false"
                    createParentDirectories="true" />

                <logger level="ERROR"
                    message="File processing failed: #[attributes.fileName] -> error/ : #[error.description]" />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Directory Structure Pattern

```
/sftp-root/
  /inbound/          ← Partner drops files here
  /processing/       ← MuleSoft moves files here during processing
  /done/             ← Successfully processed files
  /error/            ← Failed files for manual review
```

#### Large File Streaming

```xml
<flow name="sftp-large-file-streaming-flow">
    <sftp:listener config-ref="SFTP_Config"
        doc:name="SFTP Listener"
        directory="${sftp.inbound.dir}"
        autoDelete="false"
        watermarkEnabled="true">
        <non-repeatable-stream />
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="SECONDS" />
        </scheduling-strategy>
        <sftp:matcher
            filenamePattern="*.csv"
            notUpdatedInTheLast="30"
            notUpdatedInTheLast_timeUnit="SECONDS" />
    </sftp:listener>

    <batch:job jobName="large-file-batch"
        blockSize="500"
        maxFailedRecords="100">
        <batch:process-records>
            <batch:step name="process-records">
                <ee:transform doc:name="Map Record">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <http:request config-ref="Downstream_API"
                    method="POST"
                    path="/api/records" />
            </batch:step>
        </batch:process-records>
        <batch:on-complete>
            <choice>
                <when expression="#[payload.failedRecords == 0]">
                    <sftp:move config-ref="SFTP_Config"
                        sourcePath="#[vars.filePath]"
                        targetPath="#[vars.doneDir ++ '/' ++ vars.fileName]" />
                </when>
                <otherwise>
                    <sftp:move config-ref="SFTP_Config"
                        sourcePath="#[vars.filePath]"
                        targetPath="#[vars.errorDir ++ '/' ++ vars.fileName]" />
                </otherwise>
            </choice>
        </batch:on-complete>
    </batch:job>
</flow>
```

#### Idempotent Filter with Custom Key

```xml
<!-- For files where name is not unique (e.g., same name arrives daily) -->
<idempotent-message-validator
    doc:name="Content-Based Idempotent Filter"
    idExpression="#[
        import dw::Crypto
        Crypto::hashWith(payload, 'SHA-256')
    ]"
    objectStore="SFTP_Idempotent_Store" />
```

### How It Works

1. **SFTP listener polls** — The listener checks the inbound directory on a fixed schedule. The `notUpdatedInTheLast` matcher ensures files are fully written before pickup (prevents partial file reads)
2. **Watermark tracking** — The listener's built-in watermark remembers the last file timestamp. Only files newer than the watermark are picked up, preventing re-processing across restarts
3. **Move to processing** — On pickup, the file is moved from `inbound/` to `processing/` atomically. This prevents other listeners or instances from picking up the same file
4. **Idempotent filter** — A secondary check uses Object Store to track processed file fingerprints (name + size + timestamp or content hash). If a file somehow bypasses the watermark, the idempotent filter blocks it
5. **Process and route** — The file content is transformed and delivered to the downstream system
6. **Move to done/error** — On success, the file moves to `done/`. On failure, it moves to `error/` for manual investigation. The file is never deleted until explicitly archived

### Gotchas

- **Partial file detection** — If a partner is uploading a large file while MuleSoft polls, the listener may pick up an incomplete file. Use `timeBetweenSizeCheck` to wait and verify the file size is stable before processing. Alternatively, use a partner convention: upload as `.tmp`, then rename to `.csv` when complete
- **File locking** — Not all SFTP servers support advisory locks. If multiple MuleSoft workers share the same SFTP source, use the `moveToDirectory` pattern to claim files atomically. The first worker to move the file wins; the second gets a "file not found" error (handle gracefully)
- **Network interruption mid-transfer** — If the connection drops during `sftp:move`, the file may exist in both source and target directories (or neither). Implement a reconciliation flow that scans `processing/` for stuck files older than a threshold and re-queues them
- **Filename collisions** — If the same filename arrives in `done/` multiple times, `overwrite="false"` will fail. Append a timestamp to the filename: `#[attributes.fileName ++ '.' ++ now() as String {format: "yyyyMMddHHmmss"}]`
- **Object Store TTL** — The idempotent store's `entryTtl` must be longer than the maximum time between duplicate file deliveries. Set it too short and duplicates slip through; set it too long and storage grows
- **SFTP connection exhaustion** — Each listener, move, and read operation opens a connection. On high-volume flows, the SFTP server may reject connections. Configure connection pooling on the SFTP connector and limit concurrent file processing

### Related

- [Database CDC](../database-cdc/) — For database-based change delivery instead of file-based
- [AS2 Exchange](../as2-exchange/) — Alternative B2B file exchange protocol with built-in delivery receipts
- [EDI Processing](../edi-processing/) — Often used together: SFTP delivers the EDI file, then EDI module parses it
