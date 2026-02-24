## Embedding Generation
> Generate vector embeddings from text for similarity search and RAG pipelines.

### When to Use
- Building RAG (Retrieval-Augmented Generation) systems
- Semantic search across documents or knowledge bases
- Text similarity comparisons (duplicate detection, clustering)

### Configuration / Code

```xml
<flow name="generate-embedding">
    <http:listener config-ref="HTTP_Listener" path="/embed" method="POST"/>
    <http:request config-ref="OpenAI_Config" path="/v1/embeddings" method="POST">
        <http:body>#[output application/json --- {
            model: "text-embedding-3-small",
            input: payload.text
        }]</http:body>
    </http:request>
    <set-variable variableName="embedding" value="#[payload.data[0].embedding]"/>
    <!-- Store in vector database -->
    <http:request config-ref="Pinecone_Config" path="/vectors/upsert" method="POST">
        <http:body>#[output application/json --- {
            vectors: [{id: vars.docId, values: vars.embedding, metadata: {source: vars.source}}]
        }]</http:body>
    </http:request>
</flow>
```

### How It Works
1. Text is sent to an embedding model (OpenAI, Cohere, etc.)
2. Model returns a fixed-dimension vector (e.g., 1536 dimensions)
3. Vector is stored in a vector database (Pinecone, Weaviate, Chroma)
4. Similar texts have vectors that are close in the embedding space

### Gotchas
- Embedding model and search model must match (same model for indexing and querying)
- Long texts need chunking before embedding (most models have token limits)
- Embedding dimensions affect storage and search performance
- Re-embedding is needed if you change the model — vectors are not transferable

### Related
- [Vectors Setup](../../rag/vectors-setup/) — vector database configuration
- [Document Chunking](../../rag/document-chunking/) — text splitting strategies
