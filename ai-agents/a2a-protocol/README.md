# A2A Protocol — Agent-to-Agent Communication

> Build agent-to-agent workflows with Google's A2A protocol and MuleSoft.

## What is A2A?

The [Agent-to-Agent (A2A) Protocol](https://a2a-protocol.org/) is an open standard by Google (April 2025) for agents to communicate, delegate tasks, and collaborate — regardless of vendor or framework.

**MCP vs A2A**: MCP connects agents to *tools*. A2A connects agents to *other agents*. Use both together for full agent architectures.

## Prerequisites

- Mule Runtime **4.9.8+** (GA requirement)
- Java 17 (OpenJDK)
- A2A Connector v1.0.0+ from Exchange: `com.mulesoft.connectors:mule4-a2a-connector`

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule4-a2a-connector</artifactId>
    <version>1.0.1</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

### Version History

| Version | Date | Protocol | Key Changes |
|---------|------|----------|-------------|
| 0.1.0-BETA | May 2025 | A2A 0.1.0 | Initial release |
| 0.2.0-BETA | Jul 2025 | A2A 0.2.3 | Get Card, Send Message, default headers |
| 0.3.0-BETA | Aug 2025 | A2A 0.2.3 | Distributed tracing, certificate types |
| 0.4.0-BETA | Sep 2025 | A2A 0.3.0 | Push notifications, `.well-known` endpoint |
| **1.0.0 (GA)** | **Dec 2025** | **A2A 0.3.0** | **Stream Message, Task Resubscribe, distinct client/server operations** |
| 1.0.1 | Jan 2026 | A2A 0.3.0 | DataSense payload suggestions |

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

### Task Lifecycle (A2A 0.3.0)

The protocol defines 8 task states in three categories:

```
Active:       submitted → working
Interrupted:  input-required (needs human input)
              auth-required  (needs credentials)
Terminal:     completed | failed | canceled | rejected
```

**Valid state transitions:**

| From | Can Transition To |
|------|-------------------|
| `submitted` | `working`, `rejected` |
| `working` | `input-required`, `auth-required`, `completed`, `failed`, `canceled` |
| `input-required` | `working`, `canceled` |
| `auth-required` | `working`, `canceled` |
| Terminal states | None (immutable) |

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
    <set-variable value="#[payload.params.message.parts[0].text]"
                   variableName="user_prompt" />

    <!-- Your logic: call an LLM, query a database, etc. -->

    <!-- Update task status to completed -->
    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{
            "state": "completed",
            "message": {
                "parts": [{ "kind": "text", "text": vars.result }]
            }
        }]]]></a2a:status>
    </a2a:task-status>

    <!-- Attach result as artifact -->
    <a2a:task-artifact config-ref="A2A_Server">
        <a2a:artifact><![CDATA[#[{
            "artifactId": "answer-1",
            "parts": [{ "kind": "text", "text": vars.result }]
        }]]]></a2a:artifact>
    </a2a:task-artifact>
</flow>
```

## A2A Client — Call Other Agents

### 1. Client Configuration

```xml
<a2a:client-config name="A2A_Client">
    <a2a:connection
        agentCardUrl="https://remote-agent.example.com/.well-known/agent-card.json" />
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

    <!-- Poll for result (or use streaming — see below) -->
    <a2a:get-task config-ref="A2A_Client" taskId="#[payload.id]" />
