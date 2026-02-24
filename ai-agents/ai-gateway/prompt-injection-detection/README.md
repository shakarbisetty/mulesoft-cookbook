## Prompt Injection Detection
> Detect and block prompt injection attacks before they reach the LLM.

### When to Use
- Public-facing AI applications accepting user input
- Protecting system prompts from extraction or manipulation
- Security-sensitive AI deployments (finance, healthcare)

### Configuration / Code

```xml
<flow name="injection-protected-chat">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <set-variable variableName="userInput" value="#[payload.message]"/>
    <!-- Pattern-based detection -->
    <choice>
        <when expression="#[vars.userInput matches /(?i)(ignore|forget|disregard).*(previous|above|prior|system).*(instructions|prompt|rules)/]">
            <set-payload value=Request blocked: suspected prompt injection mimeType="application/json"/>
            <http:response statusCode="400"/>
        </when>
        <when expression="#[vars.userInput matches /(?i)(you are now|act as|pretend to be|new persona|roleplay as)/]">
            <set-payload value=Request blocked: suspected role manipulation mimeType="application/json"/>
            <http:response statusCode="400"/>
        </when>
        <when expression="#[sizeOf(vars.userInput) > 5000]">
            <set-payload value=Request blocked: input too long mimeType="application/json"/>
            <http:response statusCode="400"/>
        </when>
        <otherwise>
            <flow-ref name="chat-completion-flow"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. User input is scanned for known injection patterns
2. Instruction override attempts are blocked (ignore/forget previous)
3. Role manipulation attempts are blocked (you are now/act as)
4. Input length limits prevent prompt stuffing attacks

### Gotchas
- Regex detection only catches known patterns — sophisticated attacks bypass it
- Multi-language injection attempts need localized patterns
- Defense in depth: combine input filtering with robust system prompts
- Log all blocked attempts for security analysis and pattern updates

### Related
- [PII Masking](../pii-masking-llm/) — data protection
- [Content Moderation](../../inference/content-moderation/) — content safety
