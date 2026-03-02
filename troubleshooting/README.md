# Troubleshooting

Production-grade diagnostic recipes for MuleSoft runtime issues. Each recipe is designed for engineers debugging problems under pressure — step-by-step, no fluff.

## Recipes

### Memory & Resources

| # | Recipe | Description |
|---|--------|-------------|
| 1 | [Memory Budget Breakdown](./memory-budget-breakdown/) | Exact memory allocation per vCore (0.1, 0.2, 0.5, 1, 2, 4) — how much heap your app actually gets |
| 2 | [OOM Diagnostic Playbook](./oom-diagnostic-playbook/) | From symptom to root cause in 30 minutes — step-by-step for OutOfMemoryError |
| 3 | [Memory Leak Detection Step-by-Step](./memory-leak-detection-step-by-step/) | Heap dump analysis walkthrough using Eclipse MAT — find unclosed streams, static map growth, and object store leaks |
| 4 | [DataWeave OOM Debugging](./dataweave-oom-debugging/) | Diagnose and fix out-of-memory errors caused by large payloads, recursive transforms, and stream issues |
| 5 | [Streaming Strategy Decision Guide](./streaming-strategy-decision-guide/) | File-store vs in-memory vs non-repeatable streaming with decision tree |
| 6 | [Object Store Limits](./object-store-limits/) | CloudHub Object Store v2 limits, TTL, partition strategy for production use |

### Threading & Performance

| # | Recipe | Description |
|---|--------|-------------|
| 7 | [Thread Dump Analysis](./thread-dump-analysis/) | Take and read thread dumps on CloudHub and on-prem to identify deadlocks, pool exhaustion, and blocked threads |
| 8 | [Thread Dump Reading Guide](./thread-dump-reading-guide/) | Practical UBER thread pool analysis for Mule 4 — line-by-line interpretation |
| 9 | [Thread Pool Component Mapping](./thread-pool-component-mapping/) | Which thread pool (CPU_LITE, IO, CUSTOM) each Mule 4 component uses |
| 10 | [Connection Pool Sizing](./connection-pool-sizing/) | The math behind optimal pool configuration for HTTP, database, and SFTP |
| 11 | [Connection Pool Exhaustion Diagnosis](./connection-pool-exhaustion-diagnosis/) | Identify starved pools from thread dumps and JMX metrics — HikariCP, HTTP requester, and SFTP pools |
| 12 | [Timeout Hierarchy](./timeout-hierarchy/) | Connection, socket, pool wait, and response timeouts explained with diagram |
| 13 | [Flow Profiling Methodology](./flow-profiling-methodology/) | Identify slowest component without guessing — systematic profiling |
| 14 | [Batch Performance Tuning](./batch-performance-tuning/) | Thread profile tuning, block size, maxConcurrency, and memory math for batch |

### Observability & Logging

| # | Recipe | Description |
|---|--------|-------------|
| 15 | [Anypoint Monitoring vs OpenTelemetry](./anypoint-monitoring-vs-otel/) | Capability comparison and OTLP setup guide for exporting Mule telemetry |
| 16 | [OpenTelemetry Setup Guide](./opentelemetry-setup-guide/) | Complete OTel setup with Datadog, Grafana, and Splunk backends |
| 17 | [Structured Logging Complete](./structured-logging-complete/) | JSON logging, correlation IDs, MDC, CloudWatch/ELK/Splunk integration |
| 18 | [CloudHub Log Analysis](./cloudhub-log-analysis/) | Searching CloudHub logs effectively — retention, downloading, filtering |
| 19 | [Anypoint Monitoring Custom Metrics](./anypoint-monitoring-custom-metrics/) | Micrometer integration, custom dashboards, and alerting |

### HTTP & Network Errors

| # | Recipe | Description |
|---|--------|-------------|
| 20 | [HTTP 502/503/504 Guide](./http-502-503-504-guide/) | What each HTTP 5xx means and where the problem actually is |
| 21 | [504 Gateway Timeout Diagnosis](./504-gateway-timeout-diagnosis/) | The 6+ root causes and how to identify each one |
| 22 | [Common Error Messages Decoded](./common-error-messages-decoded/) | Top 30 Mule error messages with actual root causes and immediate fixes |

### Deployment & Platform

| # | Recipe | Description |
|---|--------|-------------|
| 23 | [Deployment Failure Flowchart](./deployment-failure-flowchart/) | Systematic diagnosis of CloudHub 2.0 deployment failures with Anypoint CLI commands |
| 24 | [Deployment Failure Common Causes](./deployment-failure-common-causes/) | The 15 most common deployment failures and fixes |
| 25 | [CloudHub 2.0 Migration Gotchas](./cloudhub2-migration-gotchas/) | Breaking changes from CloudHub 1.0 to 2.0 |
| 26 | [RTF Pod Failure Diagnosis](./rtf-pod-failure-diagnosis/) | Kubernetes-layer troubleshooting for Runtime Fabric |

### Connectors & Integration

| # | Recipe | Description |
|---|--------|-------------|
| 27 | [Salesforce Session Expiry Fix](./salesforce-session-expiry-fix/) | INVALID_SESSION_ID handling with auto-reconnect patterns |
| 28 | [Batch Job Failure Analysis](./batch-job-failure-analysis/) | Memory math for batch sizing, temp file cleanup, and log analysis for failed batch steps |

### Incident Response

| # | Recipe | Description |
|---|--------|-------------|
| 29 | [Top 10 Production Incidents](./top-10-production-incidents/) | Most common incidents with diagnostic runbooks for each |

## How to Use These Recipes

1. **Identify the symptom** — thread hang, OOM crash, deployment failure, mysterious error message, 5xx response
2. **Pick the matching recipe** — each one starts with "When to Use" to confirm you're in the right place
3. **Follow the steps in order** — every recipe is sequential, production-safe, and tested

## Quick Symptom Lookup

| Symptom | Start Here |
|---------|-----------|
| Application unresponsive | [Thread Dump Analysis](./thread-dump-analysis/) |
| OutOfMemoryError | [OOM Diagnostic Playbook](./oom-diagnostic-playbook/) |
| 504 Gateway Timeout | [504 Gateway Timeout Diagnosis](./504-gateway-timeout-diagnosis/) |
| 502 Bad Gateway | [HTTP 502/503/504 Guide](./http-502-503-504-guide/) |
| 503 Service Unavailable | [HTTP 502/503/504 Guide](./http-502-503-504-guide/) |
| Deployment failed | [Deployment Failure Common Causes](./deployment-failure-common-causes/) |
| Slow API response | [Flow Profiling Methodology](./flow-profiling-methodology/) |
| Connection pool exhausted | [Connection Pool Sizing](./connection-pool-sizing/) |
| Salesforce INVALID_SESSION | [Salesforce Session Expiry Fix](./salesforce-session-expiry-fix/) |
| Batch job failed | [Batch Job Failure Analysis](./batch-job-failure-analysis/) |
| Need custom monitoring | [Anypoint Monitoring Custom Metrics](./anypoint-monitoring-custom-metrics/) |
| Migrating to CloudHub 2.0 | [CloudHub 2.0 Migration Gotchas](./cloudhub2-migration-gotchas/) |

## Related Sections

- [Error Handling Patterns](../error-handling/) — preventive error handling design
- [Performance Tuning](../performance/) — proactive performance optimization
- [DevOps & CI/CD](../devops/) — deployment pipelines and monitoring setup
