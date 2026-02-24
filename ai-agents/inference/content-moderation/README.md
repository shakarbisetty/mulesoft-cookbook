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
            <set-payload value="#[output application/json --- {
                error: Content
