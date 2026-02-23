# AI Agent Integration

[![MuleSoft](https://img.shields.io/badge/MuleSoft-AI_Agents-00A1E0.svg)](https://www.mulesoft.com/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-purple.svg)](https://modelcontextprotocol.io/)
[![A2A](https://img.shields.io/badge/Protocol-A2A-green.svg)](https://a2a-protocol.org/)

> Build, connect, and govern AI agents with MuleSoft — MCP servers, A2A protocol, Agent Fabric, and more.

---

## What's Here

| Tutorial | Description | Difficulty |
|----------|-------------|------------|
| [MCP Server Basics](mcp-server-basics/) | Turn any Mule API into an MCP server that AI agents can discover and call | Beginner |
| [MCP Client](mcp-client/) | Call remote MCP servers from your Mule flows | Intermediate |
| [MCP IDE Setup](mcp-ide-setup/) | Connect Cursor, VS Code, or Windsurf to Anypoint Platform via MCP | Beginner |
| [A2A Protocol](a2a-protocol/) | Build agent-to-agent communication with Google's A2A protocol | Intermediate |
| [Agent Fabric](agent-fabric/) | Register, discover, and govern agents across clouds | Advanced |

---

## MCP vs A2A — When to Use Which

| Use Case | Protocol | Why |
|----------|----------|-----|
| Expose a Mule API as a tool for AI agents | **MCP** | MCP is designed for tool/resource access |
| Two agents collaborating on a task | **A2A** | A2A handles stateful task delegation |
| AI IDE building Mule apps | **MCP** | IDE uses MCP to call Anypoint Platform tools |
| Orchestrating agents across clouds | **A2A + Agent Fabric** | A2A for communication, Fabric for governance |
| Both: agent calls tools AND delegates to other agents | **MCP + A2A** | Use both — they are complementary |

**Simple rule:** MCP = agent talks to tools (vertical). A2A = agent talks to agents (horizontal).

---

## Prerequisites

- Anypoint Platform account
- Mule Runtime 4.9.6+ (for MCP Connector v1.3)
- Java 17
- Anypoint Studio or Anypoint Code Builder

---

## Quick Links

- [MCP Connector Docs](https://docs.mulesoft.com/mcp-connector/latest/)
- [A2A Connector Docs](https://docs.mulesoft.com/a2a-connector/latest/)
- [Agent Fabric Docs](https://docs.mulesoft.com/agent-fabric/)
- [MuleSoft MCP Server (npm)](https://www.npmjs.com/package/@mulesoft/mcp-server)
- [A2A Protocol Spec](https://a2a-protocol.org/latest/specification/)

---

Part of [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
