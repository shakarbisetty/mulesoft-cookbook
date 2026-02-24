## Email Classification Agent
> Automatically classify incoming emails by intent and route to the appropriate team.

### When to Use
- High-volume customer email triage
- Reducing manual email sorting effort
- Routing emails to specialized teams (billing, support, sales)

### Configuration / Code

```xml
<flow name="email-classifier">
    <email:listener-imap config-ref="Email_Config" folder="INBOX"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="Classify the following email into one of these categories: BILLING, SUPPORT, SALES, SPAM, OTHER. Return only the category name."/>
            <ai:message role="user" content="#[Subject:
