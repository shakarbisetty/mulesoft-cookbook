## Chat Completions with MuleSoft AI Connector
> Call LLM chat completion APIs using the MuleSoft AI/ML Connector.

### When to Use
- Adding conversational AI to MuleSoft integrations
- Calling OpenAI, Azure OpenAI, or Anthropic from Mule flows
- Generating text responses based on user input

### Configuration / Code

```xml
<ai:config name="AI_Config">
    <ai:openai-connection apiKey="${openai.api.key}" model="gpt-4o"/>
</ai:config>

<flow name="chat-completion-flow">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="You are a helpful customer service assistant for an e-commerce platform."/>
            <ai:message role="user" content="#[payload.message]"/>
        </ai:messages>
        <ai:parameters temperature="0.7" maxTokens="500"/>
    </ai:chat-completions>
    <set-payload value="#[output application/json --- {response: payload.choices[0].message.content}]"/>
</flow>
```

### How It Works
1. AI Connector manages the HTTP connection to the LLM provider
2. Messages include system prompt (behavior) and user message
3. `temperature` controls randomness (0=deterministic, 1=creative)
4. Response contains the generated text in the choices array

### Gotchas
- API keys should be stored in secure properties, not hardcoded
- Token limits vary by model — `maxTokens` prevents runaway costs
- Streaming mode requires SSE handling — use for long responses
- Rate limits from the LLM provider need retry handling

### Related
- [Prompt Templates](../prompt-templates/) — reusable prompts
- [Content Moderation](../content-moderation/) — filtering unsafe content
