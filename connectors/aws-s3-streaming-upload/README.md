## AWS S3 Streaming Upload

> S3 multipart upload with streaming for large files, presigned URL generation, and cross-region replication patterns for Mule 4.

### When to Use

- Uploading files larger than 100 MB to S3 from MuleSoft without loading the entire file in memory
- Generating presigned URLs for partners to upload/download files directly to S3, bypassing MuleSoft as a proxy
- Building a file archival pipeline that moves processed files from SFTP or local storage to S3
- Need cross-account or cross-region S3 operations with proper IAM role assumption

### The Problem

The MuleSoft Amazon S3 connector's `putObject` operation loads the entire file content into memory before uploading. For files over 100 MB on CloudHub workers with limited heap, this causes `OutOfMemoryError`. S3's multipart upload API splits large files into parts and uploads them in parallel, but the connector does not expose multipart upload directly. You must use the connector's streaming support or fall back to the AWS SDK via HTTP requests.

### Configuration

#### AWS S3 Connector Config

```xml
<s3:config name="Amazon_S3_Config" doc:name="Amazon S3 Config">
    <s3:basic-connection
        accessKey="${aws.accessKey}"
        secretKey="${aws.secretKey}"
        region="${aws.region}" />
</s3:config>

<!-- For CloudHub with IAM roles (no static credentials) -->
<s3:config name="Amazon_S3_IAM_Config" doc:name="Amazon S3 IAM Config">
    <s3:role-connection
        roleARN="${aws.roleArn}"
        region="${aws.region}" />
</s3:config>
```

#### Standard Upload with Streaming

```xml
<flow name="s3-upload-standard-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/s3/upload"
        allowedMethods="POST" />

    <set-variable variableName="fileName"
        value="#[attributes.headers.'x-file-name' default 'upload-' ++ uuid() ++ '.dat']" />
    <set-variable variableName="contentType"
        value="#[attributes.headers.'Content-Type' default 'application/octet-stream']" />

    <s3:put-object config-ref="Amazon_S3_Config"
        doc:name="Upload to S3"
        bucketName="${s3.bucket}"
        key="#['uploads/' ++ vars.fileName]"
        contentType="#[vars.contentType]" />

    <ee:transform doc:name="Upload Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "uploaded",
    bucket: p('s3.bucket'),
    key: "uploads/" ++ vars.fileName,
    s3Uri: "s3://$(p('s3.bucket'))/uploads/$(vars.fileName)",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Multipart Upload via HTTP (for files > 100 MB)

```xml
<http:request-config name="AWS_S3_HTTP_Config"
    doc:name="AWS S3 HTTP Config">
    <http:request-connection
        host="${s3.bucket}.s3.${aws.region}.amazonaws.com"
        port="443"
        protocol="HTTPS" />
</http:request-config>

<flow name="s3-multipart-upload-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/s3/multipart-upload"
        allowedMethods="POST" />

    <set-variable variableName="s3Key"
        value="#['large-uploads/' ++ attributes.headers.'x-file-name']" />
    <set-variable variableName="fileContent" value="#[payload]" />

    <!-- Step 1: Initiate multipart upload -->
    <http:request config-ref="AWS_S3_HTTP_Config"
        method="POST"
        path="#['/' ++ vars.s3Key ++ '?uploads']">
        <http:headers><![CDATA[#[output application/java --- {
            "x-amz-content-sha256": "UNSIGNED-PAYLOAD",
            "x-amz-date": now() as String {format: "yyyyMMdd'T'HHmmss'Z'"}
        }]]]></http:headers>
    </http:request>

    <set-variable variableName="uploadId"
        value="#[payload.InitiateMultipartUploadResult.UploadId]" />

    <!-- Step 2: Split into 10 MB parts and upload -->
    <ee:transform doc:name="Split into Parts">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
var partSize = 10 * 1024 * 1024
var content = vars.fileContent as Binary
var totalSize = sizeOf(content)
var partCount = ceil(totalSize / partSize)
---
(1 to partCount) map {
    partNumber: $,
    startByte: ($ - 1) * partSize,
    endByte: min([$ * partSize, totalSize])
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="etags" value="#[[]]" />

    <foreach doc:name="Upload Parts">
        <http:request config-ref="AWS_S3_HTTP_Config"
            method="PUT"
            path="#['/' ++ vars.s3Key]">
            <http:headers><![CDATA[#[output application/java --- {
                "Content-Type": "application/octet-stream"
            }]]]></http:headers>
            <http:query-params><![CDATA[#[output application/java --- {
                partNumber: payload.partNumber as String,
                uploadId: vars.uploadId
            }]]]></http:query-params>
        </http:request>

        <set-variable variableName="etags"
            value="#[vars.etags ++ [{
                partNumber: payload.partNumber,
                etag: attributes.headers.ETag
            }]]" />
    </foreach>

    <!-- Step 3: Complete multipart upload -->
    <ee:transform doc:name="Build Complete Request">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/xml
---
{
    CompleteMultipartUpload: {
        (vars.etags orderBy $.partNumber map {
            Part: {
                PartNumber: $.partNumber,
                ETag: $.etag
            }
        })
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request config-ref="AWS_S3_HTTP_Config"
        method="POST"
        path="#['/' ++ vars.s3Key]">
        <http:query-params><![CDATA[#[output application/java --- {
            uploadId: vars.uploadId
        }]]]></http:query-params>
    </http:request>

    <ee:transform doc:name="Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "completed",
    bucket: p('s3.bucket'),
    key: vars.s3Key,
    uploadId: vars.uploadId,
    parts: sizeOf(vars.etags)
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <error-handler>
        <on-error-propagate type="ANY">
            <!-- Abort multipart upload on failure to avoid orphaned parts -->
            <http:request config-ref="AWS_S3_HTTP_Config"
                method="DELETE"
                path="#['/' ++ vars.s3Key]">
                <http:query-params><![CDATA[#[output application/java --- {
                    uploadId: vars.uploadId
                }]]]></http:query-params>
            </http:request>
            <logger level="ERROR"
                message="Multipart upload aborted for #[vars.s3Key]: #[error.description]" />
        </on-error-propagate>
    </error-handler>
</flow>
```

#### Presigned URL Generation

```xml
<flow name="s3-presigned-url-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/s3/presigned-url"
        allowedMethods="POST" />

    <s3:create-presigned-url config-ref="Amazon_S3_Config"
        doc:name="Generate Presigned URL"
        bucketName="${s3.bucket}"
        key="#[payload.key]"
        method="#[payload.method default 'GET']"
        expiration="${s3.presigned.expirationMinutes}" />

    <ee:transform doc:name="Presigned URL Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    presignedUrl: payload,
    key: vars.originalPayload.key,
    method: vars.originalPayload.method default "GET",
    expiresInMinutes: p('s3.presigned.expirationMinutes') as Number,
    expiresAt: (now() + ("PT" ++ p('s3.presigned.expirationMinutes') ++ "M"))
        as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### SFTP to S3 Archival Pipeline

```xml
<flow name="sftp-to-s3-archive-flow">
    <sftp:listener config-ref="SFTP_Config"
        doc:name="SFTP Listener"
        directory="${sftp.archive.dir}"
        autoDelete="false"
        watermarkEnabled="true">
        <non-repeatable-stream />
        <scheduling-strategy>
            <fixed-frequency frequency="60" timeUnit="SECONDS" />
        </scheduling-strategy>
    </sftp:listener>

    <set-variable variableName="s3Key"
        value="#['archive/' ++ now() as String {format: 'yyyy/MM/dd'} ++ '/' ++ attributes.fileName]" />

    <s3:put-object config-ref="Amazon_S3_Config"
        doc:name="Archive to S3"
        bucketName="${s3.archive.bucket}"
        key="#[vars.s3Key]"
        contentType="application/octet-stream" />

    <sftp:delete config-ref="SFTP_Config"
        path="#[attributes.directory ++ '/' ++ attributes.fileName]" />

    <logger level="INFO"
        message="Archived #[attributes.fileName] to s3://${s3.archive.bucket}/#[vars.s3Key]" />
</flow>
```

### DataWeave Helper

```dataweave
%dw 2.0
output application/json

// Build S3 key with date-based partitioning
fun buildS3Key(prefix: String, fileName: String, partitionBy: String = "daily"): String =
    prefix ++ "/" ++ (
        partitionBy match {
            case "daily" -> now() as String {format: "yyyy/MM/dd"}
            case "hourly" -> now() as String {format: "yyyy/MM/dd/HH"}
            case "monthly" -> now() as String {format: "yyyy/MM"}
            else -> now() as String {format: "yyyy/MM/dd"}
        }
    ) ++ "/" ++ fileName

// Calculate multipart upload part count
fun partCount(fileSizeBytes: Number, partSizeMB: Number = 10): Number =
    ceil(fileSizeBytes / (partSizeMB * 1024 * 1024))
---
{
    exampleKey: buildS3Key("archive", "orders.csv", "daily"),
    partsFor500MB: partCount(500 * 1024 * 1024)
}
```

### Gotchas

- **Multipart upload minimum part size** — S3 requires each part (except the last) to be at least 5 MB. Parts smaller than 5 MB cause `EntityTooSmall` errors on `CompleteMultipartUpload`. Set your part size to 10 MB minimum
- **Orphaned multipart parts** — If a multipart upload is initiated but never completed or aborted, the uploaded parts remain in S3 and you are billed for storage. Configure an S3 lifecycle rule to abort incomplete multipart uploads after 7 days: `AbortIncompleteMultipartUpload` with `DaysAfterInitiation: 7`
- **S3 request signing** — Direct HTTP requests to S3 require AWS Signature V4. The MuleSoft S3 connector handles this automatically, but if you use raw `http:request`, you must implement SigV4 signing yourself (complex and error-prone). Prefer the connector for standard operations
- **CloudHub and S3 regions** — CloudHub workers in `us-east-1` can access S3 buckets in the same region with minimal latency. Cross-region access adds 50-200ms per request. Place your S3 bucket in the same region as your CloudHub workers
- **Presigned URL security** — Presigned URLs grant access to anyone who has the URL. Set short expiration times (5-15 minutes for uploads, 1 hour for downloads). Never log presigned URLs
- **S3 eventual consistency** — S3 now provides strong read-after-write consistency for PUT and DELETE operations (since December 2020). However, listing operations may still show stale results for a few seconds after writes

### Testing

```xml
<munit:test name="s3-upload-test"
    description="Verify file upload to S3">

    <munit:behavior>
        <munit-tools:mock-when processor="s3:put-object">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{etag: '\"abc123\"'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="fileName" value="test-file.csv" />
        <set-variable variableName="contentType" value="text/csv" />
        <set-payload value="#['test,data,here']" />
        <flow-ref name="s3-upload-standard-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('uploaded')]" />
    </munit:validation>
</munit:test>
```

### Related

- [SFTP Large File Streaming](../sftp-large-file-streaming/) — Streaming large files from SFTP before uploading to S3
- [AWS SQS Reliable Consumer](../aws-sqs-reliable-consumer/) — S3 event notifications consumed via SQS
