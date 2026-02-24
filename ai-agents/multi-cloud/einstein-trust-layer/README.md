## Einstein Trust Layer Integration
> Use Salesforce Einstein Trust Layer for secure, governed AI within the Salesforce ecosystem.

### When to Use
- Salesforce-centric AI with built-in data masking and audit
- Compliance requirements for AI interactions (financial, healthcare)
- Leveraging Salesforce data without exposing PII to external LLMs

### Configuration / Code

```xml
<flow name="einstein-trust-layer">
    <http:listener config-ref="HTTP_Listener" path="/ai/einstein" method="POST"/>
    <!-- Authenticate with Salesforce -->
    <salesforce:authorize config-ref="Salesforce_Config"/>
    <!-- Call Einstein Trust Layer -->
    <http:request config-ref="Salesforce_API" path="/services/data/v60.0/einstein/llm/prompt" method="POST">
        <http:body>#[output application/json --- {
            promptTextorId: "Generate a summary of this customer case",
            inputParams: {
                caseId: payload.caseId
            },
            additionalConfig: {
                maxTokens: 500,
                temperature: 0.3,
                applicationName: "MuleSoft Integration"
            }
        }]</http:body>
    </http:request>
</flow>
```

### How It Works
1. Request goes through Salesforce authentication
2. Einstein Trust Layer applies data masking (PII removal) automatically
3. Masked prompt is sent to the underlying LLM
4. Response is de-masked and audit logged by the Trust Layer

### Gotchas
- Requires Salesforce Einstein license and Trust Layer enablement
- Trust Layer adds latency for masking/de-masking operations
- Available models are limited to Salesforce-approved providers
- API versions change with Salesforce releases — check compatibility

### Related
- [PII Masking](../../ai-gateway/pii-masking-llm/) — manual PII masking
- [Salesforce Knowledge RAG](../../rag/salesforce-knowledge-rag/) — Salesforce data for RAG
