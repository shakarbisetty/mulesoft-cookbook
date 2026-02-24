## Anypoint MQ Large Payload
> Working around the 10MB message size limit with claim check, S3 references, and compression

### When to Use
- Payloads exceed Anypoint MQ's 10 MB limit (batch files, images, PDFs, large JSON/XML)
- Payloads are 1–10 MB and you want to reduce MQ costs (billed per message size)
- You need to pass binary data through a message queue
- High-volume flows where message size directly impacts throughput and cost

### Configuration / Code

#### Pattern 1: Claim Check with S3

The producer stores the payload in S3 and publishes a lightweight reference message. The consumer downloads from S3 using the reference.

**Producer — Store and Publish Reference:**
```xml
<flow name="large-payload-producer">
    <!-- Incoming large payload -->
    <set-variable variableName="payloadKey"
        value="#['messages/' ++ uuid() ++ '.json']" />
    <set-variable variableName="payloadSize"
        value="#[sizeOf(write(payload, 'application/json'))]" />

    <!-- Store payload in S3 -->
    <s3:put-object
        config-ref="Amazon_S3_Config"
        bucketName="${s3.bucket}"
        key="#[vars.payloadKey]"
        contentType="application/json">
        <s3:content>#[write(payload, "application/json")]</s3:content>
    </s3:put-object>

    <!-- Generate presigned URL (1 hour expiration) -->
    <s3:generate-presigned-url
        config-ref="Amazon_S3_Config"
        bucketName="${s3.bucket}"
        key="#[vars.payloadKey]"
        method="GET"
        expirationInSeconds="3600"
        target="presignedUrl" />

    <!-- Publish lightweight reference to MQ -->
    <anypoint-mq:publish
        config-ref="Anypoint_MQ_Config"
        destination="large-payload-queue">
        <anypoint-mq:message>
            <anypoint-mq:body><![CDATA[#[output application/json ---
{
    type: "claim-check",
    bucket: p('s3.bucket'),
    key: vars.payloadKey,
    presignedUrl: vars.presignedUrl,
    originalSizeBytes: vars.payloadSize,
    createdAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]]></anypoint-mq:body>
            <anypoint-mq:properties>
                <anypoint-mq:property key="pattern" value="claim-check" />
                <anypoint-mq:property key="originalSizeBytes"
                    value="#[vars.payloadSize as String]" />
            </anypoint-mq:properties>
        </anypoint-mq:message>
    </anypoint-mq:publish>

    <logger level="INFO"
        message="Published claim check: #[vars.payloadKey] (#[vars.payloadSize] bytes)" />
</flow>
```

**Consumer — Download and Process:**
```xml
<flow name="large-payload-consumer">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="large-payload-queue"
        acknowledgementMode="MANUAL" />

    <set-variable variableName="claimCheck"
        value="#[payload]" />

    <!-- Download payload from S3 -->
    <s3:get-object
        config-ref="Amazon_S3_Config"
        bucketName="#[vars.claimCheck.bucket]"
        key="#[vars.claimCheck.key]"
        target="originalPayload" />

    <try>
        <!-- Process the full payload -->
        <set-payload value="#[vars.originalPayload]" />
        <flow-ref name="process-large-payload" />

        <!-- Clean up S3 after successful processing -->
        <s3:delete-object
            config-ref="Amazon_S3_Config"
            bucketName="#[vars.claimCheck.bucket]"
            key="#[vars.claimCheck.key]" />

        <anypoint-mq:ack />

        <error-handler>
            <on-error-propagate>
                <logger level="ERROR"
                    message="Failed processing claim check #[vars.claimCheck.key]: #[error.description]" />
                <!-- Do NOT delete S3 object on failure — needed for retry -->
                <anypoint-mq:nack />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Pattern 2: Compression Before Publish

For payloads in the 1–10 MB range, gzip compression can reduce size by 5–15x, bringing them well under the limit.

```xml
<flow name="compressed-payload-producer">
    <set-variable variableName="originalSize"
        value="#[sizeOf(write(payload, 'application/json'))]" />

    <!-- Compress payload with gzip -->
    <gzip-compress xmlns="http://www.mulesoft.org/schema/mule/compression"
        doc:name="Gzip compress">
        <gzip-compressor />
        <content>#[write(payload, "application/json")]</content>
    </gzip-compress>

    <set-variable variableName="compressedSize"
        value="#[sizeOf(payload)]" />

    <logger level="INFO"
        message="Compression: #[vars.originalSize] → #[vars.compressedSize] bytes (#[(1 - vars.compressedSize / vars.originalSize) * 100 as String {format: '#.0'}]% reduction)" />

    <!-- Publish compressed payload -->
    <anypoint-mq:publish
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue">
        <anypoint-mq:message>
            <anypoint-mq:body>#[payload]</anypoint-mq:body>
            <anypoint-mq:properties>
                <anypoint-mq:property key="content-encoding" value="gzip" />
                <anypoint-mq:property key="original-size"
                    value="#[vars.originalSize as String]" />
            </anypoint-mq:properties>
        </anypoint-mq:message>
    </anypoint-mq:publish>
