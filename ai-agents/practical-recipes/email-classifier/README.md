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
    <set-variable variableName="emailSubject" value="#[payload.subject]"/>
    <set-variable variableName="emailBody" value="#[payload.body.content]"/>
    <ai:chat-completions config-ref="AI_Config">
        <ai:messages>
            <ai:message role="system" content="Classify the following email into one of these categories: BILLING, SUPPORT, SALES, SPAM, OTHER. Return JSON: {category, confidence, summary}"/>
            <ai:message role="user" content="#['Subject: ' ++ vars.emailSubject ++ '\nBody: ' ++ vars.emailBody]"/>
        </ai:messages>
        <ai:config temperature="0.1" maxTokens="100"/>
    </ai:chat-completions>
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var result = read(payload.choices[0].message.content, "application/json")
---
{
    category: result.category,
    confidence: result.confidence,
    summary: result.summary,
    originalSubject: vars.emailSubject
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <!-- Route based on classification -->
    <choice>
        <when expression="#[payload.category == 'BILLING']">
            <flow-ref name="route-to-billing"/>
        </when>
        <when expression="#[payload.category == 'SUPPORT']">
            <flow-ref name="route-to-support"/>
        </when>
        <when expression="#[payload.category == 'SALES']">
            <flow-ref name="route-to-sales"/>
        </when>
        <when expression="#[payload.category == 'SPAM']">
            <flow-ref name="route-to-spam-folder"/>
        </when>
        <otherwise>
            <flow-ref name="route-to-general"/>
        </otherwise>
    </choice>
</flow>

<!-- Example routing sub-flow -->
<sub-flow name="route-to-billing">
    <email:send config-ref="SMTP_Config" toAddresses="billing-team@company.com">
        <email:body contentType="text/plain">
            <email:content>#['[AI Classified: BILLING] ' ++ payload.summary ++ '\n\nOriginal Subject: ' ++ payload.originalSubject]</email:content>
        </email:body>
    </email:send>
    <logger message="#['Routed to BILLING: ' ++ payload.originalSubject]" level="INFO"/>
</sub-flow>
```

### How It Works
1. IMAP listener monitors the inbox for new emails
2. Subject and body are extracted and stored in variables
3. AI connector classifies the email with very low temperature (0.1) for consistency
4. Response includes category, confidence score, and a brief summary
5. Choice router directs the email to the appropriate team's sub-flow
6. Each routing sub-flow forwards the classified email with AI-generated summary
7. Logger creates an audit trail of all routing decisions

### Gotchas
- Use `temperature: 0.1` for classification — higher values cause inconsistent categories
- Limit `maxTokens: 100` — classification should be concise, not an essay
- Add confidence thresholds — route low-confidence emails to human review
- IMAP listener may re-process emails on restart — use `delete: false` and track processed IDs
- Test with diverse email samples including edge cases (multi-language, empty body, HTML-only)

### Related
- [MUnit Mock for LLM](../../ai-testing/munit-mock-llm/) — testing this flow without real AI calls
- [Data Enrichment Agent](../data-enrichment-agent/) — similar AI classification pattern
- [Sentiment Analysis](../sentiment-analysis/) — adding sentiment to email classification
