## Vector Database Setup
> Configure a vector database connection for storing and querying embeddings.

### When to Use
- Building RAG pipelines that need semantic search
- Storing document embeddings for knowledge retrieval
- Similarity-based content recommendations

### Configuration / Code

```xml
<!-- Pinecone vector database connection -->
<http:request-config name="Pinecone_Config">
    <http:request-connection host="${pinecone.host}" protocol="HTTPS">
        <http:default-headers>
            <http:header key="Api-Key" value="${pinecone.api.key}"/>
            <http:header key="Content-Type" value="application/json"/>
        </http:default-headers>
    </http:request-connection>
</http:request-config>

<!-- Query similar vectors -->
<flow name="similarity-search">
    <http:request config-ref="Pinecone_Config" path="/query" method="POST">
        <http:body>#[output application/json --- {
            vector: vars.queryEmbedding,
            topK: 5,
            includeMetadata: true,
            namespace: "knowledge-base"
        }]</http:body>
    </http:request>
</flow>
```

### How It Works
1. Configure HTTP requester to connect to your vector database API
2. Store embeddings with metadata (source document, chunk ID, content)
3. Query by embedding vector to find semantically similar documents
4. `topK` controls how many similar results to return

### Gotchas
- Choose dimensions to match your embedding model (OpenAI = 1536 or 3072)
- Index configuration (metric: cosine vs euclidean) affects search quality
- Namespace isolation keeps different knowledge bases separate
- Vector databases charge by storage and queries — monitor usage

### Related
- [Embedding Generation](../../inference/embedding-generation/) — creating embeddings
- [Similarity Search](../similarity-search/) — search patterns