</flow>
```

## Operations Reference (v1.0.0 GA)

### Client Operations

| Operation | Description |
|-----------|-------------|
| `send-message` | Send a synchronous task to a remote agent |
| `send-stream-message` | Send with SSE streaming response |
| `task-resubscribe` | Reconnect to an existing SSE stream |
| `get-task` | Poll task status and artifacts |
| `cancel-task` | Cancel a running task |
| `get-card` | Retrieve the agent's Agent Card |
| `push-notification` | Send async push notification |
| `get-push-notification-config` | Get push config for a task |
| `delete-push-notification-config` | Remove push config |

### Server Operations

| Operation | Description |
|-----------|-------------|
| `task-status` | Update task state, broadcast to SSE clients |
| `task-artifact` | Attach output artifact, broadcast to SSE clients |

### Server Sources (Event Listeners)

| Source | Description |
|--------|-------------|
| `task-listener` | Listens for synchronous `message/send` requests |
| `task-stream-listener` | Listens for streaming `message/stream` requests |

## SSE Streaming

Streaming enables real-time status updates and artifact delivery over Server-Sent Events. The server must use `task-stream-listener` (not the regular `task-listener`).

### Server-Side Streaming Flow

```xml
<flow name="streamingAgentFlow">
    <!-- Must use task-stream-listener for SSE support -->
    <a2a:task-stream-listener config-ref="A2A_Server" />

    <!-- Broadcast status: working -->
    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{
            "state": "working",
            "message": {
                "parts": [{ "kind": "text", "text": "Processing your request..." }]
            }
        }]]]></a2a:status>
    </a2a:task-status>

    <!-- Your LLM call or processing logic here -->

    <!-- Stream artifact chunks -->
    <a2a:task-artifact config-ref="A2A_Server">
        <a2a:artifact><![CDATA[#[{
            "artifactId": "result-1",
            "parts": [{ "kind": "text", "text": vars.llmChunk }],
            "append": true,
            "lastChunk": false
        }]]]></a2a:artifact>
    </a2a:task-artifact>

    <!-- Final chunk -->
    <a2a:task-artifact config-ref="A2A_Server">
        <a2a:artifact><![CDATA[#[{
            "artifactId": "result-1",
            "parts": [{ "kind": "text", "text": vars.finalChunk }],
            "append": true,
            "lastChunk": true
        }]]]></a2a:artifact>
    </a2a:task-artifact>

    <!-- Close stream with completed status -->
    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{ "state": "completed" }]]]></a2a:status>
    </a2a:task-status>
</flow>
```

### Client-Side Streaming

```xml
<flow name="streamingClientFlow">
    <!-- Stream instead of poll -->
    <a2a:send-stream-message config-ref="A2A_Client">
        <a2a:message>#[{
            "role": "user",
            "parts": [{"kind": "text", "text": "Generate quarterly report"}]
        }]</a2a:message>
    </a2a:send-stream-message>

    <!-- Process streamed events as they arrive -->
    <logger message="Stream event: #[payload]" />
</flow>
```

### Reconnecting After Disconnect

If the SSE connection drops, use `task-resubscribe` to reconnect and receive buffered events:

```xml
<a2a:task-resubscribe config-ref="A2A_Client"
    taskId="#[vars.activeTaskId]" />
```

The Agent Card must declare `"streaming": true` in capabilities for clients to use streaming.

## Human-in-the-Loop (`input-required`)

When an agent needs human input before continuing, it sets `input-required` status. This closes the SSE stream and pauses the task until the client responds.

### Server: Request Human Input

```xml
<flow name="humanInLoopFlow">
    <a2a:task-stream-listener config-ref="A2A_Server" />

    <!-- Determine if clarification is needed -->
    <choice>
        <when expression="#[vars.needsClarification == true]">
            <!-- Pause for human input -->
            <a2a:task-status config-ref="A2A_Server">
                <a2a:status><![CDATA[#[{
                    "state": "input-required",
                    "message": {
                        "parts": [{
                            "kind": "text",
                            "text": "Should I proceed with production deployment? (yes/no)"
                        }]
                    }
                }]]]></a2a:status>
            </a2a:task-status>
            <!-- Stream closes here — task waits for client to respond -->
        </when>
        <otherwise>
            <a2a:task-status config-ref="A2A_Server">
                <a2a:status><![CDATA[#[{ "state": "working" }]]]></a2a:status>
            </a2a:task-status>
            <!-- Continue processing... -->
        </otherwise>
    </choice>
</flow>
```

### Client: Resume After `input-required`

The client sends a new message on the **same `taskId`** to resume:

```xml
<flow name="resumeAfterInputRequired">
    <!-- Send follow-up on the same task -->
    <a2a:send-stream-message config-ref="A2A_Client">
        <a2a:message>#[{
            "role": "user",
            "taskId": vars.pausedTaskId,
            "parts": [{"kind": "text", "text": "Yes, proceed with deployment."}]
        }]</a2a:message>
    </a2a:send-stream-message>
    <!-- Agent transitions input-required → working → completed -->
</flow>
```

### Multi-Turn After Completion

Once a task reaches a terminal state, it's immutable. For follow-up conversations, start a new task with `referenceTaskIds`:

```json
{
  "message": {
    "contextId": "session-xyz",
    "referenceTaskIds": ["task-abc-123"],
    "parts": [{ "kind": "text", "text": "Now summarize what you deployed." }]
  }
}
```

## Push Notifications

For long-running tasks where maintaining an SSE connection isn't practical, agents can send HTTP POST callbacks to a webhook URL.

### Agent Card Setup

```json
{
  "capabilities": {
    "pushNotifications": true
  }
}
```

### Server: Send Push Notification

```xml
<a2a:push-notification config-ref="A2A_Client">
    <a2a:notification><![CDATA[#[{
        "taskId": vars.taskId,
        "status": {
            "state": "completed",
            "message": {
                "parts": [{ "kind": "text", "text": "Analysis complete." }]
            }
        }
    }]]]></a2a:notification>
</a2a:push-notification>
```

### Manage Push Configs

```xml
<!-- Get current push config for a task -->
<a2a:get-push-notification-config config-ref="A2A_Client"
    taskId="#[vars.taskId]" />

<!-- Remove push config -->
<a2a:delete-push-notification-config config-ref="A2A_Client"
    taskId="#[vars.taskId]" />
```

## Multi-Agent Orchestration Pattern

One Mule agent receives a task, delegates parts to specialist agents, and combines results:

```xml
<flow name="orchestratorFlow">
    <a2a:task-stream-listener config-ref="A2A_Server" />

    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{
            "state": "working",
            "message": { "parts": [{ "kind": "text", "text": "Delegating to specialists..." }] }
        }]]]></a2a:status>
    </a2a:task-status>

    <!-- Delegate to finance agent -->
    <a2a:send-message config-ref="Finance_A2A_Client">
        <a2a:message>#[payload.params.message]</a2a:message>
    </a2a:send-message>
    <set-variable variableName="financeResult" value="#[payload]" />

    <!-- Delegate to compliance agent -->
    <a2a:send-message config-ref="Compliance_A2A_Client">
        <a2a:message>#[payload.params.message]</a2a:message>
    </a2a:send-message>
    <set-variable variableName="complianceResult" value="#[payload]" />

    <!-- Combine and return -->
    <a2a:task-artifact config-ref="A2A_Server">
        <a2a:artifact><![CDATA[#[{
            "artifactId": "combined-analysis",
            "parts": [{
                "kind": "text",
                "text": vars.financeResult ++ "\n\n" ++ vars.complianceResult
            }]
        }]]]></a2a:artifact>
    </a2a:task-artifact>

    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{ "state": "completed" }]]]></a2a:status>
    </a2a:task-status>
</flow>
```

## Agentforce Integration

MuleSoft provides two connectors for Salesforce AI integration:

| Connector | Purpose | Runtime |
|-----------|---------|---------|
| **A2A Connector** | Standard A2A protocol (any agent) | Mule 4.9.8+ |
| **Agentforce Connector** | Direct Salesforce Agentforce sessions | Mule 4.6.9+ |

### Expose an Agentforce Agent via A2A

Wrap an Agentforce agent as an A2A-compliant server so any A2A client can discover and call it:

```xml
<flow name="agentforceA2AProxyFlow">
    <a2a:task-listener config-ref="A2A_Server" />

    <set-variable variableName="userPrompt"
        value="#[payload.params.message.parts[0].text]" />

    <!-- Call Agentforce -->
    <agentforce:create-session config-ref="Agentforce_Config"
        agentId="${agentforce.agent.id}" />
    <agentforce:send-message config-ref="Agentforce_Config"
        sessionId="#[payload.sessionId]">
        <agentforce:message>#[vars.userPrompt]</agentforce:message>
    </agentforce:send-message>

    <!-- Return as A2A response -->
    <a2a:task-status config-ref="A2A_Server">
        <a2a:status><![CDATA[#[{
            "state": "completed",
            "message": {
                "parts": [{ "kind": "text", "text": payload.botResponse }]
            }
        }]]]></a2a:status>
    </a2a:task-status>
</flow>
```

With Agentforce 3's native MCP support, you get a two-way integration: Agentforce calls MuleSoft APIs as MCP tools, and MuleSoft brokers Agentforce as A2A agents.

## Error Handling

### Error Types

| Error | When It Occurs |
|-------|----------------|
| `A2A:CONNECTIVITY` | Cannot reach the remote agent |
| `A2A:REQUEST_TIMEOUT` | Agent didn't respond in time |
| `A2A:UNAUTHORIZED` | Invalid credentials or token |
| `A2A:TASK_NOT_FOUND` | Task ID doesn't exist |
| `A2A:TASK_NOT_CANCELABLE` | Task is in a terminal state |
| `A2A:UNSUPPORTED_OPERATION` | Agent doesn't support the requested operation |
| `A2A:INVALID_PARAMS` | Malformed request parameters |
| `A2A:INTERNAL_ERROR` | Server-side failure |
| `A2A:RETRY_EXHAUSTED` | Max retries reached |

### Error Handling Pattern

```xml
<flow name="resilientAgentCall">
    <a2a:send-message config-ref="A2A_Client">
        <a2a:message>#[vars.taskMessage]</a2a:message>
    </a2a:send-message>

    <error-handler>
        <on-error-propagate type="A2A:CONNECTIVITY, A2A:REQUEST_TIMEOUT">
            <logger level="WARN"
                message="Agent unreachable, falling back to local processing" />
            <!-- Fallback logic -->
        </on-error-propagate>
        <on-error-propagate type="A2A:UNAUTHORIZED">
            <logger level="ERROR"
                message="Auth failed for agent: #[error.description]" />
            <raise-error type="APP:AUTH_FAILURE" />
        </on-error-propagate>
    </error-handler>
</flow>
```

## Governance with Flex Gateway

Agent Fabric applies these A2A-specific policies through Flex Gateway (v1.9.3+):

| Policy | Function |
|--------|----------|
| **A2A Agent Card** | Rewrites Agent Card URLs to gateway endpoint |
| **A2A Schema Validation** | Validates requests conform to A2A 0.3.0 spec |
| **A2A PII Detector** | Blocks PII from reaching or leaving agents |
| **A2A Prompt Decorator** | Injects context into prompts |
| **SSE Logging** | Logs every SSE event during streaming |
| **In-Task Auth Code** | Enforces OAuth 2.0 for outbound agent calls |

## Common Gotchas

- **`task-stream-listener` is required for streaming** — the regular `task-listener` rejects streaming requests
- **Terminal states are immutable** — once completed/failed/canceled, use `referenceTaskIds` for follow-ups
- **Agent Card must declare capabilities** — clients check `streaming` and `pushNotifications` before attempting
- **`task-resubscribe` only works while the task is active** — once terminal, the stream is gone
- **Two separate connectors for Agentforce** — A2A Connector wraps agents for interop, Agentforce Connector manages sessions directly
- **Mule 4.9.8+ required for GA** — beta versions worked on 4.9.4+, but 1.0.0 requires 4.9.8

## References

- [A2A Connector Documentation](https://docs.mulesoft.com/a2a-connector/latest/)
- [A2A Connector Examples](https://docs.mulesoft.com/a2a-connector/latest/a2a-connector-examples)
- [A2A Connector Release Notes](https://docs.mulesoft.com/release-notes/connector/a2a-connector-release-notes-mule-4)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [A2A vs MCP Comparison](https://a2a-protocol.org/latest/topics/a2a-and-mcp/)
- [Streaming & Async Operations](https://a2a-protocol.org/latest/topics/streaming-and-async/)
- [MuleSoft A2A Blog](https://blogs.mulesoft.com/news/mulesoft-a2a-connector/)
- [Agentforce Connector Docs](https://docs.mulesoft.com/agentforce-connector/latest/)
- [Flex Gateway A2A Policies](https://docs.mulesoft.com/gateway/latest/flex-agent-policies)
