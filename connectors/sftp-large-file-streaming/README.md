## SFTP Large File Streaming

> Processing 300MB+ files via SFTP without OutOfMemoryError using streaming strategies, batch processing, and watermark-based resumability.

### When to Use

- SFTP partner drops files larger than 100 MB that cause heap exhaustion on CloudHub
- Processing CSV, JSON, or XML files that contain millions of rows
- Current file processing loads the entire file into memory before transformation
- Need to resume processing after failure without re-reading the entire file

### The Problem

Mule 4 uses repeatable streams by default, which buffer the entire file content in memory (up to `maxInMemorySize`, then spills to disk). For a 500 MB CSV on a 0.5 vCore CloudHub worker with 500 MB heap, the application runs out of memory before the first record is processed. The solution is to disable repeatable streaming, use batch processing, and implement resumability for partial failures.

### Configuration

#### SFTP Connector with Streaming

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

<os:object-store name="File_Processing_Store"
    doc:name="File Processing Store"
    persistent="true"
    entryTtl="7"
    entryTtlUnit="DAYS"
    maxEntries="1000" />
```

#### Non-Repeatable Stream for Large Files

```xml
<flow name="sftp-large-file-stream-flow"
    maxConcurrency="1">
    <sftp:listener config-ref="SFTP_Config"
        doc:name="SFTP Listener"
        directory="${sftp.inbound.dir}"
        autoDelete="false"
        watermarkEnabled="true">
        <!-- Non-repeatable stream: read once, no memory buffering -->
        <non-repeatable-stream />
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="SECONDS" />
        </scheduling-strategy>
        <sftp:matcher
            filenamePattern="*.csv"
            notUpdatedInTheLast="60"
            notUpdatedInTheLast_timeUnit="SECONDS" />
    </sftp:listener>

    <set-variable variableName="fileName" value="#[attributes.fileName]" />
    <set-variable variableName="fileSize" value="#[attributes.size]" />
    <set-variable variableName="filePath"
        value="#[attributes.directory ++ '/' ++ attributes.fileName]" />

    <logger level="INFO"
        message="Starting large file processing: #[vars.fileName] (#[vars.fileSize] bytes)" />

    <!-- Move to processing directory first -->
    <sftp:move config-ref="SFTP_Config"
        doc:name="Claim File"
        sourcePath="#[vars.filePath]"
        targetPath="#['${sftp.processing.dir}/' ++ vars.fileName]"
        overwrite="false"
        createParentDirectories="true" />

    <!-- Re-read from processing dir with streaming -->
    <sftp:read config-ref="SFTP_Config"
        doc:name="Stream File"
        path="#['${sftp.processing.dir}/' ++ vars.fileName]">
        <non-repeatable-stream />
    </sftp:read>

    <!-- Process with batch -->
    <batch:job jobName="large-file-batch"
        blockSize="${batch.blockSize}"
        maxFailedRecords="${batch.maxFailed}">
        <batch:process-records>
            <batch:step name="validate-record">
                <ee:transform doc:name="Validate and Map">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.id,
    name: trim(payload.name default ""),
    email: lower(trim(payload.email default "")),
    amount: payload.amount as Number default 0,
    date: payload.date as Date {format: "MM/dd/yyyy"} default null,
    valid: (payload.id != null) and (payload.email contains "@")
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <validation:is-true
                    expression="#[payload.valid]"
                    message="Invalid record at row #[vars.batchItemIndex]" />
            </batch:step>

            <batch:step name="upsert-to-target"
                acceptPolicy="NO_FAILURES">
                <http:request config-ref="Target_API"
                    method="PUT"
                    path="#['/api/records/' ++ payload.id]"
                    responseTimeout="10000" />
            </batch:step>
        </batch:process-records>

        <batch:on-complete>
            <choice doc:name="Move Based on Result">
                <when expression="#[payload.failedRecords == 0]">
                    <sftp:move config-ref="SFTP_Config"
                        sourcePath="#['${sftp.processing.dir}/' ++ vars.fileName]"
                        targetPath="#['${sftp.done.dir}/' ++ vars.fileName]"
                        createParentDirectories="true" />

                    <logger level="INFO"
                        message="Large file complete: #[vars.fileName]. Records: #[payload.totalRecords], Success: #[payload.successfulRecords]" />
                </when>
                <otherwise>
                    <sftp:move config-ref="SFTP_Config"
                        sourcePath="#['${sftp.processing.dir}/' ++ vars.fileName]"
                        targetPath="#['${sftp.error.dir}/' ++ vars.fileName]"
                        createParentDirectories="true" />

                    <logger level="ERROR"
                        message="Large file had failures: #[vars.fileName]. Total: #[payload.totalRecords], Failed: #[payload.failedRecords]" />
                </otherwise>
            </choice>

            <!-- Store processing summary -->
            <os:store key="#[vars.fileName]"
                objectStore="File_Processing_Store">
                <os:value><![CDATA[#[output application/json --- {
                    fileName: vars.fileName,
                    fileSize: vars.fileSize,
                    totalRecords: payload.totalRecords,
                    successfulRecords: payload.successfulRecords,
                    failedRecords: payload.failedRecords,
                    processedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
                }]]]></os:value>
            </os:store>
        </batch:on-complete>
    </batch:job>

    <error-handler>
        <on-error-continue type="ANY">
            <logger level="ERROR"
                message="Fatal error processing #[vars.fileName]: #[error.description]" />
            <sftp:move config-ref="SFTP_Config"
                sourcePath="#['${sftp.processing.dir}/' ++ vars.fileName]"
                targetPath="#['${sftp.error.dir}/' ++ vars.fileName]"
                createParentDirectories="true" />
        </on-error-continue>
    </error-handler>
