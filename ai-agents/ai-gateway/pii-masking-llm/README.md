## PII Masking Before LLM Calls
> Detect and mask personally identifiable information before sending to LLMs.

### When to Use
- Compliance with GDPR, CCPA, or HIPAA for AI applications
- Preventing PII leakage to external LLM providers
- Enterprise AI governance requirements

### Configuration / Code

```xml
<flow name="pii-masked-chat">
    <http:listener config-ref="HTTP_Listener" path="/safe-chat" method="POST"/>
    <!-- Detect and mask PII -->
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
var emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
var phonePattern = /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/
var ssnPattern = /\b\d{3}-\d{2}-\d{4}\b/
---
{
    maskedMessage: payload.message
        replace emailPattern with "[EMAIL_REDACTED]"
        replace phonePattern with "[PHONE_REDACTED]"
        replace ssnPattern with "[SSN_REDACTED]",
    originalMessage: payload.message
}]]></ee:set-payload></ee:message>
    </ee:transform>
    <!-- Send masked content to LLM -->
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="user" content="#[payload.maskedMessage]"/>
        </ai:messages>
    </ai:chat-completions>
</flow>
```

### How It Works
1. Regex patterns detect common PII types (email, phone, SSN)
2. PII is replaced with redaction tokens before LLM processing
3. LLM sees only masked content — PII never leaves the organization
4. Original content can be used internally for follow-up actions

### Gotchas
- Regex-based PII detection is not exhaustive — consider NER models for better coverage
- Masked content may confuse the LLM — provide context about redacted fields
- Names and addresses are hard to detect with regex — use ML-based detection
- Audit logging should capture that masking occurred (not the original PII)

### Related
- [Prompt Injection Detection](../prompt-injection-detection/) — input security
- [Data Classification](../data-classification-pre-llm/) — classifying sensitive data
