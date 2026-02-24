# Salesforce Integration Recipes

Production-grade Salesforce integration patterns for MuleSoft developers. Each recipe includes working Mule XML configurations, DataWeave transformations, and SOQL examples you can adapt for your projects.

## Recipes

| # | Recipe | Description |
|---|--------|-------------|
| 1 | [Bidirectional Sync & Conflict Resolution](./bidirectional-sync-conflict-resolution/) | Salesforce-to-external-system sync with last-write-wins, field-level merge, and manual review queue strategies |
| 2 | [Bulk API 2.0 Partial Failure Recovery](./bulk-api-2-partial-failure/) | Handle partial failures in Bulk API 2.0 jobs with failed-record capture and individual retry |
| 3 | [CDC vs Platform Events Decision Guide](./cdc-vs-platform-events-decision/) | Decision tree for choosing between Change Data Capture, Platform Events, and Outbound Messages |
| 4 | [Governor Limit Safe Batch Processing](./governor-limit-safe-batch/) | Design batch integrations that respect API call, SOQL, and DML governor limits |
| 5 | [Agentforce Mule Action Registration](./agentforce-mule-action-registration/) | Register MuleSoft APIs as Agentforce actions with Connected Apps and External Services |
| 6 | [Connected App OAuth Patterns](./connected-app-oauth-patterns/) | OAuth 2.0 flows for Salesforce: Client Credentials, JWT Bearer, and refresh token rotation |
| 7 | [Composite API Patterns](./composite-api-patterns/) | Execute multiple Salesforce operations in a single round-trip using the Composite API |
| 8 | [Streaming API Integration](./salesforce-streaming-api/) | Real-time notifications via PushTopics, Generic Events, and CometD with replay durability |
| 9 | [Data Migration Strategies](./data-migration-strategies/) | Full, delta, and incremental migration patterns with rollback and audit logging |

## Prerequisites

- Anypoint Studio 7.x or Mule Runtime 4.4+
- Salesforce Connector 10.x (Mule 4)
- Salesforce Developer or Sandbox org for testing

## Related Sections

- [Error Handling — Salesforce Connector Errors](../error-handling/connector-errors/salesforce-invalid-session/)
- [Performance — Connection Pool Tuning](../performance/connections/)
- [DataWeave Patterns](../dataweave/patterns/)