</flow>
```

#### File-Based Stream Strategy (Spill to Disk)

For cases where you need repeatable reads but cannot hold the file in memory:

```xml
<flow name="sftp-repeatable-file-stream-flow">
    <sftp:listener config-ref="SFTP_Config"
        doc:name="SFTP Listener"
        directory="${sftp.inbound.dir}"
        autoDelete="false"
        watermarkEnabled="true">
        <!-- Repeatable file stream: buffers to disk, not memory -->
        <repeatable-file-store-stream
            inMemorySize="512"
            bufferUnit="KB"
            maxInMemorySize="1"
            maxInMemorySizeUnit="MB" />
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="SECONDS" />
        </scheduling-strategy>
    </sftp:listener>

    <!-- Stream is now repeatable via temp files on disk -->
    <!-- First pass: count records -->
    <ee:transform doc:name="Count Records">
        <ee:message>
            <ee:set-variable variableName="recordCount">
                <![CDATA[%dw 2.0
output application/java
---
sizeOf(payload)]]>
            </ee:set-variable>
        </ee:message>
    </ee:transform>

    <logger level="INFO"
        message="File contains #[vars.recordCount] records" />

    <!-- Second pass: process (possible because stream is repeatable) -->
    <batch:job jobName="repeatable-file-batch"
        blockSize="500"
        maxFailedRecords="-1">
        <batch:process-records>
            <batch:step name="process">
                <ee:transform doc:name="Map Record">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </batch:step>
        </batch:process-records>
    </batch:job>
