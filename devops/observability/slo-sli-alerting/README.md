## SLO/SLI Definitions and Alerting
> Define Service Level Objectives and Indicators with automated alert rules

### When to Use
- You need formal SLOs for your MuleSoft APIs (availability, latency, error rate)
- You want automated alerting when SLIs degrade below thresholds
- You need error budget tracking to balance reliability and velocity

### Configuration

**SLO definitions (slo-definitions.yaml)**
```yaml
slos:
  - name: "Order API Availability"
    service: order-api
    sli:
      type: availability
      metric: "sum(rate(http_requests_total{app='order-api',status!~'5..'}[5m])) / sum(rate(http_requests_total{app='order-api'}[5m]))"
    target: 99.9      # 99.9% availability
    window: 30d        # Rolling 30-day window
    error_budget: 0.1  # 0.1% = ~43 minutes/month
    alerts:
      - severity: warning
        condition: "error_budget_remaining < 50%"
        message: "Order API error budget is 50% consumed"
      - severity: critical
        condition: "error_budget_remaining < 20%"
        message: "Order API error budget nearly exhausted"

  - name: "Order API Latency"
    service: order-api
    sli:
      type: latency
      metric: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app='order-api'}[5m]))"
    target: 95         # 95% of requests under threshold
    threshold: 2.0     # 2 seconds p95
    window: 30d
    alerts:
      - severity: warning
        condition: "p95_latency > 1.5s for 10m"
        message: "Order API p95 latency exceeding 1.5s"
      - severity: critical
        condition: "p95_latency > 2.0s for 5m"
        message: "Order API p95 latency SLO breach"

  - name: "Order API Error Rate"
    service: order-api
    sli:
      type: error_rate
      metric: "sum(rate(http_requests_total{app='order-api',status=~'5..'}[5m])) / sum(rate(http_requests_total{app='order-api'}[5m])) * 100"
    target: 0.1        # Less than 0.1% error rate
    window: 30d
    alerts:
      - severity: warning
        condition: "error_rate > 0.05% for 10m"
        message: "Order API error rate elevated"
      - severity: critical
        condition: "error_rate > 0.1% for 5m"
        message: "Order API error rate SLO breach"
```

**Prometheus alerting rules (mulesoft-alerts.yaml)**
```yaml
groups:
  - name: mulesoft-slo-alerts
    interval: 30s
    rules:
      # Availability SLO
      - alert: OrderApiAvailabilitySLOWarning
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{app="order-api",status!~"5.."}[30d]))
              /
              sum(rate(http_requests_total{app="order-api"}[30d]))
            )
          ) / 0.001 > 0.5
        for: 5m
        labels:
          severity: warning
          service: order-api
          slo: availability
        annotations:
          summary: "Order API error budget 50% consumed"
          description: "Error budget consumption: {{ $value | humanizePercentage }}"

      - alert: OrderApiAvailabilitySLOCritical
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{app="order-api",status!~"5.."}[30d]))
              /
              sum(rate(http_requests_total{app="order-api"}[30d]))
            )
          ) / 0.001 > 0.8
        for: 5m
        labels:
          severity: critical
          service: order-api
          slo: availability
        annotations:
          summary: "Order API error budget 80% consumed"

      # Latency SLO
      - alert: OrderApiLatencySLOWarning
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="order-api"}[5m])) > 1.5
        for: 10m
        labels:
          severity: warning
          service: order-api
          slo: latency
        annotations:
          summary: "Order API p95 latency {{ $value }}s (threshold 1.5s)"

      - alert: OrderApiLatencySLOCritical
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="order-api"}[5m])) > 2.0
        for: 5m
        labels:
          severity: critical
          service: order-api
          slo: latency
        annotations:
          summary: "Order API p95 latency SLO BREACH: {{ $value }}s"

      # Error Rate SLO
      - alert: OrderApiErrorRateSLOCritical
        expr: |
          sum(rate(http_requests_total{app="order-api",status=~"5.."}[5m]))
          / sum(rate(http_requests_total{app="order-api"}[5m])) * 100 > 0.1
        for: 5m
        labels:
          severity: critical
          service: order-api
          slo: error_rate
        annotations:
          summary: "Order API error rate {{ $value }}% exceeds 0.1% SLO"

      # Business Metric Alert
      - alert: OrderProcessingStalled
        expr: |
          rate(orders_processed_total[10m]) == 0
          and
          rate(http_requests_total{app="order-api"}[10m]) > 0
        for: 5m
        labels:
          severity: critical
          service: order-api
        annotations:
          summary: "Orders are being received but not processed"

**Alertmanager config (alertmanager.yml)**
```yaml
route:
  receiver: "default"
  group_by: [service, slo]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: "pagerduty-critical"
      repeat_interval: 1h

    - match:
        severity: warning
      receiver: "slack-warnings"
      repeat_interval: 4h

receivers:
  - name: "default"
    slack_configs:
      - api_url: "${SLACK_WEBHOOK_URL}"
        channel: "#mulesoft-alerts"
        title: "{{ .GroupLabels.service }} - {{ .GroupLabels.slo }}"
        text: "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}"

  - name: "pagerduty-critical"
    pagerduty_configs:
      - service_key: "${PAGERDUTY_SERVICE_KEY}"
        severity: critical

  - name: "slack-warnings"
    slack_configs:
      - api_url: "${SLACK_WEBHOOK_URL}"
        channel: "#mulesoft-alerts"
        color: "warning"
```

**Grafana SLO dashboard query (error budget)**
```
Error Budget Remaining (%) =
  100 * (1 - (
    (1 - (
      sum(increase(http_requests_total{app="order-api",status!~"5.."}[30d]))
      / sum(increase(http_requests_total{app="order-api"}[30d]))
    )) / 0.001
  ))
```

### How It Works
1. **SLIs** (Service Level Indicators) are measurable metrics: availability, latency, error rate
2. **SLOs** (Service Level Objectives) set targets for SLIs: "99.9% availability over 30 days"
3. **Error budgets** quantify how much unreliability is acceptable: 0.1% = ~43 minutes/month
4. Prometheus alerting rules fire when error budget is consumed too fast
5. Alertmanager routes alerts to Slack (warnings) and PagerDuty (critical)
6. Grafana dashboards show real-time error budget burn rate

### Gotchas
- SLOs should be set based on user experience, not technical capability (99.99% is often overkill)
- Error budget consumption alerts are more useful than raw metric alerts (they account for history)
- Multi-window, multi-burn-rate alerts reduce false positives (Google SRE book pattern)
- Prometheus needs 30+ days of data for 30-day SLO calculations; ensure retention is sufficient
- SLO targets should be reviewed quarterly; over-conservative targets slow down development

### Related
- [distributed-tracing-otel](../distributed-tracing-otel/) — Trace data for latency SLIs
- [custom-metrics-micrometer](../custom-metrics-micrometer/) — Business metric SLIs
- [log-aggregation](../log-aggregation/) — Error logs for availability SLIs
