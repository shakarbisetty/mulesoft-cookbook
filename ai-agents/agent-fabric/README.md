# Agent Fabric — Governed Agent Networks

> Register, discover, orchestrate, and govern AI agents across clouds with MuleSoft Agent Fabric.

## What is Agent Fabric?

Agent Fabric is MuleSoft's platform for managing AI agents at enterprise scale. It solves "agent sprawl" — the problem of dozens of agents across different clouds with no central governance.

## Four Pillars

| Pillar | Tool | Purpose |
|--------|------|---------|
| **Discovery** | Anypoint Exchange + Agent Scanners | Find and catalog agents across clouds |
| **Orchestration** | Agent Brokers (YAML) | Route tasks to the best-fit agent |
| **Governance** | Flex Gateway | Security, rate limiting, access control on agent traffic |
| **Observation** | Agent Visualizer | Monitor agent interactions and performance |

## Agent Scanners (GA January 2026)

Automatically discover agents running on:
- Salesforce Agentforce
- Amazon Bedrock
- Google Cloud Vertex AI
- Microsoft Copilot Studio

Discovered agents are automatically registered in your Agent Registry.

## MCP Server by URL (GA January 2026)

Register external MCP servers by simply pasting their URL:

1. Navigate to **Agent Registry** in Anypoint Platform
2. Click **Add MCP Server**
3. Paste the server URL
4. Agent Registry auto-discovers tools and capabilities

## Exposing APIs as MCP Servers

The recommended path: adapt **existing APIs** to MCP rather than building new servers from scratch.

### Step 1: Annotate Your API Spec

Add semantic metadata that helps AI agents understand your API:

- **Scope**: Narrowly defines the agent's job
- **Classification Description**: Plain-text summary for topic relevance
- **Instructions**: Guidelines for how the agent executes actions

### Step 2: Publish to Anypoint Exchange

Register your API as a discoverable asset in Exchange.

### Step 3: Build an Agent Network

Create a declarative YAML project in Anypoint Code Builder that defines which APIs/tools the agent network can access and how orchestration works.

### Step 4: Deploy Flex Gateway (Two Instances)

- **Ingress Gateway**: Policies on traffic coming into the broker (auth, rate limiting)
- **Egress Gateway**: Policies on traffic going out to external services (logging, security)

### Step 5: Monitor with Agent Visualizer

View the full agent network topology, trace interactions, and debug issues.

## Protocol Support

Agent Fabric governs both MCP and A2A traffic:

| Protocol | What It Governs |
|----------|----------------|
| **MCP** | Agent-to-tool connections (tool invocations, resource access) |
| **A2A** | Agent-to-agent connections (task delegation, collaboration) |

Flex Gateway applies security policies to both protocol types.

## Common Gotchas

- **Two Flex Gateway instances are required** — one ingress, one egress
- **Semantic metadata is critical** — without proper annotations, agents won't discover your API
- **Adapt existing APIs first** — don't build new MCP servers from scratch if you already have APIs
- **Agent Scanners require credentials** for each cloud platform they scan

## References

- [Agent Fabric Documentation](https://docs.mulesoft.com/agent-fabric/)
- [Exposing APIs as MCP Servers](https://blogs.mulesoft.com/news/how-to-expose-an-api-as-an-mcp-server-with-mulesoft-agent-fabric/)
- [Agent Fabric Deep Dive](https://architect.salesforce.com/docs/architect/fundamentals/guide/mulesoft-agent-fabric-deep-dive)
- [Governance for Agent Interactions](https://blogs.mulesoft.com/news/mulesoft-governance-for-agent-interactions/)
- [Q1 2026 Product Roadmap](https://blogs.mulesoft.com/news/mulesoft-q1-2026-product-roadmap/)
