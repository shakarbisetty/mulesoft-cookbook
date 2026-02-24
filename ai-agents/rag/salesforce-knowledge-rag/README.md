## Salesforce Knowledge Base RAG
> Build a RAG pipeline using Salesforce Knowledge articles as the data source.

### When to Use
- Customer support chatbots grounded in Salesforce Knowledge
- Internal help desk with AI-powered search
- Reducing support ticket volume with self-service AI

### Configuration / Code

```xml
<!-- Sync Salesforce Knowledge articles -->
<flow name="sync-knowledge-base">
    <scheduler><scheduling-strategy><fixed-frequency frequency="3600000"/></scheduling-strategy></scheduler>
    <salesforce:query config-ref="Salesforce_Config">
        <salesforce:salesforce-query>
            SELECT Id, Title, Summary, ArticleBody
            FROM Knowledge__kav
            WHERE PublishStatus = Online
            AND LastModifiedDate > :lastSync
        </salesforce:salesforce-query>
    </salesforce:query>
    <foreach>
        <flow-ref name="chunk-and-embed"/>
    </foreach>
    <os:store key="lastSync" objectStore="watermark">
        <os:value>#[now()]</os:value>
    </os:store>
</flow>

<!-- RAG query flow -->
<flow name="knowledge-rag-query">
    <http:listener config-ref="HTTP_Listener" path="/support/ask" method="POST"/>
    <flow-ref name="rag-query"/>
</flow>
```

### How It Works
1. Scheduler syncs Salesforce Knowledge articles periodically
2. Articles are chunked, embedded, and stored in the vector database
3. User questions trigger similarity search against the knowledge base
4. LLM generates answers grounded in Salesforce article content

### Gotchas
- Salesforce SOQL has query limits — batch large knowledge bases
- Article updates need re-embedding — track LastModifiedDate
- Deleted articles must be removed from the vector database
- Salesforce session management requires OAuth refresh handling

### Related
- [Similarity Search](../similarity-search/) — search pipeline
- [Document Chunking](../document-chunking/) — chunking strategy
