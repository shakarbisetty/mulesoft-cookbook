# A2A Protocol — Agent-to-Agent Communication

> Build agent-to-agent workflows with Google's A2A protocol and MuleSoft.

## What is A2A?

The [Agent-to-Agent (A2A) Protocol](https://a2a-protocol.org/) is an open standard by Google (April 2025) for agents to communicate, delegate tasks, and collaborate — regardless of vendor or framework.

**MCP vs A2A**: MCP connects agents to *tools*. A2A connects agents to *other agents*. Use both together for full agent architectures.

## Prerequisites

- Mule Runtime 4.9.6+
- A2A Connector from Exchange: `com.mulesoft.connectors:mule4-a2a-connector`

## Core Concepts

### Agent Card

Every A2A agent publishes an Agent Card at `/.well-known/agent-card.json` — its "business card" describing capabilities:

```json
{
  "name": "Financial Analysis Agent",
  "description": "Analyzes financial data and generates reports",
  "version": "1.0.0",
  "url": "https://finance-agent.example.com/a2a",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true
  },
  "defaultInputModes": ["text/plain", "application/json"],
  "defaultOutputModes": ["application/json"],
  "skills": [
    {
      "id": "financial_analysis",
      "name": "Financial Analysis",
      "description": "Analyzes financial statements and market data",
      "tags": ["finance", "analysis"],
      "examples": ["Analyze Q4 revenue trends"]
    }
  ]
}
```

### Task Lifecycle

```
pending → working → completed
                  → failed
                  → canceled
                  → input-required (pauses for client input)
```

### Messages, Parts, and Artifacts

- **Message**: A communication turn (`role`: "user" or "agent")
- **Part**: Content unit within a message (`text`, `raw`, `url`, `data`)
- **Artifact**: Output produced by task execution (multipart, typed)

## A2A Server — Expose a Mule Flow as an Agent

### 1. Server Configuration

```xml
<http:listener-config name="HTTP_Listener_config">
    <http:listener-connection host="0.0.0.0" port="8081" />
</http:listener-config>

<a2a:server-config name="A2A_Server">
    <a2a:connection listenerConfig="HTTP_Listener_config" agentPath="/" />
    <a2a:agent-card file="agent-card.json" />
</a2a:server-config>
```

### 2. Task Listener (Receive Tasks)

```xml
<flow name="myAgentFlow">
    <a2a:task-listener config-ref="A2A_Server" />

    <!-- Extract the user's prompt -->
    <set-variable value="#[payload.message.parts[0].text]"
                   variableName="user_prompt" />

    <!-- Your logic: call an LLM, query a database, etc. -->

    <!-- Update task status to completed -->
    <a2a:update-task-status config-ref="A2A_Server"
        taskId="#[payload.id]" status="completed" />

    <!-- Attach result as artifact -->
    <a2a:update-task-artifact config-ref="A2A_Server"
        taskId="#[payload.id]">
        <a2a:artifact name="Answer">
            <a2a:parts>
                <a2a:text-part text="#[vars.result]" />
            </a2a:parts>
        </a2a:artifact>
    </a2a:update-task-artifact>
</flow>
```

## A2A Client — Call Other Agents

### 1. Client Configuration

```xml
<a2a:client-config name="A2A_Client">
    <a2a:connection serverUrl="https://remote-agent.example.com"
                     requestTimeout="30"
                     requestTimeoutUnit="SECONDS" />
</a2a:client-config>
```

### 2. Send a Task

```xml
<flow name="delegateToSpecialist">
    <!-- Discover what the remote agent can do -->
    <a2a:get-card config-ref="A2A_Client" useExtendedCard="false" />
    <logger message="Agent skills: #[payload.skills]" />

    <!-- Send a task -->
    <a2a:send-message config-ref="A2A_Client">
        <a2a:message>#[{
            "role": "user",
            "parts": [{"kind": "text", "text": "Analyze Q4 revenue trends"}]
        }]</a2a:message>
    </a2a:send-message>

    <!-- Poll for result (or use streaming) -->
    <a2a:get-task config-ref="A2A_Client" taskId="#[payload.id]" />
</flow>
```

## Client Operations

| Operation | Description |
|-----------|-------------|
| `send-message` | Send a task to a remote agent |
| `send-stream-message` | Send with SSE streaming response |
| `get-task` | Poll task status and artifacts |
| `cancel-task` | Cancel a running task |
| `get-card` | Retrieve the agent's Agent Card |

## Server Operations

| Operation | Description |
|-----------|-------------|
| `update-task-status` | Update task lifecycle state |
| `update-task-artifact` | Attach output artifacts |
| `send-push-notification` | Push async notification to client |

## Multi-Agent Orchestration Pattern

One Mule agent receives a task, delegates parts to specialist agents, and combines results:

```xml
<flow name="orchestratorFlow">
    <a2a:task-listener config-ref="A2A_Server" />

    <!-- Delegate to finance agent -->
    <a2a:send-message config-ref="Finance_A2A_Client">
        <a2a:message>#[payload.message]</a2a:message>
    </a2a:send-message>
    <set-variable variableName="financeResult" value="#[payload]" />

    <!-- Delegate to compliance agent -->
    <a2a:send-message config-ref="Compliance_A2A_Client">
        <a2a:message>#[payload.message]</a2a:message>
    </a2a:send-message>
    <set-variable variableName="complianceResult" value="#[payload]" />

    <!-- Combine and return -->
    <a2a:update-task-artifact config-ref="A2A_Server"
        taskId="#[payload.id]">
        <a2a:artifact name="Combined Analysis">
            <a2a:parts>
                <a2a:text-part text="#[vars.financeResult ++ vars.complianceResult]" />
            </a2a:parts>
        </a2a:artifact>
    </a2a:update-task-artifact>
</flow>
```

## Error Types

`A2A:CONNECTIVITY`, `A2A:INTERNAL_ERROR`, `A2A:INVALID_PARAMS`, `A2A:TASK_NOT_FOUND`, `A2A:UNAUTHORIZED`, `A2A:REQUEST_TIMEOUT`, `A2A:RETRY_EXHAUSTED`

## References

- [A2A Connector Documentation](https://docs.mulesoft.com/a2a-connector/latest/)
- [A2A Connector Examples](https://docs.mulesoft.com/a2a-connector/latest/a2a-connector-examples)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [A2A vs MCP Comparison](https://a2a-protocol.org/latest/topics/a2a-and-mcp/)
- [MuleSoft A2A Blog](https://blogs.mulesoft.com/news/mulesoft-a2a-connector/)
