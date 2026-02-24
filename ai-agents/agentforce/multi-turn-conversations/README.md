## Multi-Turn Conversations
> Manage conversation context and state across multiple agent interactions.

### When to Use
- Complex workflows requiring multiple back-and-forth exchanges
- Gathering information progressively (order details, preferences)
- Maintaining context when switching between topics

### Configuration / Code

```xml
<flow name="conversation-handler">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <!-- Retrieve conversation history -->
    <os:retrieve key="#[payload.sessionId]" objectStore="conversation-store" target="history">
        <os:default-value>#[output application/json --- []]</os:default-value>
    </os:retrieve>
    <!-- Append new message -->
    <set-variable variableName="messages" value="#[vars.history ++ [{role: user, content: payload.message}]]"/>
    <!-- Call LLM with full history -->
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>#[vars.messages]</ai:messages>
    </ai:chat-completions>
    <!-- Save updated history -->
    <set-variable variableName="messages"
                  value="#[vars.messages ++ [{role: assistant, content: payload.choices[0].message.content}]]"/>
    <os:store key="#[payload.sessionId]" objectStore="conversation-store">
        <os:value>#[write(vars.messages, application/json)]</os:value>
    </os:store>
</flow>
```

### How It Works
1. Each conversation has a session ID for state tracking
2. Full message history is stored in Object Store
3. Every LLM call includes the complete conversation context
4. New messages are appended and saved after each exchange

### Gotchas
- Conversation history grows with each turn — trim old messages to stay within token limits
- Object Store TTL controls session expiry (e.g., 30 minutes of inactivity)
- History includes both user messages and assistant responses
- Large histories increase LLM costs — summarize older turns

### Related
- [Custom Instructions](../custom-instructions/) — agent behavior
- [Agent Testing](../agent-testing/) — testing conversations
