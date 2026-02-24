## Email SMTP Error Alert
> Send structured error notification emails to an ops distribution list.

### When to Use
- Slack/Teams is not available or not monitored 24/7
- Compliance requires email audit trail of errors
- Escalation path includes email notifications

### Configuration / Code

```xml
<email:smtp-config name="SMTP_Config">
    <email:smtps-connection host="${smtp.host}" port="465" user="${smtp.user}" password="${smtp.password}">
        <tls:context>
            <tls:trust-store insecure="false"/>
        </tls:context>
    </email:smtps-connection>
</email:smtp-config>

<sub-flow name="notify-email-error">
    <email:send config-ref="SMTP_Config" fromAddress="${alert.from}" subject="#['[ALERT] Mule Error: ' ++ error.errorType.identifier]">
        <email:to-addresses>
            <email:to-address value="${alert.ops.email}"/>
        </email:to-addresses>
        <email:body contentType="text/html">
            <email:content><![CDATA[#[output text/html --- '<h2>Mule Error Alert</h2><table border="1"><tr><td>Flow</td><td>' ++ flow.name ++ '</td></tr><tr><td>Error</td><td>' ++ error.errorType.identifier ++ '</td></tr><tr><td>Correlation ID</td><td>' ++ correlationId ++ '</td></tr><tr><td>Description</td><td>' ++ (error.description default "N/A") ++ '</td></tr></table>']]]></email:content>
        </email:body>
    </email:send>
</sub-flow>
```

### How It Works
1. SMTP connector sends HTML email with error details in a table
2. Subject line includes the error type for quick scanning
3. Reusable as a sub-flow from any error handler

### Gotchas
- SMTP connections can be slow (1-5s) — run in async scope if latency matters
- Rate-limit email alerts to prevent inbox flooding during error storms
- Use secure properties for SMTP credentials

### Related
- [Slack Webhook Alert](../slack-webhook-alert/) — faster notification channel
- [CloudHub Notifications](../cloudhub-notifications/) — platform-native alerts
