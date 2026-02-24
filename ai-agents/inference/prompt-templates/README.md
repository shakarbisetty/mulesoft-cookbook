## Prompt Templates
> Define reusable, parameterized prompt templates for consistent LLM interactions.

### When to Use
- Standardizing prompts across multiple flows
- Separating prompt engineering from application logic
- A/B testing different prompt variations

### Configuration / Code

**config/prompts/order-summary.txt:**
```
You are analyzing an order for a customer service system.

Order Details:
- Order ID: {{orderId}}
- Customer: {{customerName}}
- Items: {{items}}
- Total: {{total}}

Provide a brief, friendly summary of this order suitable for a customer email.
Keep it under 100 words.
```

**Mule flow using the template:**
```xml
<flow name="order-summary-flow">
    <http:listener config-ref="HTTP_Listener" path="/order-summary" method="POST"/>
    <parse-template location="config/prompts/order-summary.txt"/>
    <set-variable variableName="prompt" value="#[payload]"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="user" content="#[vars.prompt]"/>
        </ai:messages>
    </ai:chat-completions>
</flow>
```

### How It Works
1. Prompt templates are stored as external files with `{{placeholders}}`
2. `parse-template` resolves placeholders from flow variables
3. Resolved prompt is sent to the LLM via the AI connector
4. Templates can be updated without changing Mule flow code

### Gotchas
- Template variables must match flow variable names exactly
- Long prompts consume more tokens — optimize for conciseness
- Version control prompt templates alongside your Mule app
- Test prompt changes in isolation before deploying to production

### Related
- [Chat Completions](../chat-completions/) — calling the LLM
- [A/B Testing Prompts](../../ai-testing/ab-testing-prompts/) — testing variations
