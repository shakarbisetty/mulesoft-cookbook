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
| 10 | [SF API Quota Monitoring](./sf-api-quota-monitoring/) | Real-time API quota monitoring with tiered thresholds and circuit-breaker pattern for Bulk API fallback |
| 11 | [Bulk API v2 Job Orchestrator](./bulk-api-v2-job-orchestrator/) | Parent-child data load sequencing with Bulk API v2: load parents, extract IDs, then load children |
| 12 | [Bulk API v2 Chunk Calculator](./bulk-api-v2-chunk-calculator/) | Optimal chunk size calculator based on object complexity, trigger count, and validation rules |
| 13 | [Platform Events DLQ Pattern](./platform-events-dlq-pattern/) | Dead Letter Queue for Platform Events with failure capture, exponential backoff retry, and admin API |
| 14 | [SF Pub/Sub API Migration](./sf-pubsub-api-migration/) | Migration guide from CometD/Streaming API to Salesforce Pub/Sub gRPC API with parallel-run strategy |
| 15 | [High-Volume Platform Events](./high-volume-platform-events/) | High-volume Platform Event consumption with backpressure, parallel processing, and subscriber lag monitoring |
| 16 | [CDC Replay Storm Prevention](./cdc-replay-storm-prevention/) | Prevent CDC replay storms on application restart with replay ID staleness detection and polling catchup |
| 17 | [CDC Field-Level Filtering](./cdc-field-level-filtering/) | Filter CDC events by specific field changes using changedFields bitmap to reduce processing volume by 80-90% |
| 18 | [INVALID_SESSION_ID Recovery](./sf-invalid-session-recovery/) | Root cause analysis for 5 types of session failures with automatic recovery and exponential backoff |
| 19 | [Sync Loop Prevention](./sf-sync-loop-prevention/) | Prevent bidirectional sync loops with integration user filtering, sync flags, and timestamp deduplication |
| 20 | [SF Flow vs MuleSoft Decision](./sf-flow-vs-mulesoft-decision/) | Scored decision matrix for choosing between Salesforce Flow and MuleSoft with anti-pattern detection |
| 21 | [Multi-Org Dynamic Routing](./sf-multi-org-dynamic-routing/) | Route requests to multiple Salesforce orgs from a single MuleSoft app with dynamic configuration |
| 22 | [Sandbox Refresh Reconnect](./sf-sandbox-refresh-reconnect/) | Automated detection and recovery after Salesforce sandbox refresh with ops alerting and runbooks |
| 23 | [External ID Strategy](./sf-external-id-strategy/) | External ID design for idempotent migrations with parent-child relationship resolution and cross-reference mapping |
| 24 | [FLS Integration Patterns](./sf-fls-integration-patterns/) | Detect and handle Field-Level Security permission gaps to prevent silent data loss in integrations |

## Prerequisites

- Anypoint Studio 7.x or Mule Runtime 4.4+
- Salesforce Connector 10.x (Mule 4)
- Salesforce Developer or Sandbox org for testing

## Related Sections

- [Error Handling — Salesforce Connector Errors](../error-handling/connector-errors/salesforce-invalid-session/)
- [Performance — Connection Pool Tuning](../performance/connections/)
- [DataWeave Patterns](../dataweave/patterns/)
