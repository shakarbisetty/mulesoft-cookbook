# MuleSoft Cookbook

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![MuleSoft](https://img.shields.io/badge/MuleSoft-Anypoint-00A1E0.svg)](https://www.mulesoft.com/)
[![Recipes](https://img.shields.io/badge/recipes-490%2B-orange.svg)](#whats-inside)
[![GitHub Stars](https://img.shields.io/github/stars/shakarbisetty/mulesoft-cookbook?style=social)](https://github.com/shakarbisetty/mulesoft-cookbook)

> Practical recipes for MuleSoft developers — DataWeave patterns, error handling, performance tuning, AI agent integration, API management, CI/CD pipelines, migration guides, Salesforce integration, cost optimization, troubleshooting, enterprise architecture, messaging, and connector patterns.

---

## What's Inside

| Section | What You Get | Recipes |
|---------|-------------|---------|
| [**DataWeave**](dataweave/) | Transformation patterns, Exchange modules, cheatsheet, anti-patterns | 102 |
| [**Error Handling**](error-handling/) | Global handlers, retry/circuit breaker, DLQ, transactions, notifications | 51 |
| [**Performance**](performance/) | Streaming, memory tuning, batch optimization, caching, thread pools | 49 |
| [**API Management**](api-management/) | Flex Gateway, custom policies, rate limiting, security, governance | 57 |
| [**AI Agents**](ai-agents/) | MCP, A2A, RAG, Agentforce, inference, Vibes, AI testing, AI gateway | 63 |
| [**DevOps**](devops/) | CI/CD pipelines, IaC, secrets, deployment, testing, observability | 53 |
| [**Migrations**](migrations/) | Java versions, runtime upgrades, CloudHub, connectors, architecture | 63 |
| [**Cost Optimization**](cost-optimization/) | vCore sizing, API consolidation, license audit, TCO comparison | 7 |
| [**Salesforce**](salesforce/) | Bidirectional sync, Bulk API, CDC, Agentforce, OAuth, Composite API | 9 |
| [**Troubleshooting**](troubleshooting/) | Thread dumps, OOM debugging, error decoding, deployment failures | 8 |
| [**Architecture**](architecture/) | API-led patterns, C4E, event-driven, DR strategy, maturity model | 8 |
| [**Messaging**](messaging/) | Anypoint MQ vs Kafka, FIFO, DLQ replay, circuit breaker, ordering | 7 |
| [**Connectors**](connectors/) | SAP, Workday, ServiceNow, NetSuite, EDI, SFTP, AS2, database CDC | 8 |

---

## Quick Start

**Pick a section** from the table above, or jump straight to the most popular content:

### DataWeave (most popular)

```dwl
%dw 2.0
output application/json
---
payload filter $.status == "active"
    map {
        name: $.firstName ++ " " ++ $.lastName,
        email: lower($.email)
    }
```

Browse all 102 patterns: **[dataweave/](dataweave/)**

---

## Table of Contents

### DataWeave Patterns (102)

| Category | Patterns | Difficulty |
|----------|----------|-----------|
| [Array Manipulation](dataweave/patterns/01-array-manipulation/) | 9 | Beginner to Advanced |
| [Object Transformation](dataweave/patterns/02-object-transformation/) | 7 | Beginner to Advanced |
| [String Operations](dataweave/patterns/03-string-operations/) | 6 | Beginner to Intermediate |
| [Type Coercion](dataweave/patterns/04-type-coercion/) | 4 | Beginner to Advanced |
| [XML Handling](dataweave/patterns/05-xml-handling/) | 7 | Intermediate to Advanced |
| [CSV Operations](dataweave/patterns/06-csv-operations/) | 4 | Beginner to Intermediate |
| [Error Handling](dataweave/patterns/07-error-handling/) | 6 | Beginner to Advanced |
| [Date/Time](dataweave/patterns/08-date-time/) | 4 | Beginner to Intermediate |
| [Advanced Patterns](dataweave/patterns/09-advanced-patterns/) | 9 | Advanced |
| [Real-World Mappings](dataweave/patterns/10-real-world-mappings/) | 6 | Intermediate to Advanced |
| [Security & Encoding](dataweave/patterns/11-security-encoding/) | 7 | Intermediate to Advanced |
| [API Response Patterns](dataweave/patterns/12-api-response-patterns/) | 5 | Intermediate to Advanced |
| [Flat File / Fixed Width](dataweave/patterns/13-flat-file-fixed-width/) | 4 | Intermediate to Advanced |
| [Lookup & Enrichment](dataweave/patterns/14-lookup-enrichment/) | 4 | Intermediate to Advanced |
| [Performance Optimization](dataweave/patterns/15-performance-optimization/) | 6 | Advanced |
| [Event-Driven](dataweave/patterns/16-event-driven/) | 2 | Advanced |
| [Math & Precision](dataweave/patterns/17-math-precision/) | 2 | Intermediate |
| [Observability](dataweave/patterns/18-observability/) | 2 | Intermediate |
| [AI Integration](dataweave/patterns/19-ai-integration/) | 2 | Advanced |
| [Utility Modules](dataweave/patterns/20-utility-modules/) | 5 | Intermediate to Advanced |

### Additional DataWeave Resources

- [DW 2.x Cheatsheet](dataweave/cheatsheet/dataweave-2x-cheatsheet.md) | [PDF](dataweave/cheatsheet/dataweave-2x-cheatsheet.pdf)
- [Anti-Patterns & Common Mistakes](dataweave/anti-patterns/common-mistakes.md)
- [DW 1.0 to 2.0 Migration Guide](dataweave/anti-patterns/dw1-vs-dw2-migration.md)
- [MEL to DataWeave Guide](dataweave/anti-patterns/mel-to-dataweave.md)
- [7 Exchange Modules](dataweave/#anypoint-exchange-modules) (96 functions, 213 MUnit tests)
- [Playground Tips](dataweave/playground/)

### Error Handling (51 recipes)

Global handlers, retry patterns, circuit breaker, dead letter queues, async errors, transactions, connector-specific errors, alerting, validation, and recovery patterns.

**[Browse all error handling recipes](error-handling/)**

### Performance (49 recipes)

Streaming strategies, memory/heap tuning, batch optimization, connection pools, caching, threading model, API performance, database tuning, CloudHub sizing, HTTP/2 multiplexing, and monitoring.

**[Browse all performance recipes](performance/)**

### API Management (57 recipes)

Flex Gateway deployment, AI gateway, custom WASM policies, rate limiting, OAuth/JWT/mTLS security, OWASP API Top 10 mapping, MCP/A2A gateway, agent governance, API design patterns, versioning, and analytics.

**[Browse all API management recipes](api-management/)**

### AI Agent Integration (63 recipes)

MCP server/client setup, A2A protocol, advanced MCP (OAuth, streaming, tracing), RAG pipelines, Agentforce actions, inference connector, Vibes prompt engineering and governance, LLM gateway, AI testing, multi-cloud LLMs, and AI security.

**[Browse all AI agent recipes](ai-agents/)**

### DevOps & CI/CD (53 recipes)

CI/CD pipelines (GitHub Actions, GitLab, Jenkins), environment promotion, IaC (Terraform, Helm), secrets management, deployment strategies (blue-green, canary), MUnit testing (batch, async, error, coverage), RTF, observability, and compliance.

**[Browse all DevOps recipes](devops/)**

### Migrations (63 recipes)

Java version upgrades, Mule runtime migrations (3→4, 4.9→4.10, 4.10→4.11), CloudHub 1→2, API spec conversions, connector upgrades, security migrations, monitoring migrations, build tool upgrades, and architectural modernization.

**[Browse all migration recipes](migrations/)**

### Cost Optimization (7 recipes)

vCore right-sizing calculator, API consolidation patterns, usage-based pricing migration, dev sandbox cost reduction, CloudHub vs RTF vs on-prem TCO comparison, license audit checklist, and Anypoint MQ cost optimization.

**[Browse all cost optimization recipes](cost-optimization/)**

### Salesforce Integration (9 recipes)

Bidirectional sync with conflict resolution, Bulk API 2.0 partial failure recovery, CDC vs Platform Events decision tree, governor limit-safe batch processing, Agentforce action registration, OAuth patterns, Composite API, Streaming API, and data migration strategies.

**[Browse all Salesforce recipes](salesforce/)**

### Production Troubleshooting (8 recipes)

Thread dump analysis, top 30 error messages decoded, memory leak detection step-by-step, deployment failure flowchart, Anypoint Monitoring vs OpenTelemetry, connection pool exhaustion diagnosis, DataWeave OOM debugging, and batch job failure analysis.

**[Browse all troubleshooting recipes](troubleshooting/)**

### Enterprise Architecture (8 recipes)

API-led anti-patterns, C4E setup playbook, event-driven architecture with MuleSoft, domain-driven API design, multi-region DR strategy, application network topology, microservices vs API-led, and integration maturity model.

**[Browse all architecture recipes](architecture/)**

### Messaging (7 recipes)

Anypoint MQ vs Kafka honest comparison, FIFO queue patterns, DLQ reprocessing, large payload workarounds, consumer circuit breaker, VM queue vs Anypoint MQ decision tree, and message ordering guarantees.

**[Browse all messaging recipes](messaging/)**

### Connector Patterns (8 recipes)

SAP IDoc processing, Workday custom reports, ServiceNow CMDB integration, NetSuite patterns, database change data capture, SFTP guaranteed delivery, EDI X12/EDIFACT processing, and AS2 message exchange.

**[Browse all connector recipes](connectors/)**

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Adding a new pattern?** Place it in the appropriate section folder with a README explaining the concept.

**Adding a new section?** Open an issue first to discuss the scope.

---

## License

[MIT](LICENSE) — Copyright (c) 2026 Shakar Bisetty

---

Built by [WeavePilot](https://github.com/shakarbisetty) — practical MuleSoft recipes for the community.