</flow>
```

#### Chunked Download for Very Large Files

```xml
<flow name="sftp-chunked-download-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sftp/download"
        allowedMethods="POST" />

    <!-- Read file metadata without loading content -->
    <sftp:list config-ref="SFTP_Config"
        doc:name="List Files"
        directoryPath="#[payload.directory]">
        <sftp:matcher filenamePattern="#[payload.filename]" />
    </sftp:list>

    <set-variable variableName="fileInfo" value="#[payload[0]]" />

    <logger level="INFO"
        message="Downloading #[vars.fileInfo.attributes.fileName] (#[vars.fileInfo.attributes.size] bytes)" />

    <!-- Stream directly to target without holding in memory -->
    <sftp:read config-ref="SFTP_Config"
        doc:name="Stream Read"
        path="#[vars.fileInfo.attributes.path]">
        <non-repeatable-stream />
    </sftp:read>

    <!-- Write directly to local filesystem or S3 -->
    <file:write config-ref="Local_File_Config"
        doc:name="Write to Local"
        path="#['${local.staging.dir}/' ++ vars.fileInfo.attributes.fileName]"
        mode="CREATE_NEW" />

    <ee:transform doc:name="Confirm">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "downloaded",
    fileName: vars.fileInfo.attributes.fileName,
    size: vars.fileInfo.attributes.size,
    localPath: "${local.staging.dir}/" ++ vars.fileInfo.attributes.fileName
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Estimate memory needed for file processing
fun estimateMemory(fileSizeBytes: Number, strategy: String): Object = do {
    var fileSizeMB = fileSizeBytes / (1024 * 1024)
    ---
    strategy match {
        case "non-repeatable" -> {
            peakMemoryMB: ceil(fileSizeMB * 0.1),
            description: "Only current batch block in memory"
        }
        case "repeatable-file" -> {
            peakMemoryMB: ceil(min([fileSizeMB, 1])),
            diskUsageMB: ceil(fileSizeMB),
            description: "Max 1MB in memory, rest on disk"
        }
        case "repeatable-in-memory" -> {
            peakMemoryMB: ceil(fileSizeMB * 1.3),
            description: "Entire file in heap (1.3x for object overhead)"
        }
        else -> { error: "Unknown strategy" }
    }
}

// Recommend streaming strategy based on file size and vCore
fun recommendStrategy(fileSizeMB: Number, vcores: Number): String = do {
    var heapMB = vcores * 500
    ---
    if (fileSizeMB < heapMB * 0.3) "repeatable-in-memory"
    else if (fileSizeMB < 2000) "repeatable-file"
    else "non-repeatable"
}
---
{
    "300MB_file": estimateMemory(300 * 1024 * 1024, "non-repeatable"),
    "recommendation": recommendStrategy(500, 1)
}
```

### Gotchas

- **`non-repeatable-stream` can only be read once** — If any processor in the flow reads the stream (even a logger with `#[payload]`), the stream is consumed and subsequent processors get an empty payload. Place the batch job immediately after the stream source
- **`maxConcurrency="1"` prevents parallel file processing** — If two large files arrive simultaneously, processing both in parallel doubles memory usage. Set `maxConcurrency="1"` on the flow to serialize large file processing
- **Batch `blockSize` determines memory footprint** — With `blockSize=500`, Mule holds 500 records in memory at a time. For records with many large text fields, reduce to 100-200. The formula is: `blockSize * avgRecordSizeKB < availableHeapMB * 0.2`
- **`notUpdatedInTheLast` prevents partial file pickup** — If a partner is still uploading a 500 MB file, the listener may pick it up mid-upload. Set `notUpdatedInTheLast` to at least 60 seconds (longer for very large files over slow connections)
- **Temp file cleanup** — `repeatable-file-store-stream` creates temporary files in the system temp directory. If processing fails without proper error handling, these temp files accumulate. Monitor `/tmp` disk usage on CloudHub workers
- **CSV parsing and streaming** — Mule's CSV reader supports streaming natively. JSON and XML readers do NOT stream by default; they parse the entire document into memory. For large JSON arrays, use `streaming="true"` in the DataWeave reader: `application/json {streaming: true}`
- **CloudHub disk space** — CloudHub workers have limited disk space (varies by worker size). `repeatable-file-store-stream` for a 2 GB file requires 2 GB of free disk. If disk runs out, you get `IOException` instead of the expected `OutOfMemoryError`

### Testing

```xml
<munit:test name="sftp-large-file-success-test"
    description="Verify large file processes without OOM">

    <munit:behavior>
        <munit-tools:mock-when processor="sftp:move">
            <munit-tools:then-return>
                <munit-tools:payload value="#[null]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
        <munit-tools:mock-when processor="sftp:read">
            <munit-tools:then-return>
                <munit-tools:payload value="#[readUrl('classpath://test-large-file.csv')]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{status: 'ok'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="fileName" value="test-large.csv" />
        <set-variable variableName="fileSize" value="314572800" />
        <flow-ref name="sftp-large-file-stream-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="sftp:move"
            times="2" />
    </munit:validation>
</munit:test>
```

### Related

- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — Standard-size file processing with delivery guarantees
- [DB Bulk Insert Performance](../db-bulk-insert-performance/) — Efficient database loading for records extracted from large files
