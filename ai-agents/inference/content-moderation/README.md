## Content Moderation
> Filter user inputs and AI outputs for unsafe or inappropriate content.

### When to Use
- Public-facing AI chatbots requiring content safety
- Compliance with content policies (hate speech, PII, violence)
- Pre-filtering inputs before sending to LLMs

### Configuration / Code

```xml
<flow name="moderated-chat">
    <http:listener config-ref="HTTP_Listener" path="/safe-chat" method="POST"/>
    <!-- Check input with moderation API -->
    <http:request config-ref="OpenAI_Config" path="/v1/moderations" method="POST">
        <http:body>#[output application/json --- {input: payload.message}]</http:body>
    </http:request>
    <choice>
        <when expression="#[payload.results[0].flagged == true]">
            <set-payload value='#[output application/json --- {
                error: "Content policy violation",
                categories: payload.results[0].categories
                    filterObject ((v, k) -> v == true)
                    pluck ((v, k) -> k as String)
            }]'/>
            <set-variable variableName="httpStatus" value="400"/>
        </when>
        <otherwise>
            <!-- Input is safe — forward to LLM -->
            <ai:chat-completions config-ref="AI_Config">
                <ai:messages>
                    <ai:message role="system" content="You are a helpful assistant."/>
                    <ai:message role="user" content="#[vars.originalMessage]"/>
                </ai:messages>
            </ai:chat-completions>
            <!-- Also moderate the output -->
            <set-variable variableName="aiResponse" value="#[payload.choices[0].message.content]"/>
            <http:request config-ref="OpenAI_Config" path="/v1/moderations" method="POST">
                <http:body>#[output application/json --- {input: vars.aiResponse}]</http:body>
            </http:request>
            <choice>
                <when expression="#[payload.results[0].flagged == true]">
                    <set-payload value='#[output application/json --- {
                        response: "I cannot provide that information.",
                        moderated: true
                    }]'/>
                </when>
                <otherwise>
                    <set-payload value='#[output application/json --- {
                        response: vars.aiResponse,
                        moderated: false
                    }]'/>
                </otherwise>
            </choice>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. User message arrives and is sent to the moderation API for input screening
2. If flagged, the request is rejected with 400 and the violated category names
3. If safe, the message forwards to the LLM via the AI Connector
4. The LLM response is also moderated (output screening) before returning to the user
5. Flagged AI outputs are replaced with a safe generic message
6. Both input and output moderation use the same OpenAI moderation endpoint
7. Categories like `hate`, `violence`, `self-harm`, `sexual` are individually flagged

### Gotchas
- Moderation adds ~200ms latency per check — two checks per request (input + output)
- OpenAI moderation API is free but rate-limited — cache results for repeated inputs
- Moderation models have false positives — monitor rejections and tune thresholds
- Non-English content has lower accuracy — consider language-specific moderation
- Store moderation results for compliance audit trails

### Related
- [PII Masking for LLM](../../ai-gateway/pii-masking-llm/) — remove PII before sending to LLMs
- [Prompt Injection Detection](../../ai-gateway/prompt-injection-detection/) — block prompt attacks
- [Chat Completions](../chat-completions/) — the base inference pattern used here
