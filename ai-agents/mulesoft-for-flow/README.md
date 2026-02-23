# MuleSoft for Flow — Low-Code Integration in Salesforce

> Connect external systems to Salesforce automations — no Mule project required.

## What is MuleSoft for Flow?

MuleSoft for Flow: Integration is a low-code integration layer built directly inside Salesforce Flow Builder. It lets Salesforce admins connect external systems (SAP, Workday, NetSuite, Jira, Slack, and 130+ others) to Salesforce automations without writing Mule XML or DataWeave.

**This is not Vibes.** MuleSoft for Flow targets Salesforce admins and business users. Vibes targets MuleSoft developers. They solve different problems for different personas.

## MuleSoft for Flow vs Vibes

| Dimension | MuleSoft for Flow | MuleSoft Vibes |
|-----------|-------------------|----------------|
| **Primary user** | Salesforce admins, business analysts | MuleSoft integration developers |
| **Interface** | Salesforce Flow Builder (point-and-click) | Anypoint Code Builder (VS Code-based IDE) |
| **Output** | Salesforce Flow automation | Mule application (XML + DataWeave) |
| **Code required** | No code | AI-assisted code generation |
| **Deployment** | Salesforce org | CloudHub, RTF, on-prem |
| **Connectors** | 130+ prebuilt | Full 500+ connector catalog |
| **Custom logic** | Flow formula expressions | Full DataWeave scripting |
| **Runtime** | Salesforce | Mule Runtime |

## When to Use Which

| Scenario | Use |
|----------|-----|
| Admin connects ServiceNow tickets to Cases | **MuleSoft for Flow** |
| Developer builds complex multi-system orchestration | **Vibes + Mule** |
| Agentforce action needs external data | **MuleSoft for Flow** (or MCP) |
| Custom DataWeave transformations required | **Vibes + Mule** |
| Simple CRUD sync between Salesforce and one system | **MuleSoft for Flow** |
| Real-time event processing with complex routing | **Vibes + Mule** |

## How It Works

1. Open **Salesforce Setup > Flow Builder**
2. Add an action element
3. Select a MuleSoft connector (e.g., NetSuite, Workday, SAP)
4. Configure the operation (create record, query, update)
5. Map Salesforce fields to connector fields
6. Activate the Flow

No Mule runtime, no CloudHub deployment, no DataWeave — the connector runs inside the Salesforce platform.

## Available Connectors (130+)

| Category | Examples |
|----------|----------|
| **ERP** | SAP, NetSuite, Oracle EBS |
| **HCM** | Workday, BambooHR, ADP |
| **ITSM** | ServiceNow, Jira, PagerDuty |
| **Collaboration** | Slack, Microsoft Teams, Google Workspace |
| **Finance** | QuickBooks, Stripe, Xero |
| **Productivity** | Box, Dropbox, Google Drive |
| **CRM** | HubSpot, Zendesk |

## Agentforce Integration

Flow automations built with MuleSoft for Flow connectors can be exposed as **Agentforce actions**:

1. Build a Flow that queries Workday for employee PTO balances
2. Expose the Flow as an Invocable Action
3. Agentforce agent can now check PTO balances when employees ask

This makes external system data available to AI agents without building custom MCP servers.

## Advanced Features

### Polling Triggers with State Management

Triggers can detect only new or changed records (not full re-scans):

- Tracks last processed record ID or timestamp
- Only fires for records created/modified since last poll
- Reduces API call volume and processing overhead

### Error Handling

Flows support fault paths for connector failures:
- Retry logic for transient errors (timeouts, rate limits)
- Fault path routing for permanent failures
- Notification actions on failure (email, Slack, Chatter)

## Common Gotchas

- **Not a replacement for Mule** — complex orchestration, DataWeave transformations, and custom protocols still require Mule apps
- **Connector subset** — 130+ connectors vs 500+ in full Anypoint, so check availability first
- **Salesforce governor limits apply** — Flow callout limits, DML limits, and CPU time limits affect connector operations
- **No DataWeave** — field mapping is visual only; complex transformations need Mule
- **Separate from Anypoint Platform** — these connectors are managed in Salesforce Setup, not Anypoint

## References

- [MuleSoft for Flow: Integration](https://www.mulesoft.com/platform/flow-integration)
- [MuleSoft for Flow Announcement](https://blogs.mulesoft.com/news/mulesoft-for-flow-integration/)
- [Salesforce Flow Documentation](https://help.salesforce.com/s/articleView?id=sf.flow.htm)
