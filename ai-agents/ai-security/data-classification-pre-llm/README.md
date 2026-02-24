## Data Classification Before LLM Processing
> Classify data sensitivity levels before deciding what can be sent to external LLMs.

### When to Use
- Compliance requirements for data handling (GDPR, HIPAA, PCI)
- Preventing sensitive data from leaving organizational boundaries
- Routing to on-premises vs. cloud LLMs based on data sensitivity

### Configuration / Code

```xml
<flow name="classified-ai-request">
    <http:listener config-ref="HTTP_Listener" path="/ai/safe-process" method="POST"/>
    <!-- Classify input data -->
    <ee:transform>
        <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
var hasPII = payload.text matches /\b\d{3}-\d{2}-\d{4}\b/ or payload.text matches /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
var hasPHI = payload.text matches /(?i)(diagnosis|prescription|patient|medical record)/
var hasPCI = payload.text matches /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/
---
{
    text: payload.text,
    classification: if (hasPHI) "RESTRICTED"
                    else if (hasPCI) "CONFIDENTIAL"
                    else if (hasPII) "INTERNAL"
                    else "PUBLIC",
    flags: {pii: hasPII, phi: hasPHI, pci: hasPCI}
}]]></ee:set-payload></ee:message>
    </ee:transform>
    <choice>
        <when expression="#[payload.classification == RESTRICTED]">
            <logger message="RESTRICTED data detected — routing to on-prem LLM"/>
            <flow-ref name="on-prem-llm-call"/>
        </when>
        <when expression="#[payload.classification == CONFIDENTIAL]">
            <flow-ref name="mask-and-process"/>
        </when>
        <otherwise>
            <flow-ref name="cloud-llm-call"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Input text is scanned for sensitive data patterns (PII, PHI, PCI)
2. Classification determines the sensitivity level
3. RESTRICTED data stays on-premises; PUBLIC data can go to cloud LLMs
4. CONFIDENTIAL data is masked before cloud processing

### Gotchas
- Regex-based classification has false positives and negatives
- Consider ML-based classifiers for better accuracy
- Classification logic must be kept up to date with compliance requirements
- Log classification decisions for audit purposes (but not the sensitive data)

### Related
- [PII Masking](../../ai-gateway/pii-masking-llm/) — masking sensitive data
- [Prompt Injection Detection](../../ai-gateway/prompt-injection-detection/) — input security
