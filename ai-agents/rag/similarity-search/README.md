## Similarity Search for RAG
> Query vector database to find the most relevant context for LLM prompts.

### When to Use
- RAG pipeline: retrieve context before generating answers
- Knowledge base Q&A where the answer is in stored documents
- Contextual search that understands meaning, not just keywords

### Configuration / Code

```xml
<flow name="rag-query">
    <http:listener config-ref="HTTP_Listener" path="/ask" method="POST"/>
    <!-- Generate embedding for the question -->
    <flow-ref name="generate-embedding"/>
    <!-- Search for similar chunks -->
    <http:request config-ref="Pinecone_Config" path="/query" method="POST">
        <http:body>#[output application/json --- {
            vector: vars.questionEmbedding,
            topK: 3,
            includeMetadata: true
        }]</http:body>
    </http:request>
    <!-- Build context from results -->
    <set-variable variableName="context"
                  value="#[payload.matches map $.metadata.content joinBy '\n---\n']"/>
    <set-variable variableName="sources"
                  value="#[payload.matches map {title: $.metadata.title, score: $.score}]"/>
    <!-- Send to LLM with context -->
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="Answer based on the following context only. If the answer is not in the context, say 'I don't have enough information to answer that.' Cite which source you used."/>
            <ai:message role="user" content="#['Context:\n' ++ vars.context ++ '\n\nQuestion: ' ++ vars.originalQuestion]"/>
        </ai:messages>
        <ai:config temperature="0.2" maxTokens="500"/>
    </ai:chat-completions>
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    answer: payload.choices[0].message.content,
    sources: vars.sources,
    tokensUsed: payload.usage.total_tokens
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>

<sub-flow name="generate-embedding">
    <set-variable variableName="originalQuestion" value="#[payload.question]"/>
    <http:request config-ref="OpenAI_Config" path="/v1/embeddings" method="POST">
        <http:body>#[output application/json --- {
            model: "text-embedding-3-small",
            input: payload.question
        }]</http:body>
    </http:request>
    <set-variable variableName="questionEmbedding" value="#[payload.data[0].embedding]"/>
</sub-flow>
```

### How It Works
1. User sends a question via POST to `/ask`
2. The question is converted to a vector embedding using OpenAI's embedding model
3. Pinecone (or any vector DB) receives the embedding and returns top 3 similar document chunks
4. Matching chunks are joined with `---` separators to form the context string
5. Source metadata (title, similarity score) is captured for attribution
6. The LLM receives a system prompt instructing it to only use the provided context
7. Response includes the answer, source citations, and token usage for cost tracking

### Gotchas
- Use the same embedding model for indexing and querying — mismatched models give poor results
- `topK: 3` is a good starting point — more chunks give better recall but increase token costs
- Set similarity score threshold (e.g., > 0.7) — low-score matches add noise, not relevance
- `text-embedding-3-small` is 5x cheaper than `3-large` with only ~2% accuracy difference
- Monitor context size — 3 chunks of 500 tokens each = 1,500 context tokens per query

### Related
- [Document Chunking](../document-chunking/) — preparing documents for vector storage
- [Vectors Setup](../vectors-setup/) — configuring vector database connections
- [Salesforce Knowledge RAG](../salesforce-knowledge-rag/) — RAG with Salesforce data
