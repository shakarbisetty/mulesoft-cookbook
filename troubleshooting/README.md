# Troubleshooting

Production-grade diagnostic recipes for MuleSoft runtime issues. Each recipe is designed for engineers debugging problems under pressure — step-by-step, no fluff.

## Recipes

| # | Recipe | Description |
|---|--------|-------------|
| 1 | [Thread Dump Analysis](./thread-dump-analysis/) | Take and read thread dumps on CloudHub and on-prem to identify deadlocks, pool exhaustion, and blocked threads |
| 2 | [Common Error Messages Decoded](./common-error-messages-decoded/) | Top 30 Mule error messages with actual root causes and immediate fixes in table format |
| 3 | [Memory Leak Detection Step-by-Step](./memory-leak-detection-step-by-step/) | Heap dump analysis walkthrough using Eclipse MAT — find unclosed streams, static map growth, and object store leaks |
| 4 | [Deployment Failure Flowchart](./deployment-failure-flowchart/) | Systematic diagnosis of CloudHub 2.0 deployment failures with Anypoint CLI commands at each step |
| 5 | [Anypoint Monitoring vs OpenTelemetry](./anypoint-monitoring-vs-otel/) | Capability comparison and OTLP setup guide for exporting Mule telemetry to Grafana, Datadog, or Splunk |
| 6 | [Connection Pool Exhaustion Diagnosis](./connection-pool-exhaustion-diagnosis/) | Identify starved pools from thread dumps and JMX metrics — HikariCP, HTTP requester, and SFTP pools |
| 7 | [DataWeave OOM Debugging](./dataweave-oom-debugging/) | Diagnose and fix out-of-memory errors caused by large payloads, recursive transforms, and stream issues |
| 8 | [Batch Job Failure Analysis](./batch-job-failure-analysis/) | Memory math for batch sizing, temp file cleanup, and log analysis for failed batch steps |

## How to Use These Recipes

1. **Identify the symptom** — thread hang, OOM crash, deployment failure, mysterious error message
2. **Pick the matching recipe** — each one starts with "When to Use" to confirm you're in the right place
3. **Follow the steps in order** — every recipe is sequential, production-safe, and tested

## Related Sections

- [Error Handling Patterns](../error-handling/) — preventive error handling design
- [Performance Tuning](../performance/) — proactive performance optimization
- [DevOps & CI/CD](../devops/) — deployment pipelines and monitoring setup
