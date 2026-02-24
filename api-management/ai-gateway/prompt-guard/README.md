## Prompt Injection Guard
> Detect and block prompt injection attempts before they reach the LLM.

### When to Use
- Public-facing AI chatbots vulnerable to prompt injection
- Protecting system prompts from extraction or override
- Compliance requirements for AI input validation

### Configuration / Code

```xml
<flow name="prompt-guard-flow">
    <http:listener config-ref="HTTP_Listener" path="/v1/chat/completions" method="POST"/>
    <!-- Extract user message -->
    <set-variable variableName="userMessage"
                  value="#[payload.messages[-1].content]"/>
    <!-- Check for injection patterns -->
    <choice>
        <when expression="#[vars.userMessage matches /(?i)(ignore previous|system prompt|you are now|forget your instructions|reveal your)/]">
            <set-payload value=Request blocked: potential prompt injection detected mimeType="application/json"/>
            <http:response statusCode="400"/>
        </when>
        <otherwise>
            <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Extract the user message from the chat completions request
2. Apply regex patterns to detect common injection phrases
3. Block requests matching injection patterns with 400 response
4. Clean requests pass through to the LLM

### Gotchas
- Regex-based detection catches only known patterns — sophisticated attacks may bypass it
- False positives: legitimate messages may trigger pattern matches
- Defense in depth: combine with system prompt hardening and output filtering
- Log blocked requests for pattern analysis and rule tuning

### Related
- [Content Moderation](../../custom-policies/dataweave-transform/) — content filtering
- [OpenAI Proxy](../openai-proxy/) — gateway setup
