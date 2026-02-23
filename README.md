# MuleSoft Cookbook

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![MuleSoft](https://img.shields.io/badge/MuleSoft-Anypoint-00A1E0.svg)](https://www.mulesoft.com/)
[![GitHub Stars](https://img.shields.io/github/stars/shakarbisetty/mulesoft-cookbook?style=social)](https://github.com/shakarbisetty/mulesoft-cookbook)

> Practical recipes for MuleSoft developers — DataWeave patterns, AI agent integration, CI/CD pipelines, migration guides, and more.

---

## What's Inside

| Section | What You Get | Status |
|---------|-------------|--------|
| [**DataWeave**](dataweave/) | 100+ transformation patterns, 7 Exchange modules, cheatsheet, anti-patterns guide | 100 patterns |
| [**AI Agents**](ai-agents/) | MCP server setup, A2A protocol, Agentforce actions, Inference Connector, RAG pipelines | Coming soon |
| [**DevOps**](devops/) | GitHub Actions CI/CD, CloudHub 2.0 deployment, MUnit automation, monitoring | Coming soon |
| [**Migrations**](migrations/) | Java 8 to 17, DW 1.0 to 2.0, MEL to DataWeave | Coming soon |
| [**Error Handling**](error-handling/) | Circuit breaker, retry with backoff, dead letter queues, global error patterns | Coming soon |
| [**Performance**](performance/) | Streaming large payloads, memory tuning, batch optimization, caching | Coming soon |
| [**API Management**](api-management/) | Flex Gateway, custom policies, rate limiting, API governance | Coming soon |

---

## Quick Start

**Pick a section** from the table above, or jump straight to the most popular content:

### DataWeave (most popular)

```dwl
%dw 2.0
output application/json
---
payload groupBy $.department
    mapObject ((employees, dept) -> {
        (dept): sizeOf(employees)
    })
```

Browse all 100+ patterns: **[dataweave/](dataweave/)**

---

## Table of Contents

### DataWeave Patterns (100+)

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
| [Math & Precision](dataweave/patterns/17-math-precision/) | 1 | Intermediate |
| [Observability](dataweave/patterns/18-observability/) | 1 | Intermediate |
| [AI Integration](dataweave/patterns/19-ai-integration/) | 2 | Advanced |
| [Utility Modules](dataweave/patterns/20-utility-modules/) | 5 | Intermediate to Advanced |

### Additional DataWeave Resources

- [DW 2.x Cheatsheet](dataweave/cheatsheet/dataweave-2x-cheatsheet.md) | [PDF](dataweave/cheatsheet/dataweave-2x-cheatsheet.pdf)
- [Anti-Patterns & Common Mistakes](dataweave/anti-patterns/common-mistakes.md)
- [DW 1.0 to 2.0 Migration Guide](dataweave/anti-patterns/dw1-vs-dw2-migration.md)
- [MEL to DataWeave Guide](dataweave/anti-patterns/mel-to-dataweave.md)
- [7 Exchange Modules](dataweave/#anypoint-exchange-modules) (96 functions, 213 MUnit tests)
- [Playground Tips](dataweave/playground/)

### AI Agent Integration (coming soon)

- MCP Server setup with Anypoint
- A2A protocol for agent-to-agent communication
- Agentforce actions via Topic Center
- Inference Connector for LLM calls from Mule flows
- RAG pipelines with Vectors Connector

### DevOps & CI/CD (coming soon)

- GitHub Actions pipeline for MuleSoft
- CloudHub 2.0 deployment automation
- MUnit test automation in CI
- Direct Telemetry Stream monitoring

### Migration Guides (coming soon)

- Java 8 to Java 17 migration
- DataWeave 1.0 to 2.0 migration
- MEL to DataWeave conversion

### Error Handling Patterns (coming soon)

- Circuit breaker implementation
- Retry with exponential backoff
- Dead letter queue patterns
- Global error handler design

### Performance Optimization (coming soon)

- Streaming strategies for large payloads
- Memory management and heap tuning
- Batch job performance patterns

### API Management (coming soon)

- Flex Gateway as LLM Gateway
- Custom policy development
- Rate limiting strategies
- API governance automation

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
