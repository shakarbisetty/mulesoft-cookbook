# MCP IDE Setup

> Connect Cursor, VS Code, or Windsurf to Anypoint Platform — build Mule apps with natural language.

## What It Does

The MuleSoft MCP Server (`@mulesoft/mcp-server`) bridges AI-powered IDEs to the Anypoint Platform. You can create projects, generate flows, write DataWeave, deploy apps, and manage APIs — all from natural language prompts in your editor.

## Prerequisites

- **Node.js 20+**
- **Git**
- Anypoint Platform account with **Organization Administrator** access
- A Connected App on Anypoint Platform (see Step 1)

## Step 1: Create a Connected App

1. Go to **Anypoint Platform > Access Management > Connected Apps**
2. Click **Create App** > Select **App acts on its own behalf (Client Credentials)**
3. Add scopes:
   - Code Builder
   - Runtime Manager (Read/Write)
   - API Manager
   - Exchange (Contributor)
   - Monitoring (Read)
4. Select **all business groups** and **all environments**
5. Save the **Client ID** and **Client Secret**

## Step 2: Configure Your IDE

### Cursor

Create or edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "mulesoft": {
      "command": "npx",
      "args": ["-y", "@mulesoft/mcp-server", "start"],
      "env": {
        "ANYPOINT_CLIENT_ID": "your-client-id",
        "ANYPOINT_CLIENT_SECRET": "your-client-secret",
        "ANYPOINT_REGION": "PROD_US"
      }
    }
  }
}
```

### VS Code

Create `.vscode/mcp.json` in your workspace:

```json
{
  "mcp": {
    "servers": {
      "mulesoft": {
        "command": "npx",
        "args": ["-y", "@mulesoft/mcp-server", "start"],
        "env": {
          "ANYPOINT_CLIENT_ID": "your-client-id",
          "ANYPOINT_CLIENT_SECRET": "your-client-secret",
          "ANYPOINT_REGION": "PROD_US"
        }
      }
    }
  }
}
```

### Supported Regions

| Region | Value |
|--------|-------|
| US | `PROD_US` |
| EU | `PROD_EU` |
| Canada | `PROD_CA` |
| Japan | `PROD_JP` |

### Supported IDEs

Cursor, VS Code, Windsurf, Zed, Trae, Cline

## Step 3: Try It

Open your IDE's AI chat and try these prompts:

```
Create a new Mule project called "order-api"
```

```
Generate a flow that accepts POST /orders, validates the payload, and stores it in a database
```

```
Write a DataWeave transformation that converts this XML to JSON: [paste XML]
```

```
Deploy my project to CloudHub 2.0 in the Sandbox environment
```

## Available Tools (37+)

The MCP server exposes 37+ tools across 8 categories:

| Category | Examples |
|----------|---------|
| **App Development** | Create projects, generate flows, generate MUnit tests, validate |
| **DataWeave** | Create DW projects, run scripts, generate sample data |
| **API Specs** | Generate RAML/OAS specs, mock APIs, implement specs |
| **Deployment** | Deploy to CloudHub 2.0, manage apps, run locally |
| **Connectors** | Generate custom connectors from API specs |
| **Governance** | Add rulesets, validate against governance rules |
| **Agent Networks** | Create and deploy agent network projects |
| **Insights** | Platform analytics, reuse metrics |

## Common Gotchas

- **Connected App scopes must match** the tools you want to use — missing scopes cause silent failures
- **Select all business groups and environments** when creating the Connected App
- **Anypoint Code Builder Desktop** has MCP pre-configured — no manual setup needed
- **Anypoint Extension Pack v1.10.0+** required for third-party IDE integration
- **Node.js 20 is required** — older versions will fail silently

## References

- [MuleSoft MCP Server Overview](https://docs.mulesoft.com/mulesoft-mcp-server/)
- [Getting Started Guide](https://docs.mulesoft.com/mulesoft-mcp-server/getting-started)
- [Tool Reference (37+ tools)](https://docs.mulesoft.com/mulesoft-mcp-server/reference-mcp-tools)
- [npm Package](https://www.npmjs.com/package/@mulesoft/mcp-server)
