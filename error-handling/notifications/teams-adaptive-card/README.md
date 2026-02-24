## Microsoft Teams Adaptive Card Alert
> Post an Adaptive Card to a Teams incoming webhook with error severity and context.

### When to Use
- Your organization uses Microsoft Teams for operations communication
- You want rich, formatted error notifications with action buttons
- Link directly to Anypoint Runtime Manager from the alert

### Configuration / Code

```xml
<sub-flow name="notify-teams-error">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    "type": "message",
    "attachments": [{
        "contentType": "application/vnd.microsoft.card.adaptive",
        "content": {
            "\$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": [
                {type: "TextBlock", text: "Mule Error Alert", weight: "Bolder", size: "Large", color: "Attention"},
                {type: "FactSet", facts: [
                    {title: "Flow", value: flow.name},
                    {title: "Error Type", value: error.errorType.identifier},
                    {title: "Correlation ID", value: correlationId},
                    {title: "Timestamp", value: now() as String {format: "yyyy-MM-dd HH:mm:ss z"}}
                ]},
                {type: "TextBlock", text: error.description default "No description", wrap: true, maxLines: 5}
            ]
        }
    }]
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <http:request config-ref="Teams_Webhook" path="${teams.webhook.path}" method="POST"/>
</sub-flow>
```

### How It Works
1. Build an Adaptive Card JSON payload with error details in a FactSet
2. POST to the Teams incoming webhook URL
3. Teams renders the card with formatted fields

### Gotchas
- Teams webhook payload format differs from Slack — use the `attachments` wrapper
- Adaptive Cards have a 28 KB size limit
- Teams webhooks are being deprecated in favor of Power Automate workflows — check your org's policy

### Related
- [Slack Webhook Alert](../slack-webhook-alert/) — Slack alternative
- [Email SMTP Alert](../email-smtp-alert/) — email fallback