</flow>

<flow name="compressed-payload-consumer">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue"
        acknowledgementMode="MANUAL" />

    <!-- Check if compressed -->
    <choice>
        <when expression="#[attributes.properties['content-encoding'] == 'gzip']">
            <gzip-decompress xmlns="http://www.mulesoft.org/schema/mule/compression"
                doc:name="Gzip decompress">
                <gzip-decompressor />
                <content>#[payload]</content>
            </gzip-decompress>
            <set-payload value="#[read(payload, 'application/json')]" />
        </when>
    </choice>

    <!-- Process normally -->
    <flow-ref name="process-order" />
    <anypoint-mq:ack />
</flow>
```

#### Pattern Comparison

| Criteria | Claim Check (S3) | Compression (gzip) |
|----------|------------------|---------------------|
| **Max payload** | Unlimited (S3 limit: 5 TB) | ~100 MB pre-compression (10 MB post) |
| **Typical size reduction** | Reference is ~200 bytes | 5–15x for JSON/XML |
| **Latency overhead** | +50–200ms (S3 round-trip) | +5–20ms (CPU) |
| **Additional infra** | S3 bucket + IAM | None |
| **Cost** | S3 storage + GET/PUT ($0.0004/1K requests) | Minimal CPU |
| **Binary data** | Yes | Only if compressible |
| **Consumer complexity** | Must handle S3 download + cleanup | Must handle decompression |
| **Failure mode** | S3 outage = consumer can't download | Corrupt gzip = decompression failure |
| **Best for** | >10 MB, binary, long-lived references | 1–10 MB text (JSON, XML, CSV) |

### How It Works

1. **Anypoint MQ 10 MB limit**: Anypoint MQ enforces a hard 10 MB limit per message. Messages exceeding this are rejected at publish time with an error. This limit includes the message body, properties, and headers.

2. **Claim Check pattern**: Instead of putting the payload in the message, you store it externally (S3, Azure Blob, database) and put a reference in the message. The consumer retrieves the payload using the reference. This is the Enterprise Integration Pattern called "Claim Check."

3. **Compression**: JSON and XML are highly compressible. A 50 MB JSON payload typically compresses to 3–5 MB with gzip. This keeps the message self-contained (no external storage) at the cost of CPU.

4. **Presigned URLs**: S3 presigned URLs let the consumer download without needing S3 credentials. The URL has a built-in expiration — set it longer than your max processing time plus retry window.

5. **S3 lifecycle**: Use S3 lifecycle rules to auto-delete objects after 7 days (matching MQ TTL). This prevents orphaned objects if messages expire before consumers process them.

6. **Hybrid approach**: For payloads of variable size, try compression first. If the compressed size still exceeds 10 MB, fall back to claim check.

### Gotchas
- **Presigned URL expiration**: If the consumer processes the message hours after publish (e.g., backlog), the presigned URL may have expired. Either: (a) use long-lived URLs (24h), (b) skip presigned URLs and give the consumer direct S3 access, or (c) store the bucket/key and let the consumer generate its own presigned URL.
- **Compression CPU overhead**: Gzip compression uses CPU. On CloudHub with 0.1 vCore workers, compressing a 50 MB payload can take several seconds and may trigger out-of-memory errors. Size your workers accordingly.
- **Binary message encoding**: Anypoint MQ messages are UTF-8 text by default. Compressed (binary) payloads must be Base64-encoded, which adds ~33% overhead. A 7.5 MB compressed payload becomes ~10 MB Base64-encoded, potentially exceeding the limit.
- **S3 cleanup on failure**: If the consumer fails processing, do NOT delete the S3 object — the message will be redelivered (or go to DLQ) and the next attempt needs the S3 object. Only delete after successful ACK.
- **Orphaned S3 objects**: If a message expires in MQ before being consumed, the S3 object is never cleaned up. Use S3 lifecycle policies to auto-delete objects after a retention period.
- **Cost at scale**: At 1M messages/day with claim check, you're making 2M S3 API calls (PUT + GET) costing ~$1/day. The S3 storage cost is negligible if you clean up. But if payloads are small enough to compress below 10 MB, skip S3 entirely.
- **No streaming**: Anypoint MQ loads the entire message into memory. Even with claim check, the consumer loads the entire S3 object into memory. For truly large files (>100 MB), use streaming with a repeatable file store on the consumer side.

### Related
- [Anypoint MQ vs Kafka — Honest Comparison](../anypoint-mq-vs-kafka-honest-comparison/) — Kafka's default 1 MB limit is even more restrictive
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) — failed large payloads in DLQ
- [Anypoint MQ Circuit Breaker](../anypoint-mq-circuit-breaker/) — circuit break when S3 is down
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) — VM queues have no message size limit (memory-bound)
