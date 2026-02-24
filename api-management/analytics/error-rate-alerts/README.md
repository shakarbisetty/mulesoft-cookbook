## Error Rate Alerting
> Configure automated alerts when API error rates exceed thresholds.

### When to Use
- Proactive incident detection before users report issues
- SLA compliance monitoring (99.9% uptime)
- Escalation workflows for critical API failures

### Configuration / Code

**Anypoint Monitoring alert configuration:**
```yaml
alert:
  name: "Orders API High Error Rate"
  condition:
    metric: "http_responses_total"
    filter:
      api: "orders-api"
      status_code: "5xx"
    aggregation: rate
    window: 5m
    threshold: 5
    operator: ">"
  severity: critical
  notifications:
  - type: email
    recipients: ["api-team@example.com"]
  - type: pagerduty
    serviceKey: "${PAGERDUTY_KEY}"
  - type: slack
    webhookUrl: "${SLACK_WEBHOOK}"
```

**Mule 4 — manual error tracking:**
```xml
<error-handler>
    <on-error-propagate>
        <anypoint-monitoring:custom-metric metricName="api_errors">
            <anypoint-monitoring:dimensions>
                <anypoint-monitoring:dimension key="error_type" value="#[error.errorType.identifier]"/>
                <anypoint-monitoring:dimension key="endpoint" value="#[attributes.requestPath]"/>
            </anypoint-monitoring:dimensions>
            <anypoint-monitoring:facts>
                <anypoint-monitoring:fact key="count" value="1"/>
            </anypoint-monitoring:facts>
        </anypoint-monitoring:custom-metric>
    </on-error-propagate>
</error-handler>
```

### How It Works
1. Anypoint Monitoring tracks error rates per API automatically
2. Alert rules trigger when the rate exceeds the threshold over the window
3. Notifications are sent to configured channels (email, PagerDuty, Slack)
4. Custom error metrics provide additional context (error type, endpoint)

### Gotchas
- Set alert windows long enough to avoid false alarms from transient spikes (5m minimum)
- Error rate alerts should distinguish client errors (4xx) from server errors (5xx)
- Alert fatigue: start with critical alerts only, add warnings incrementally
- PagerDuty integration requires the Events API v2 service key

### Related
- [Analytics Dashboard](../analytics-dashboard/) — visualization
- [Custom Metrics Connector](../custom-metrics-connector/) — custom metrics
