## Multi-Agent Orchestration via A2A
> Coordinate multiple AI agents using the Agent-to-Agent protocol for complex workflows.

### When to Use
- Complex tasks requiring specialized agents (research, coding, review)
- Workflow decomposition where each agent handles a subtask
- Enterprise agent orchestration with MuleSoft as the backbone

### Configuration / Code

```xml
<flow name="orchestrator-flow">
    <http:listener config-ref="HTTP_Listener" path="/orchestrate" method="POST"/>
    <!-- Step 1: Research agent gathers data -->
    <http:request config-ref="Research_Agent" path="/a2a/tasks/send" method="POST">
        <http:body>#[output application/json --- {
            jsonrpc: "2.0", method: "tasks/send",
            params: {task: {message: {role: "user", parts: [{type: "text", text: payload.query}]}}}
        }]</http:body>
    </http:request>
    <set-variable variableName="researchResult" value="#[payload.result.task.message.parts[0].text]"/>
    <!-- Step 2: Analysis agent processes research -->
    <http:request config-ref="Analysis_Agent" path="/a2a/tasks/send" method="POST">
        <http:body>#[output application/json --- {
            jsonrpc: "2.0", method: "tasks/send",
            params: {task: {message: {role: "user", parts: [{type: "text", text: vars.researchResult}]}}}
        }]</http:body>
    </http:request>
    <set-payload value="#[output application/json --- {research: vars.researchResult, analysis: payload.result}]"/>
</flow>
```

### How It Works
1. Orchestrator receives a complex request
2. Decomposes into subtasks and sends to specialized agents via A2A
3. Each agent processes its subtask and returns results
4. Orchestrator aggregates results and returns the final output

### Gotchas
- Agent failures need graceful handling — implement retry and fallback
- Circular agent calls cause infinite loops — implement call depth limits
- Latency compounds with sequential agent calls — parallelize when possible
- A2A task IDs must be tracked for status polling on long-running tasks

### Related
- [A2A Protocol](../a2a-protocol/) — A2A basics
- [Error Recovery](../error-recovery/) — handling agent failures
