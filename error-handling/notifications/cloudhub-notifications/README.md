## CloudHub Notifications
> Publish custom CloudHub notifications on error for Runtime Manager visibility.

### When to Use
- Running on CloudHub and want errors visible in Runtime Manager
- You want to trigger CloudHub alerts based on custom notifications
- Platform-native notification without external integrations

### Configuration / Code

```xml
<cloudhub:config name="CloudHub_Config" xmlns:cloudhub="http://www.mulesoft.org/schema/mule/cloudhub"/>

<sub-flow name="notify-cloudhub-error">
    <cloudhub:create-notification config-ref="CloudHub_Config"
                                  domain="${app.name}"
                                  priority="ERROR">
        <cloudhub:message>#[output text/plain --- 'Error in ' ++ flow.name ++ ': ' ++ error.errorType.identifier ++ ' - ' ++ (error.description default 'No description')]</cloudhub:message>
    </cloudhub:create-notification>
</sub-flow>
```

### How It Works
1. `cloudhub:create-notification` publishes a notification to Runtime Manager
2. Notifications appear in the app's Runtime Manager console
3. CloudHub alerts can trigger email/webhook on notification patterns

### Gotchas
- Only works on CloudHub 1.0 — CloudHub 2.0 uses Anypoint Monitoring instead
- Notifications have a 1000-character limit for the message
- Rate limit: ~10 notifications/second per app
- For CH2, use Anypoint Monitoring custom metrics instead

### Related
- [Slack Webhook Alert](../slack-webhook-alert/) — external notification
- [Custom Business Metrics](../../performance/monitoring/custom-business-metrics/) — CH2 alternative
