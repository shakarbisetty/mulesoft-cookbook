## Slack Webhook Error Alert
> POST a formatted Slack message with error details to an incoming webhook on failure.

### When to Use
- Operations team monitors a Slack channel for production errors
- You want real-time error notifications with context
- Quick alerting without setting up a full monitoring solution

### Configuration / Code

```xml
<http:request-config name="Slack_Webhook">
    <http:request-connection host="hooks.slack.com" port="443" protocol="HTTPS"/>
</http:request-config>

<sub-flow name="notify-slack-error">
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    blocks: [
        {type: "header", text: {type: "plain_text", text: ":rotating_light: Mule Error Alert"}},
        {type: "section", fields: [
            {type: "mrkdwn", text: "*Flow:*\n" ++ flow.name},
            {type: "mrkdwn", text: "*Error:*\n" ++ error.errorType.identifier},
            {type: "mrkdwn", text: "*Correlation ID:*\n" ++ correlationId},
            {type: "mrkdwn", text: "*Time:*\n" ++ (now() as String {format: "HH:mm:ss z"})}
        ]},
        {type: "section", text: {type: "mrkdwn", text: "*Description:*\n```" ++ (error.description default "No description")[0 to 500] ++ "```"}}
    ]
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <http:request config-ref="Slack_Webhook" path="${slack.webhook.path}" method="POST"/>
</sub-flow>
```

**Usage in error handler:**
```xml
<on-error-propagate type="ANY">
    <flow-ref name="notify-slack-error"/>
    <set-variable variableName="httpStatus" value="500"/>
    <set-payload value='{"error":"Internal error"}' mimeType="application/json"/>
</on-error-propagate>
```

### How It Works
1. DataWeave builds a Slack Block Kit message with error metadata
2. HTTP POST sends it to the Slack incoming webhook URL
3. The `sub-flow` is reusable from any error handler via `flow-ref`

### Gotchas
- Slack webhooks have rate limits (1 message/sec) — batch errors in high-volume scenarios
- Store the webhook URL in secure properties, not in code
- Truncate `error.description` to avoid Slack's 3000-character block limit
- If the Slack POST fails, do not let it mask the original error

### Related
- [Teams Adaptive Card](../teams-adaptive-card/) — Microsoft Teams alternative
- [Structured JSON Logging](../structured-json-logging/) — log-based alerting
