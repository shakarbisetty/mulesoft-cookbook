## Order Status Chatbot
> Build a conversational chatbot that retrieves and explains order status.

### When to Use
- Customer self-service for order tracking
- Reducing support ticket volume for status inquiries
- 24/7 automated customer support

### Configuration / Code

```xml
<flow name="order-chatbot">
    <http:listener config-ref="HTTP_Listener" path="/chatbot" method="POST"/>
    <!-- Retrieve conversation history -->
    <os:retrieve key="#[payload.sessionId]" objectStore="sessions" target="history">
        <os:default-value>#[output application/json --- []]</os:default-value>
    </os:retrieve>
    <!-- LLM with function calling -->
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="You are a helpful order assistant. Use the get_order function to look up order details. Be concise and friendly."/>
            <ai:message role="user" content="#[payload.message]"/>
        </ai:messages>
        <ai:tools>
            <ai:tool name="get_order" description="Look up order by ID">
                <ai:parameters>{"type":"object","properties":{"orderId":{"type":"string"}},"required":["orderId"]}</ai:parameters>
            </ai:tool>
        </ai:tools>
    </ai:chat-completions>
    <!-- Handle function calls -->
    <choice>
        <when expression="#[payload.choices[0].message.tool_calls != null]">
            <set-variable variableName="orderId" value="#[payload.choices[0].message.tool_calls[0].function.arguments.orderId]"/>
            <flow-ref name="get-order-from-db"/>
            <!-- Send function result back to LLM -->
            <ai:chat-completions config-ref="AI_Config">
                <ai:messages>
                    <ai:message role="tool" content="#[write(vars.orderData, application/json)]"/>
                </ai:messages>
            </ai:chat-completions>
        </when>
    </choice>
</flow>
```

### How It Works
1. User sends a message to the chatbot endpoint
2. LLM determines if it needs to call the get_order function
3. Mule executes the function (database query) and returns results to the LLM
4. LLM formats a natural language response using the order data

### Gotchas
- Function calling adds an extra LLM round-trip — increases latency
- Validate function arguments before executing (SQL injection prevention)
- Session management is needed for multi-turn conversations
- Handle cases where the order is not found gracefully

### Related
- [Multi-Turn Conversations](../../agentforce/multi-turn-conversations/) — session management
- [Chat Completions](../../inference/chat-completions/) — LLM basics
