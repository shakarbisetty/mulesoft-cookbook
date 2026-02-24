## Exchange API Documentation RAG
> Index Anypoint Exchange API documentation for AI-powered developer assistance.

### When to Use
- Developer portal chatbot answering API usage questions
- Internal developer productivity tool for MuleSoft APIs
- Automated documentation search and Q&A

### Configuration / Code

```xml
<!-- Index Exchange API docs -->
<flow name="index-exchange-docs">
    <http:listener config-ref="HTTP_Listener" path="/admin/index-apis" method="POST"/>
    <http:request config-ref="Exchange_API" path="/v2/assets" method="GET">
        <http:query-params>#[{organizationId: vars.orgId, type: "rest-api"}]</http:query-params>
    </http:request>
    <foreach>
        <!-- Fetch API spec and docs for each asset -->
        <http:request config-ref="Exchange_API" path="/v2/assets/#[payload.groupId]/#[payload.assetId]"/>
        <set-variable variableName="docContent" value="#[payload.description ++ payload.pages map $.content joinBy n]"/>
        <flow-ref name="chunk-and-embed"/>
    </foreach>
</flow>
```

### How It Works
1. Exchange API lists all published API assets
2. Each API asset includes specs, descriptions, and documentation pages
3. Documentation content is chunked, embedded, and indexed
4. Developers ask questions and get answers grounded in actual API docs

### Gotchas
- Exchange API rate limits apply — throttle indexing requests
- API specs (RAML/OAS) should be indexed separately from prose documentation
- Index updates needed when APIs are updated in Exchange
- Authentication requires a connected app with Exchange Viewer permissions

### Related
- [Salesforce Knowledge RAG](../salesforce-knowledge-rag/) — CRM knowledge base
- [Vectors Setup](../vectors-setup/) — vector database setup
