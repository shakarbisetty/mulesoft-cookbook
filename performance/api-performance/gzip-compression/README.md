## GZIP Response Compression
> Compress API responses to reduce bandwidth by 40-70%.

### When to Use
- JSON/XML APIs with verbose response payloads
- Mobile or bandwidth-constrained clients
- Reducing CloudHub egress costs

### Configuration / Code

```xml
<http:listener-config name="HTTP_Listener">
    <http:listener-connection host="0.0.0.0" port="${http.port}"/>
</http:listener-config>

<flow name="compressed-api-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/data"/>
    <flow-ref name="get-data"/>
    <choice>
        <when expression="#[attributes.headers.accept-encoding contains gzip]">
            <compression:compress xmlns:compression="http://www.mulesoft.org/schema/mule/compression">
                <compression:compressor>
                    <compression:gzip-compressor/>
                </compression:compressor>
            </compression:compress>
            <set-variable variableName="outboundHeaders"
                          value="#[{Content-Encoding: gzip}]"/>
        </when>
    </choice>
</flow>
```

### How It Works
1. Check if client sends `Accept-Encoding: gzip` header
2. Compress the response payload using the compression module
3. Set `Content-Encoding: gzip` response header
4. Client decompresses transparently

### Gotchas
- Compression uses CPU — do not compress small payloads (< 1 KB) or binary data (images, PDFs)
- Add the compression module dependency to your pom.xml
- Some clients do not support gzip — always check the `Accept-Encoding` header
- Flex Gateway can handle compression at the gateway level instead

### Related
- [Content Negotiation](../content-negotiation/) — format negotiation
- [Streaming strategies](../../streaming/repeatable-file-store/) — large payload handling
