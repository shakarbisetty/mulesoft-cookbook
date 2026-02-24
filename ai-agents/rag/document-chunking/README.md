## Document Chunking Strategies
> Split documents into optimal chunks for embedding and retrieval.

### When to Use
- Processing long documents for RAG pipelines
- Optimizing chunk size for retrieval quality
- Handling different document formats (PDF, HTML, plain text)

### Configuration / Code

```xml
<flow name="chunk-document">
    <http:listener config-ref="HTTP_Listener" path="/ingest" method="POST"/>
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json

var text = payload.content
var chunkSize = 500
var overlap = 50

fun chunkText(t, size, ovlp) =
    if (sizeOf(t) <= size) [t]
    else [t[0 to size-1]] ++ chunkText(t[(size - ovlp) to -1], size, ovlp)
---
{
    chunks: chunkText(text, chunkSize, overlap) map {
        id: uuid(),
        content: $,
        metadata: {
            source: payload.filename,
            chunkIndex: $$,
            totalChunks: sizeOf(chunkText(text, chunkSize, overlap))
        }
    }
}]]></ee:set-payload></ee:message>
    </ee:transform>
    <foreach collection="#[payload.chunks]">
        <flow-ref name="generate-and-store-embedding"/>
    </foreach>
</flow>
```

### How It Works
1. Document text is split into fixed-size chunks with overlap
2. Overlap ensures context is not lost at chunk boundaries
3. Each chunk gets metadata (source, position) for traceability
4. Chunks are individually embedded and stored in the vector database

### Gotchas
- Chunk size affects retrieval quality: too small = missing context, too large = noise
- Overlap should be 10-20% of chunk size for good boundary handling
- Respect sentence/paragraph boundaries when possible (not mid-word splits)
- Different document types need different chunking strategies

### Related
- [Vectors Setup](../vectors-setup/) — storing chunks
- [Similarity Search](../similarity-search/) — querying chunks
