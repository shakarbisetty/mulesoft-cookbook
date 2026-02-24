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
                  value="#[payload.matches map $.metadata.content joinBy n---n]"/>
    <!-- Send to LLM with context -->
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="Answer based on the following context. If the answer is not in the context, say so."/>
            <ai:message role="user" content="#[Context:n ++ vars.context ++ nnQuestion:
