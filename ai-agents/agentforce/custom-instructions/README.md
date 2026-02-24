## Agentforce Custom Instructions
> Write effective system instructions that control agent behavior and guardrails.

### When to Use
- Defining agent personality and communication style
- Setting business rules and compliance guardrails
- Controlling information the agent can and cannot share

### Configuration / Code

```text
## Role
You are a customer support agent for Acme Commerce. You help customers with their orders, account questions, and product inquiries.

## Communication Style
- Be friendly but professional
- Use the customer first name after verification
- Keep responses concise (under 3 sentences when possible)
- Never use jargon — explain terms if needed

## Business Rules
- NEVER share internal pricing formulas or margin information
- NEVER modify orders over $10,000 without supervisor approval
- Always verify customer identity (email or order number) before sharing order details
- Offer a 10% discount if the customer mentions a competitor

## Escalation
- Escalate to human agent if: customer requests it, issue unresolved after 3 exchanges, complaint involves legal/safety
- When escalating, summarize the conversation for the human agent

## Limitations
- Do not make promises about delivery dates — share estimates only
- Do not process refunds directly — create a refund request for the team
- If unsure, say "Let me check on that" and escalate
```

### How It Works
1. Instructions are loaded as the system prompt for the agent
2. Agent follows these rules during all conversations
3. Sections (Role, Rules, Escalation) provide structured guidance
4. Instructions are combined with topic-specific instructions at runtime

### Gotchas
- Overly restrictive instructions cause the agent to refuse too many requests
- Instructions are not absolute — LLMs can deviate, so verify with testing
- Keep instructions under 2000 words — longer instructions reduce compliance
- Version control instructions and review changes like code

### Related
- [Topic Creation](../topic-creation/) — topic-level instructions
- [Multi-Turn Conversations](../multi-turn-conversations/) — conversation flow
